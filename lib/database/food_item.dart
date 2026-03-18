/// Represents a single food entry in the CleanEater food bank.
///
/// All nutritional values are per 100g unless otherwise noted.
/// This model is used by both the bundled JSON asset and the USDA API service.
/// It is the input type for [NutritionalProximityAlgorithm].
///
/// Contrast with [Meal]: a [Meal] is a named, scheduled eating event
/// (e.g. "Breakfast") that a user plans. A [FoodItem] is a scientific
/// food entry with full nutritional detail drawn from a database.
class FoodItem {
  /// Unique identifier. Bundled foods use 'local_XXX', USDA foods use the
  /// fdcId as a string (e.g. '171515').
  final String id;

  /// Human-readable food name, e.g. "Chicken Breast (cooked)".
  final String name;

  /// Food category for grouping in the UI, e.g. "Poultry", "Snacks".
  final String category;

  // ── Macronutrients (g per 100g serving) ──────────────────────────────────

  /// Energy in kilocalories per 100g.
  final double calories;

  /// Total protein in grams per 100g.
  final double proteinG;

  /// Total fat (lipids) in grams per 100g.
  final double fatG;

  /// Total carbohydrates in grams per 100g.
  final double carbsG;

  // ── Key Micronutrients (per 100g) ─────────────────────────────────────────

  /// Total sugars in grams per 100g.
  /// Threshold for "high sugar" (UK FSA): >22.5g per 100g.
  final double sugarG;

  /// Sodium in milligrams per 100g.
  /// Threshold for "high sodium": >600mg per 100g.
  final double sodiumMg;

  /// Total dietary fiber in grams per 100g.
  final double fiberG;

  /// Where this record came from: 'bundled', 'usda_api', or 'cached'.
  final String source;

  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.calories,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.sugarG,
    required this.sodiumMg,
    required this.fiberG,
    this.source = 'bundled',
  });

  // ── Unhealthy flag helpers ────────────────────────────────────────────────

  /// Fat > 17.5g per 100g (UK FSA "high fat" threshold).
  bool get isHighFat => fatG > 17.5;

  /// Sugar > 22.5g per 100g (UK FSA "high sugar" threshold).
  bool get isHighSugar => sugarG > 22.5;

  /// Sodium > 600mg per 100g (UK FSA "high salt" equivalent threshold).
  bool get isHighSodium => sodiumMg > 600.0;

  /// Returns true if any single dimension is flagged as unhealthy.
  /// This triggers the Smart Swap suggestion panel in the UI.
  bool get isUnhealthy => isHighFat || isHighSugar || isHighSodium;

  // ── Category compatibility for the algorithm ──────────────────────────────

  /// Returns the compatibility group key for this food's category.
  ///
  /// The Nutritional Proximity Algorithm ONLY compares foods within the same
  /// compatibility group. This prevents absurd suggestions like
  /// "swap salmon for nutritional yeast" — they share a protein profile but
  /// are completely different foods in practice.
  ///
  /// Groups are intentionally broad to allow meaningful swaps (e.g. chicken
  /// and fish are both in "protein_main") while preventing cross-type nonsense.
  String get compatibilityGroup => _categoryToGroup(category);

  static String _categoryToGroup(String cat) {
    switch (cat) {
      // ── Main protein sources ──────────────────────────────────────────────
      case 'Poultry':
      case 'Fish & Seafood':
      case 'Red Meat':
        return 'protein_main';

      // ── Plant protein (similar macro profiles to each other, not to meat) ─
      case 'Plant Protein':
      case 'Legumes':
        return 'protein_plant';

      // ── Eggs & dairy ──────────────────────────────────────────────────────
      case 'Eggs & Dairy':
        return 'dairy_egg';

      // ── Starchy carbs / grains ────────────────────────────────────────────
      case 'Grains':
      case 'Bread & Bakery':
        return 'starchy_carbs';

      // ── Breakfast cereals (separate — very high carb, breakfast context) ──
      case 'Breakfast Cereals':
        return 'breakfast_cereal';

      // ── Vegetables (any) ─────────────────────────────────────────────────
      case 'Vegetables':
      case 'Salads':
        return 'vegetables';

      // ── Fruits ────────────────────────────────────────────────────────────
      case 'Fruits':
        return 'fruits';

      // ── Nuts, seeds, nut butters ──────────────────────────────────────────
      case 'Nuts & Seeds':
      case 'Nut Butters':
        return 'nuts_seeds';

      // ── Snacks (packaged, savoury and sweet) ──────────────────────────────
      case 'Snacks':
        return 'snacks';

      // ── Desserts ──────────────────────────────────────────────────────────
      case 'Desserts':
        return 'desserts';

      // ── Fast food (burger/pizza/fries context) ────────────────────────────
      case 'Fast Food':
        return 'fast_food';

      // ── Composed meals ────────────────────────────────────────────────────
      case 'Meals':
        return 'composed_meals';

      // ── Processed meat ────────────────────────────────────────────────────
      case 'Processed Meat':
        return 'processed_meat';

      // ── Condiments (sauces, dressings) ────────────────────────────────────
      case 'Condiments':
        return 'condiments';

      // ── Soups ────────────────────────────────────────────────────────────
      case 'Soups':
        return 'soups';

      // ── Beverages ────────────────────────────────────────────────────────
      case 'Beverages':
        return 'beverages';

      // ── Fats & oils ───────────────────────────────────────────────────────
      case 'Fats & Oils':
        return 'fats_oils';

      // ── Supplements ───────────────────────────────────────────────────────
      case 'Supplements':
        return 'supplements';

      default:
        return 'general';
    }
  }

  /// Returns true if [other] is in a compatible swap group with this food.
  ///
  /// Some groups are cross-compatible:
  ///   - protein_main ↔ protein_plant  (e.g. tofu instead of chicken)
  ///   - desserts ↔ fruits             (e.g. fruit salad instead of cheesecake)
  ///   - fast_food ↔ composed_meals    (e.g. homemade burger vs fast food)
  ///   - snacks ↔ fruits               (e.g. apple instead of crisps)
  ///   - snacks ↔ nuts_seeds           (e.g. almonds instead of crisps)
  bool isCompatibleWith(FoodItem other) {
    final g1 = compatibilityGroup;
    final g2 = other.compatibilityGroup;
    if (g1 == g2) return true;

    // Defined cross-compatible pairs (symmetric).
    const crossCompatible = {
      ('protein_main', 'protein_plant'),
      ('protein_plant', 'protein_main'),
      ('desserts', 'fruits'),
      ('fruits', 'desserts'),
      ('fast_food', 'composed_meals'),
      ('composed_meals', 'fast_food'),
      ('snacks', 'fruits'),
      ('fruits', 'snacks'),
      ('snacks', 'nuts_seeds'),
      ('nuts_seeds', 'snacks'),
      ('starchy_carbs', 'vegetables'), // e.g. swap white rice for cauliflower rice
      ('vegetables', 'starchy_carbs'),
    };

    return crossCompatible.contains((g1, g2));
  }

  // ── Meal context suitability ───────────────────────────────────────────────

  /// Returns the set of meal slots this food is naturally appropriate for.
  /// Used by the algorithm to avoid suggesting breakfast foods for dinner.
  ///
  /// Values: 'breakfast', 'lunch', 'dinner', 'snack', 'any'
  Set<String> get suitableMealSlots => _categoryToMealSlots(category);

  static Set<String> _categoryToMealSlots(String cat) {
    switch (cat) {
      case 'Poultry':
      case 'Fish & Seafood':
      case 'Red Meat':
      case 'Legumes':
      case 'Plant Protein':
        return {'lunch', 'dinner'};

      case 'Eggs & Dairy':
        return {'breakfast', 'lunch', 'snack'};

      case 'Breakfast Cereals':
        return {'breakfast'};

      case 'Grains':
        return {'lunch', 'dinner', 'breakfast'};

      case 'Bread & Bakery':
        return {'breakfast', 'lunch', 'snack'};

      case 'Vegetables':
      case 'Salads':
        return {'lunch', 'dinner', 'snack'};

      case 'Fruits':
        return {'breakfast', 'snack', 'lunch'};

      case 'Nuts & Seeds':
      case 'Nut Butters':
        return {'breakfast', 'snack'};

      case 'Snacks':
        return {'snack', 'any'};

      case 'Desserts':
        return {'snack', 'any'};

      case 'Fast Food':
      case 'Meals':
      case 'Composed Meals':
        return {'lunch', 'dinner'};

      case 'Soups':
        return {'lunch', 'dinner', 'snack'};

      case 'Processed Meat':
        return {'breakfast', 'lunch'};

      case 'Beverages':
      case 'Condiments':
      case 'Fats & Oils':
      case 'Supplements':
        return {'any'};

      default:
        return {'any'};
    }
  }

  /// Returns true if this food is appropriate for the given [mealSlot].
  bool isSuitableFor(String mealSlot) {
    final slots = suitableMealSlots;
    return slots.contains('any') || slots.contains(mealSlot);
  }

  // ── Nutrition vector for the Euclidean distance algorithm ─────────────────

  /// A 5-dimensional vector representing this food's nutritional fingerprint.
  /// Dimensions: [proteinG, fatG, carbsG, sugarG, sodiumMg].
  ///
  /// All values are in their raw units (grams / mg) — normalization is done
  /// inside [NutritionalProximityAlgorithm] at query time using the candidate
  /// pool's max values so comparisons are always contextually scaled.
  List<double> get nutritionVector => [
        proteinG,
        fatG,
        carbsG,
        sugarG,
        sodiumMg,
      ];

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'calories': calories,
        'protein_g': proteinG,
        'fat_g': fatG,
        'carbs_g': carbsG,
        'sugar_g': sugarG,
        'sodium_mg': sodiumMg,
        'fiber_g': fiberG,
        'source': source,
      };

  factory FoodItem.fromMap(Map<String, Object?> map) => FoodItem(
        id: map['id'] as String,
        name: map['name'] as String,
        category: (map['category'] as String?) ?? 'General',
        calories: (map['calories'] as num).toDouble(),
        proteinG: (map['protein_g'] as num).toDouble(),
        fatG: (map['fat_g'] as num).toDouble(),
        carbsG: (map['carbs_g'] as num).toDouble(),
        sugarG: (map['sugar_g'] as num).toDouble(),
        sodiumMg: (map['sodium_mg'] as num).toDouble(),
        fiberG: (map['fiber_g'] as num).toDouble(),
        source: (map['source'] as String?) ?? 'bundled',
      );

  /// Parse a single food object from the bundled base_foods.json asset.
  /// JSON keys use camelCase to match Dart conventions.
  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        id: json['id'] as String,
        name: json['name'] as String,
        category: (json['category'] as String?) ?? 'General',
        calories: (json['calories'] as num).toDouble(),
        proteinG: (json['proteinG'] as num).toDouble(),
        fatG: (json['fatG'] as num).toDouble(),
        carbsG: (json['carbsG'] as num).toDouble(),
        sugarG: (json['sugarG'] as num).toDouble(),
        sodiumMg: (json['sodiumMg'] as num).toDouble(),
        fiberG: (json['fiberG'] as num).toDouble(),
        source: 'bundled',
      );

  /// Parse a food from the USDA FoodData Central API search response.
  /// The [nutrientMap] should be pre-built by [UsdaApiService] mapping
  /// nutrientId → value for efficient lookup.
  factory FoodItem.fromUsdaJson({
    required int fdcId,
    required String description,
    required String foodCategory,
    required Map<int, double> nutrientMap,
  }) {
    double n(int id) => nutrientMap[id] ?? 0.0;

    return FoodItem(
      id: fdcId.toString(),
      name: _toTitleCase(description),
      category: foodCategory.isNotEmpty ? foodCategory : 'General',
      calories: n(1008),
      proteinG: n(1003),
      fatG: n(1004),
      carbsG: n(1005),
      sugarG: n(2000),
      sodiumMg: n(1093),
      fiberG: n(1079),
      source: 'usda_api',
    );
  }

  /// Converts a USDA description string like "CHICKEN BREAST, RAW"
  /// to "Chicken Breast, Raw" for display.
  static String _toTitleCase(String s) => s
      .toLowerCase()
      .replaceAllMapped(
          RegExp(r'(^|\s)\S'), (m) => m.group(0)!.toUpperCase());

  @override
  String toString() =>
      'FoodItem($name, cal:$calories, P:${proteinG}g, F:${fatG}g, C:${carbsG}g)';
}
