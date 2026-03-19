/// Represents a named meal entry in the user's diet plan.
///
/// A [Meal] is a user-facing scheduled eating event (e.g. "Breakfast")
/// that lives in the local SQLite `meals` table. It carries full
/// nutritional data so macro chips and Smart Swap can operate on it.
///
/// [mealSlot] tells the algorithm which time-of-day context this meal
/// belongs to, so it only suggests contextually appropriate alternatives.
/// Values: 'breakfast', 'lunch', 'dinner', 'snack'.
class Meal {
  final int? id;
  final String name;
  final String description;
  final int calories;

  /// Time-of-day slot for this meal. Used by the Nutritional Proximity
  /// Algorithm to filter candidates to appropriate meal contexts.
  /// Defaults to 'any' if not set (no filtering).
  final String mealSlot;

  // ── Macronutrients (g) ───────────────────────────────────────────────────
  final double proteinG;
  final double fatG;
  final double carbsG;

  // ── Key Micronutrients ───────────────────────────────────────────────────
  final double sugarG;
  final double sodiumMg;
  final double fiberG;

  const Meal({
    this.id,
    required this.name,
    required this.description,
    required this.calories,
    this.mealSlot = 'any',
    this.proteinG = 0.0,
    this.fatG = 0.0,
    this.carbsG = 0.0,
    this.sugarG = 0.0,
    this.sodiumMg = 0.0,
    this.fiberG = 0.0,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'calories': calories,
        'meal_slot': mealSlot,
        'protein_g': proteinG,
        'fat_g': fatG,
        'carbs_g': carbsG,
        'sugar_g': sugarG,
        'sodium_mg': sodiumMg,
        'fiber_g': fiberG,
      };

  factory Meal.fromMap(Map<String, Object?> map) => Meal(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String,
        calories: map['calories'] as int,
        mealSlot: (map['meal_slot'] as String?) ?? 'any',
        proteinG: (map['protein_g'] as num?)?.toDouble() ?? 0.0,
        fatG: (map['fat_g'] as num?)?.toDouble() ?? 0.0,
        carbsG: (map['carbs_g'] as num?)?.toDouble() ?? 0.0,
        sugarG: (map['sugar_g'] as num?)?.toDouble() ?? 0.0,
        sodiumMg: (map['sodium_mg'] as num?)?.toDouble() ?? 0.0,
        fiberG: (map['fiber_g'] as num?)?.toDouble() ?? 0.0,
      );
}
