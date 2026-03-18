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
      .replaceAllMapped(RegExp(r'(^|\s)\S'), (m) => m.group(0)!.toUpperCase());

  @override
  String toString() =>
      'FoodItem($name, cal:$calories, P:${proteinG}g, F:${fatG}g, C:${carbsG}g)';
}
