import 'dart:math';

import '../database/food_item.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Nutritional Proximity Algorithm
//  Based on weighted Euclidean distance in a 5-dimensional nutrient space.
//
//  Reference: CleanEater design spec (CSScenario1Plan.pdf), Framework §3.
//
//  HOW IT WORKS
//  ─────────────
//  Each FoodItem is represented as a vector of 5 nutritional dimensions:
//    [proteinG, fatG, carbsG, sugarG, sodiumMg]
//
//  Before computing distances, every dimension is normalised to [0, 1]
//  using the maximum observed value across the entire candidate pool.
//  This ensures gram-scale and milligram-scale dimensions are comparable.
//
//  The weighted Euclidean distance between food A and candidate B is:
//
//    d = sqrt( wP*(pA-pB)² + wF*(fA-fB)² + wC*(cA-cB)² +
//              wS*(sA-sB)² + wNa*(nA-nB)² )
//
//  A candidate is suggested only if:
//    • d ≤ maxDistance  (similar enough in nutritional profile)
//    • It provides a measurable health improvement in at least one
//      dimension that the original food was flagged on.
//    • It is not significantly more caloric than the original.
//
//  HOW TO TUNE
//  ─────────────
//  All tunable constants are at the top of this class.
//  Increase a weight to make that dimension matter more for similarity.
//  Increase a threshold to make the "improvement" requirement stricter.
//  Decrease maxDistance to only suggest foods that are very similar.
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
  // Adjust these to change how the algorithm weighs each nutritional dimension
  // when deciding whether two foods are "similar".
  //
  // Rationale for defaults:
  //   sugar   × 2.0  — sugar is the primary improvement target (spec §Feedback)
  //   fat     × 1.5  — potato-chip example in spec; fat is key swap driver
  //   sodium  × 1.5  — "Smart Swap" example in spec focuses on sodium
  //   protein × 1.0  — equal to carbs; similarity in protein matters but less
  //   carbs   × 1.0  — baseline

  static const double weightProtein = 1.0;
  static const double weightFat = 1.5;
  static const double weightCarbs = 1.0;
  static const double weightSugar = 2.0;
  static const double weightSodium = 1.5;

  // ── HEALTH IMPROVEMENT THRESHOLDS ─────────────────────────────────────────
  // A candidate must be at least this much better in the flagged dimension
  // to qualify as a valid suggestion.
  // Example: 0.15 means "≥15% less fat than the original".

  static const double minFatReductionFraction = 0.15;
  static const double minSugarReductionFraction = 0.15;
  static const double minSodiumReductionFraction = 0.15;

  // ── SIMILARITY THRESHOLD ─────────────────────────────────────────────────
  // Maximum normalised distance allowed for a food to be considered
  // "similar enough" to suggest. Lower = stricter (fewer but more relevant
  // suggestions). Range: 0.0 (exact match only) to 1.0 (anything goes).

  static const double maxDistance = 0.65;

  // ── CALORIE CEILING ───────────────────────────────────────────────────────
  // Suggestions must not be more than this fraction more caloric than the
  // original. Set to 1.10 = allow up to 10% more calories.
  // Ethical design: we don't want to push users to eat significantly more.

  static const double maxCalorieFractionIncrease = 1.10;

  // ── PUBLIC API ─────────────────────────────────────────────────────────────

  /// Find the best healthier alternatives for [food] from [candidates].
  ///
  /// [food]       — the food item the user has (e.g. from their meal plan).
  /// [candidates] — the full pool to search (use FoodRepository.getAllBaseFoods()).
  /// [maxResults] — how many suggestions to return (default: 3).
  ///
  /// Returns an empty list if [food] is not flagged as unhealthy, or if
  /// no candidates pass the distance and improvement filters.
  static List<SwapSuggestion> findAlternatives(
    FoodItem food,
    List<FoodItem> candidates, {
    int maxResults = 3,
  }) {
    // Only run the algorithm if the food has at least one unhealthy flag.
    // This avoids surfacing "swap" suggestions for perfectly healthy foods.
    if (!food.isUnhealthy) return [];

    // Build normalisation denominators from the candidate pool + the food itself.
    final pool = [...candidates, food];
    final maxProtein = _maxOf(pool, (f) => f.proteinG);
    final maxFat = _maxOf(pool, (f) => f.fatG);
    final maxCarbs = _maxOf(pool, (f) => f.carbsG);
    final maxSugar = _maxOf(pool, (f) => f.sugarG);
    final maxSodium = _maxOf(pool, (f) => f.sodiumMg);

    // Normalised vector for the original food.
    final origVec = _normalise(food, maxProtein, maxFat, maxCarbs, maxSugar, maxSodium);

    final suggestions = <SwapSuggestion>[];

    for (final candidate in candidates) {
      // Skip itself.
      if (candidate.id == food.id) continue;

      // Skip if significantly more caloric.
      if (food.calories > 0 &&
          candidate.calories > food.calories * maxCalorieFractionIncrease) {
        continue;
      }

      // Compute weighted Euclidean distance.
      final candVec = _normalise(
          candidate, maxProtein, maxFat, maxCarbs, maxSugar, maxSodium);
      final d = _weightedDistance(origVec, candVec);
      if (d > maxDistance) continue;

      // Check health improvements.
      final improvements = _computeImprovements(food, candidate);
      if (improvements.isEmpty) continue;

      // Build the suggestion.
      suggestions.add(SwapSuggestion(
        original: food,
        alternative: candidate,
        distance: d,
        improvements: improvements,
        reason: _buildReason(candidate, improvements),
      ));
    }

    // Sort: more improvements first, then closer similarity.
    suggestions.sort((a, b) {
      final scoreA = a.improvements.length * (1 - a.distance);
      final scoreB = b.improvements.length * (1 - b.distance);
      return scoreB.compareTo(scoreA);
    });

    return suggestions.take(maxResults).toList();
  }

  // ── PRIVATE HELPERS ───────────────────────────────────────────────────────

  static double _maxOf(List<FoodItem> pool, double Function(FoodItem) getter) {
    final max = pool.fold(0.0, (m, f) => getter(f) > m ? getter(f) : m);
    // Avoid division-by-zero: if max is 0, use 1 so normalised value stays 0.
    return max == 0 ? 1.0 : max;
  }

  /// Returns a normalised 5-vector for [food].
  static List<double> _normalise(
    FoodItem food,
    double maxP,
    double maxF,
    double maxC,
    double maxS,
    double maxNa,
  ) =>
      [
        food.proteinG / maxP,
        food.fatG / maxF,
        food.carbsG / maxC,
        food.sugarG / maxS,
        food.sodiumMg / maxNa,
      ];

  /// Computes the weighted Euclidean distance between two normalised vectors.
  static double _weightedDistance(List<double> a, List<double> b) {
    assert(a.length == 5 && b.length == 5);
    final weights = [
      weightProtein,
      weightFat,
      weightCarbs,
      weightSugar,
      weightSodium,
    ];
    var sum = 0.0;
    for (var i = 0; i < 5; i++) {
      final diff = a[i] - b[i];
      sum += weights[i] * diff * diff;
    }
    return sqrt(sum);
  }

  /// Returns a list of improvement descriptions.
  /// Only checks the dimensions on which [original] is flagged as unhealthy.
  static List<String> _computeImprovements(
      FoodItem original, FoodItem candidate) {
    final improvements = <String>[];

    // Fat improvement — only check if original is flagged as high-fat.
    if (original.isHighFat && original.fatG > 0) {
      final reduction = (original.fatG - candidate.fatG) / original.fatG;
      if (reduction >= minFatReductionFraction) {
        final pct = (reduction * 100).round();
        improvements.add('−$pct% fat');
      }
    }

    // Sugar improvement — only check if original is flagged as high-sugar.
    if (original.isHighSugar && original.sugarG > 0) {
      final reduction = (original.sugarG - candidate.sugarG) / original.sugarG;
      if (reduction >= minSugarReductionFraction) {
        final pct = (reduction * 100).round();
        improvements.add('−$pct% sugar');
      }
    }

    // Sodium improvement — only check if original is flagged as high-sodium.
    if (original.isHighSodium && original.sodiumMg > 0) {
      final reduction =
          (original.sodiumMg - candidate.sodiumMg) / original.sodiumMg;
      if (reduction >= minSodiumReductionFraction) {
        final pct = (reduction * 100).round();
        improvements.add('−$pct% sodium');
      }
    }

    // Bonus: note if candidate is also higher in protein (positive framing).
    if (candidate.proteinG > original.proteinG * 1.20) {
      final extra = (candidate.proteinG - original.proteinG).round();
      improvements.add('+${extra}g protein');
    }

    // Bonus: note if candidate is higher in fibre.
    if (candidate.fiberG > original.fiberG + 2.0) {
      improvements.add('+${(candidate.fiberG - original.fiberG).round()}g fibre');
    }

    return improvements;
  }

  /// Produces a short, non-judgmental reason string for the UI.
  static String _buildReason(FoodItem alt, List<String> improvements) {
    final parts = improvements.take(2).join(', ');
    return 'Similar taste profile — $parts';
  }
}
