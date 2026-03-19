import 'food_item.dart';

/// Represents a single food item the user has logged as eaten.
///
/// Nutritional values are stored as the actual consumed amounts (already
/// scaled by serving size), not per-100g. This means the Home page can
/// sum rows directly without any per-serving arithmetic.
///
/// [loggedDate] uses the 'YYYY-MM-DD' format so SQLite can filter by day
/// with a simple string equality / LIKE query.
class FoodLogEntry {
  final int? id;

  /// Links back to the FoodItem that was logged (for future deduplication).
  final String foodItemId;

  /// Display name of the food (stored denormalised for fast rendering).
  final String foodName;

  final String category;

  /// Amount the user ate, in grams.
  final double servingG;

  // ── Actual consumed nutrients (scaled by servingG / 100) ──────────────────

  final double calories;
  final double proteinG;
  final double fatG;
  final double carbsG;
  final double sugarG;
  final double sodiumMg;
  final double fiberG;

  /// Which meal this was logged under: 'breakfast', 'lunch', 'dinner', 'snack'.
  final String mealSlot;

  /// Date the food was logged, formatted as 'YYYY-MM-DD'.
  final String loggedDate;

  /// Unix millisecond timestamp for precise ordering within a day.
  final int loggedAt;

  const FoodLogEntry({
    this.id,
    required this.foodItemId,
    required this.foodName,
    required this.category,
    required this.servingG,
    required this.calories,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.sugarG,
    required this.sodiumMg,
    required this.fiberG,
    required this.mealSlot,
    required this.loggedDate,
    required this.loggedAt,
  });

  /// Creates a log entry from a [FoodItem] given a serving size in grams.
  /// All nutritional values are scaled proportionally from per-100g values.
  factory FoodLogEntry.fromFoodItem(
    FoodItem item,
    double servingG,
    String mealSlot,
  ) {
    final factor = servingG / 100.0;
    final now = DateTime.now();
    final date = '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return FoodLogEntry(
      foodItemId: item.id,
      foodName: item.name,
      category: item.category,
      servingG: servingG,
      calories: item.calories * factor,
      proteinG: item.proteinG * factor,
      fatG: item.fatG * factor,
      carbsG: item.carbsG * factor,
      sugarG: item.sugarG * factor,
      sodiumMg: item.sodiumMg * factor,
      fiberG: item.fiberG * factor,
      mealSlot: mealSlot,
      loggedDate: date,
      loggedAt: now.millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'food_item_id': foodItemId,
        'food_name': foodName,
        'category': category,
        'serving_g': servingG,
        'calories': calories,
        'protein_g': proteinG,
        'fat_g': fatG,
        'carbs_g': carbsG,
        'sugar_g': sugarG,
        'sodium_mg': sodiumMg,
        'fiber_g': fiberG,
        'meal_slot': mealSlot,
        'logged_date': loggedDate,
        'logged_at': loggedAt,
      };

  factory FoodLogEntry.fromMap(Map<String, Object?> map) => FoodLogEntry(
        id: map['id'] as int?,
        foodItemId: map['food_item_id'] as String,
        foodName: map['food_name'] as String,
        category: (map['category'] as String?) ?? 'General',
        servingG: (map['serving_g'] as num).toDouble(),
        calories: (map['calories'] as num).toDouble(),
        proteinG: (map['protein_g'] as num).toDouble(),
        fatG: (map['fat_g'] as num).toDouble(),
        carbsG: (map['carbs_g'] as num).toDouble(),
        sugarG: (map['sugar_g'] as num).toDouble(),
        sodiumMg: (map['sodium_mg'] as num).toDouble(),
        fiberG: (map['fiber_g'] as num).toDouble(),
        mealSlot: (map['meal_slot'] as String?) ?? 'any',
        loggedDate: map['logged_date'] as String,
        loggedAt: map['logged_at'] as int,
      );

  @override
  String toString() =>
      'FoodLogEntry($foodName, ${servingG}g, ${calories.toStringAsFixed(0)} kcal)';
}
