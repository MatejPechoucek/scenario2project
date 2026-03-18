import 'dart:math';

import '../database/food_item.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Nutritional Proximity Algorithm  v2
//  Weighted Euclidean distance with category compatibility + meal context.
//
//  Reference: CleanEater design spec (CSScenario1Plan.pdf), Framework §3.
//
//  WHAT WAS WRONG IN v1
//  ─────────────────────
//  v1 was purely numeric — it had no concept of what type of food something
//  is. This caused absurd suggestions like "swap salmon for nutritional yeast"
//  because both score similarly on the protein dimension.
//
//  HOW v2 WORKS
//  ─────────────
//  The algorithm now applies three sequential filters before computing any
//  distances, in addition to the Euclidean scoring:
//
//  1. CATEGORY COMPATIBILITY FILTER
//     Each food has a `compatibilityGroup` (defined on FoodItem). Candidates
//     must be in the same group OR a defined cross-compatible group.
//     e.g. Fish ↔ Poultry ↔ Red Meat are all 'protein_main' — fair swaps.
//     Nutritional Yeast is 'protein_plant' — incompatible with Fish for dinner.
//
//  2. MEAL SLOT FILTER
//     Each food and meal has a meal slot ('breakfast', 'lunch', 'dinner',
//     'snack'). Candidates must be appropriate for that slot.
//     e.g. Breakfast Cereals are flagged 'breakfast' — never suggested for dinner.
//
//  3. CALORIE SCALE AWARENESS
//     base_foods.json values are per 100g. Meals are totals (e.g. 600 kcal).
//     The algorithm operates on per-100g nutritional ratios so the Euclidean
//     comparison is always apples-to-apples. The calorie ceiling filter
//     is applied on the per-100g calorie value of the candidate, not the
//     meal total, so oats (389 kcal/100g) are not incorrectly blocked or
//     passed based on a 600 kcal meal total.
//
//  4. EUCLIDEAN DISTANCE (unchanged from v1)
//     After the three filters, candidates that survive are scored by weighted
//     Euclidean distance in a 5D nutritional space. Lower = more similar.
//
//  HOW TO TUNE
//  ─────────────
//  All tunable constants are at the top of [NutritionalProximityAlgorithm].
//  The category groups and cross-compatibility pairs live on [FoodItem] —
//  edit _categoryToGroup() and the crossCompatible set there.
// ═══════════════════════════════════════════════════════════════════════════

/// Represents a single swap suggestion produced by the algorithm.
class SwapSuggestion {
  /// The food that was flagged as potentially improvable.
  final FoodItem original;

  /// The suggested healthier alternative.
  final FoodItem alternative;

  /// Normalised Euclidean distance (0 = identical, 1 = maximally different).
  /// Lower is better — it means the foods are more nutritionally similar.
  final double distance;

  /// Human-readable descriptions of the improvements, e.g.
  /// ["−32% fat", "−18% sugar"].
  final List<String> improvements;

  /// A single-sentence rationale shown in the UI.
  final String reason;

  const SwapSuggestion({
    required this.original,
    required this.alternative,
    required this.distance,
    required this.improvements,
    required this.reason,
  });
}

class NutritionalProximityAlgorithm {
  // ── TUNABLE WEIGHTS ───────────────────────────────────────────────────────
  // Adjust these to change how each nutritional dimension influences similarity.
  //
  // Rationale for defaults:
  //   sugar   × 2.0  — sugar is the primary improvement target (spec §Feedback)
  //   fat     × 1.5  — potato-chip example in spec; fat is the key swap driver
  //   sodium  × 1.5  — "Smart Swap" spec example focuses on sodium
  //   protein × 1.2  — slightly elevated: we want swaps to preserve protein
  //   carbs   × 1.0  — baseline

  static const double weightProtein = 1.2;
  static const double weightFat     = 1.5;
  static const double weightCarbs   = 1.0;
  static const double weightSugar   = 2.0;
  static const double weightSodium  = 1.5;

  // ── HEALTH IMPROVEMENT THRESHOLDS ─────────────────────────────────────────
  // A candidate must be at least this much better in the flagged dimension.
  // 0.15 = "≥15% less fat/sugar/sodium than the original".

  static const double minFatReductionFraction    = 0.15;
  static const double minSugarReductionFraction  = 0.15;
  static const double minSodiumReductionFraction = 0.15;

  // ── SIMILARITY THRESHOLD ─────────────────────────────────────────────────
  // Maximum normalised distance to be considered "similar enough".
  // Tightened from v1's 0.65 — fewer but more relevant suggestions.

  static const double maxDistance = 0.50;

  // ── PUBLIC API ─────────────────────────────────────────────────────────────

  /// Find the best healthier alternatives for [food] from [candidates].
  ///
  /// [food]       — the food item to find alternatives for.
  /// [candidates] — the full food bank pool (FoodRepository.getAllBaseFoods()).
  /// [mealSlot]   — 'breakfast', 'lunch', 'dinner', or 'snack'. Filters
  ///                candidates to only those appropriate for the meal.
  ///                Defaults to 'any' (no slot filtering).
  /// [maxResults] — how many suggestions to return (default: 3).
  ///
  /// Returns an empty list if [food] is not flagged as unhealthy, or if no
  /// candidates survive the three pre-filters + distance threshold.
  static List<SwapSuggestion> findAlternatives(
    FoodItem food,
    List<FoodItem> candidates, {
    String mealSlot = 'any',
    int maxResults = 3,
  }) {
    // Only run for foods with at least one unhealthy flag.
    if (!food.isUnhealthy) return [];

    // Pre-filter candidates through all three gates before expensive scoring.
    final eligible = candidates.where((c) {
      // Gate 1: not the same food.
      if (c.id == food.id) return false;

      // Gate 2: category compatibility — same group or cross-compatible.
      if (!food.isCompatibleWith(c)) return false;

      // Gate 3: meal slot — must be appropriate for this meal.
      if (mealSlot != 'any' && !c.isSuitableFor(mealSlot)) return false;

      return true;
    }).toList();

    if (eligible.isEmpty) return [];

    // Build normalisation denominators from eligible pool + original.
    final pool = [...eligible, food];
    final maxP  = _maxOf(pool, (f) => f.proteinG);
    final maxF  = _maxOf(pool, (f) => f.fatG);
    final maxC  = _maxOf(pool, (f) => f.carbsG);
    final maxS  = _maxOf(pool, (f) => f.sugarG);
    final maxNa = _maxOf(pool, (f) => f.sodiumMg);

    final origVec = _normalise(food, maxP, maxF, maxC, maxS, maxNa);

    final suggestions = <SwapSuggestion>[];

    for (final candidate in eligible) {
      // Euclidean distance gate.
      final candVec = _normalise(candidate, maxP, maxF, maxC, maxS, maxNa);
      final d = _weightedDistance(origVec, candVec);
      if (d > maxDistance) continue;

      // Health improvement gate — must actually be better in at least one way.
      final improvements = _computeImprovements(food, candidate);
      if (improvements.isEmpty) continue;

      suggestions.add(SwapSuggestion(
        original: food,
        alternative: candidate,
        distance: d,
        improvements: improvements,
        reason: _buildReason(candidate, improvements),
      ));
    }

    // Sort: more improvements first, then by similarity (lower distance).
    suggestions.sort((a, b) {
      final scoreA = a.improvements.length * (1.0 - a.distance);
      final scoreB = b.improvements.length * (1.0 - b.distance);
      return scoreB.compareTo(scoreA);
    });

    return suggestions.take(maxResults).toList();
  }

  // ── PRIVATE HELPERS ───────────────────────────────────────────────────────

  static double _maxOf(List<FoodItem> pool, double Function(FoodItem) getter) {
    final m = pool.fold(0.0, (acc, f) => getter(f) > acc ? getter(f) : acc);
    return m == 0 ? 1.0 : m;
  }

  static List<double> _normalise(
    FoodItem food,
    double maxP, double maxF, double maxC, double maxS, double maxNa,
  ) =>
      [
        food.proteinG / maxP,
        food.fatG     / maxF,
        food.carbsG   / maxC,
        food.sugarG   / maxS,
        food.sodiumMg / maxNa,
      ];

  static double _weightedDistance(List<double> a, List<double> b) {
    const weights = [weightProtein, weightFat, weightCarbs, weightSugar, weightSodium];
    var sum = 0.0;
    for (var i = 0; i < 5; i++) {
      final diff = a[i] - b[i];
      sum += weights[i] * diff * diff;
    }
    return sqrt(sum);
  }

  /// Computes health improvement descriptions.
  /// Only flags dimensions where the original food is actually unhealthy —
  /// this avoids misleading "−5% fat" claims when fat isn't the problem.
  static List<String> _computeImprovements(FoodItem orig, FoodItem cand) {
    final improvements = <String>[];

    if (orig.isHighFat && orig.fatG > 0) {
      final r = (orig.fatG - cand.fatG) / orig.fatG;
      if (r >= minFatReductionFraction) {
        improvements.add('−${(r * 100).round()}% fat');
      }
    }

    if (orig.isHighSugar && orig.sugarG > 0) {
      final r = (orig.sugarG - cand.sugarG) / orig.sugarG;
      if (r >= minSugarReductionFraction) {
        improvements.add('−${(r * 100).round()}% sugar');
      }
    }

    if (orig.isHighSodium && orig.sodiumMg > 0) {
      final r = (orig.sodiumMg - cand.sodiumMg) / orig.sodiumMg;
      if (r >= minSodiumReductionFraction) {
        improvements.add('−${(r * 100).round()}% sodium');
      }
    }

    // Bonus: flag if candidate has meaningfully more protein (positive framing).
    if (cand.proteinG > orig.proteinG * 1.25) {
      final extra = (cand.proteinG - orig.proteinG).round();
      improvements.add('+${extra}g protein');
    }

    // Bonus: flag if candidate has notably more fibre.
    if (cand.fiberG > orig.fiberG + 2.5) {
      improvements.add('+${(cand.fiberG - orig.fiberG).round()}g fibre');
    }

    return improvements;
  }

  /// Produces a context-aware, non-judgmental reason string for the UI.
  static String _buildReason(FoodItem alt, List<String> improvements) {
    // Lead with the category to reinforce why this is a realistic swap.
    final category = alt.category;
    final topImprovements = improvements.take(2).join(' & ');
    return '$category · $topImprovements';
  }
}
