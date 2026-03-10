class CalorieCalculator {
  static const _activityMultipliers = [1.0, 1.2, 1.375, 1.55, 1.725, 1.9];

  /// Returns TDEE using Mifflin-St Jeor (gender-neutral average).
  /// Returns 0 if any required value is missing.
  static int calculate({
    required int heightCm,
    required int weightKg,
    required int age,
    required int activityLevel, // 0–5
  }) {
    if (heightCm == 0 || weightKg == 0 || age == 0) return 0;
    final bmr = 10 * weightKg + 6.25 * heightCm - 5 * age - 78;
    final multiplier = _activityMultipliers[activityLevel.clamp(0, 5)];
    return (bmr * multiplier).round();
  }
}
