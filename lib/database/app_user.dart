/// Represents the single local user profile for CleanEater.
///
/// There is always exactly one row in the `app_user` table (id = 1).
class AppUser {
  final int id;
  final String name;

  /// Daily calorie target in kcal — TDEE minus any weight-loss deficit.
  final int dailyCalorieGoal;

  // ── Daily macro goals (grams) ─────────────────────────────────────────────

  final double proteinGGoal;
  final double fatGGoal;
  final double carbsGGoal;

  // ── TDEE calculator inputs (persisted so the page restores them) ──────────

  final int heightCm;
  final int weightKg;
  final int age;
  final int activityLevel;

  /// Biological sex for Mifflin-St Jeor calculation.
  /// 0 = not specified, 1 = male, 2 = female.
  final int sex;

  /// Weekly weight-loss target in kg (0 = maintain).
  /// Used to compute the calorie deficit: deficit = weeklyLossKg × 7700 / 7.
  final double weeklyLossKg;

  const AppUser({
    this.id = 1,
    this.name = 'User',
    this.dailyCalorieGoal = 2000,
    this.proteinGGoal = 150.0,
    this.fatGGoal = 65.0,
    this.carbsGGoal = 250.0,
    this.heightCm = 0,
    this.weightKg = 0,
    this.age = 0,
    this.activityLevel = 0,
    this.sex = 0,
    this.weeklyLossKg = 0.0,
  });

  /// Daily calorie deficit derived from [weeklyLossKg].
  /// 1 kg of body fat ≈ 7700 kcal; spread over 7 days.
  int get dailyDeficit => (weeklyLossKg * 7700 / 7).round();

  AppUser copyWith({
    String? name,
    int? dailyCalorieGoal,
    double? proteinGGoal,
    double? fatGGoal,
    double? carbsGGoal,
    int? heightCm,
    int? weightKg,
    int? age,
    int? activityLevel,
    int? sex,
    double? weeklyLossKg,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
        proteinGGoal: proteinGGoal ?? this.proteinGGoal,
        fatGGoal: fatGGoal ?? this.fatGGoal,
        carbsGGoal: carbsGGoal ?? this.carbsGGoal,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        age: age ?? this.age,
        activityLevel: activityLevel ?? this.activityLevel,
        sex: sex ?? this.sex,
        weeklyLossKg: weeklyLossKg ?? this.weeklyLossKg,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'daily_calorie_goal': dailyCalorieGoal,
        'protein_g_goal': proteinGGoal,
        'fat_g_goal': fatGGoal,
        'carbs_g_goal': carbsGGoal,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'age': age,
        'activity_level': activityLevel,
        'sex': sex,
        'weekly_loss_kg': weeklyLossKg,
      };

  factory AppUser.fromMap(Map<String, Object?> map) => AppUser(
        id: map['id'] as int,
        name: map['name'] as String,
        dailyCalorieGoal: map['daily_calorie_goal'] as int,
        proteinGGoal: (map['protein_g_goal'] as num).toDouble(),
        fatGGoal: (map['fat_g_goal'] as num).toDouble(),
        carbsGGoal: (map['carbs_g_goal'] as num).toDouble(),
        heightCm: (map['height_cm'] as int?) ?? 0,
        weightKg: (map['weight_kg'] as int?) ?? 0,
        age: (map['age'] as int?) ?? 0,
        activityLevel: (map['activity_level'] as int?) ?? 0,
        sex: (map['sex'] as int?) ?? 0,
        weeklyLossKg: (map['weekly_loss_kg'] as num?)?.toDouble() ?? 0.0,
      );
}
