class CalorieCalculator {
  static const _activityMultipliers = [1.0, 1.2, 1.375, 1.55, 1.725, 1.9];

  /// Returns TDEE using Mifflin-St Jeor with biological sex correction.
  ///
  /// [sex]: 0 = not specified (neutral −78), 1 = male (+5), 2 = female (−161)
  /// Returns 0 if any required value is missing (height/weight/age = 0).
  static int calculate({
    required int heightCm,
    required int weightKg,
    required int age,
    required int activityLevel,
    int sex = 0,
  }) {
    if (heightCm == 0 || weightKg == 0 || age == 0) return 0;
    // Mifflin-St Jeor gender constant: male +5, female −161, neutral −78 (midpoint)
    final s = sex == 1 ? 5.0 : sex == 2 ? -161.0 : -78.0;
    final bmr = 10.0 * weightKg + 6.25 * heightCm - 5.0 * age + s;
    final multiplier = _activityMultipliers[activityLevel.clamp(0, 5)];
    return (bmr * multiplier).round();
  }
}
