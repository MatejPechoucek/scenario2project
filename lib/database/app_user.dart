/// Represents the single local user profile for CleanEater.
///
/// There is always exactly one row in the `app_user` table (id = 1).
/// This acts as a lightweight user system without authentication —
/// suitable for a prototype where all data is local.
class AppUser {
  final int id;
  final String name;

  /// Daily calorie target in kcal. Updated when the user calculates TDEE
  /// on the Diet Plan page, or manually on the Profile page.
  final int dailyCalorieGoal;

  // ── Daily macro goals (grams) ─────────────────────────────────────────────

  final double proteinGGoal;
  final double fatGGoal;
  final double carbsGGoal;

  const AppUser({
    this.id = 1,
    this.name = 'User',
    this.dailyCalorieGoal = 2000,
    this.proteinGGoal = 150.0,
    this.fatGGoal = 65.0,
    this.carbsGGoal = 250.0,
  });

  AppUser copyWith({
    String? name,
    int? dailyCalorieGoal,
    double? proteinGGoal,
    double? fatGGoal,
    double? carbsGGoal,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
        proteinGGoal: proteinGGoal ?? this.proteinGGoal,
        fatGGoal: fatGGoal ?? this.fatGGoal,
        carbsGGoal: carbsGGoal ?? this.carbsGGoal,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'daily_calorie_goal': dailyCalorieGoal,
        'protein_g_goal': proteinGGoal,
        'fat_g_goal': fatGGoal,
        'carbs_g_goal': carbsGGoal,
      };

  factory AppUser.fromMap(Map<String, Object?> map) => AppUser(
        id: map['id'] as int,
        name: map['name'] as String,
        dailyCalorieGoal: map['daily_calorie_goal'] as int,
        proteinGGoal: (map['protein_g_goal'] as num).toDouble(),
        fatGGoal: (map['fat_g_goal'] as num).toDouble(),
        carbsGGoal: (map['carbs_g_goal'] as num).toDouble(),
      );
}
