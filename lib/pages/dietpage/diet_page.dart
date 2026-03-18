import 'package:flutter/material.dart';

import '../../algorithm/nutritional_proximity.dart';
import '../../database/db_helper.dart';
import '../../database/food_item.dart';
import '../../database/meal.dart';
import '../../services/food_repository.dart';
import '../../widgets/int_spinner_field.dart';
import '../../widgets/smart_swap_panel.dart';
import 'calorie_calculator.dart';

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  static const _meals = [
    'Healthy Gain',
    'Manage Deficiency',
    'Muscle Gain',
    'Custom',
  ];

  static const _calculatorFields = [
    (label: 'Height (CM)', max: 300),
    (label: 'Weight (KG)', max: 500),
    (label: 'Age',         max: 120),
    (label: 'Activity',    max: 5),
  ];

  final List<int> _values = [0, 0, 0, 0];
  final List<int> _values2 = [0, 0, 0, 0];

  int get _calories => CalorieCalculator.calculate(
        heightCm:      _values[0],
        weightKg:      _values[1],
        age:           _values[2],
        activityLevel: _values[3],
      );

  // ignore: unused_element
  int get _calories2 => CalorieCalculator.calculate(
        heightCm:      _values2[0],
        weightKg:      _values2[1],
        age:           _values2[2],
        activityLevel: _values2[3],
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Diet Plan', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            _MealGrid(meals: _meals),
            const SizedBox(height: 16),
            _CalculatorGrid(
              fields: _calculatorFields,
              onChanged: (index, val) => setState(() => _values[index] = val),
            ),
            const SizedBox(height: 8),
            _CalorieCard(calories: _calories),
            const _TargetMealPlan(),
          ],
        ),
      ),
    );
  }
}

// ── Goal preset grid — stateful, highlights the selected plan ─────────────────

class _MealGrid extends StatefulWidget {
  final List<String> meals;
  const _MealGrid({required this.meals});

  @override
  State<_MealGrid> createState() => _MealGridState();
}

class _MealGridState extends State<_MealGrid> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 60,
      ),
      itemCount: widget.meals.length,
      itemBuilder: (context, index) {
        final isSelected = _selected == index;
        return FilledButton.tonal(
          onPressed: () => setState(() => _selected = index),
          style: isSelected
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                )
              : FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          child: Text(widget.meals[index]),
        );
      },
    );
  }
}

// ── TDEE calculator spinner grid ──────────────────────────────────────────────

class _CalculatorGrid extends StatelessWidget {
  final List<({String label, int max})> fields;
  final void Function(int index, int value) onChanged;
  const _CalculatorGrid({required this.fields, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 150,
      ),
      itemCount: fields.length,
      itemBuilder: (context, index) => IntSpinnerField(
        label: fields[index].label,
        max: fields[index].max,
        onChanged: (val) => onChanged(index, val),
      ),
    );
  }
}

// ── TDEE display card ─────────────────────────────────────────────────────────

class _CalorieCard extends StatelessWidget {
  final int calories;
  const _CalorieCard({required this.calories});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            calories > 0 ? 'Your TDEE is: $calories calories' : 'Your TDEE is: —',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}

// ── Macro target sliders ──────────────────────────────────────────────────────

class _TargetSliders extends StatefulWidget {
  const _TargetSliders();

  @override
  State<_TargetSliders> createState() => _TargetSlidersState();
}

class _TargetSlidersState extends State<_TargetSliders> {
  final List<double> _macros = [0, 0, 0];
  static const _macroNames = ['Protein', 'Fat', 'Carbs'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int index = 0; index < _macroNames.length; index++)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_macroNames[index],
                  style: Theme.of(context).textTheme.bodyLarge),
              Slider(
                value: _macros[index],
                label: _macroNames[index],
                max: 100,
                onChanged: (val) => setState(() => _macros[index] = val),
              ),
            ],
          ),
      ],
    );
  }
}

// ── Meal plan — loads from DB, shows macro chips + Smart Swap ─────────────────

class _MealPlan extends StatefulWidget {
  const _MealPlan();

  @override
  State<_MealPlan> createState() => _MealPlanState();
}

class _MealPlanState extends State<_MealPlan> {
  late final Future<(List<Meal>, List<FoodItem>)> _data = _loadData();

  static Future<(List<Meal>, List<FoodItem>)> _loadData() async {
    final results = await Future.wait([
      DbHelper.getMeals(),
      FoodRepository.getAllBaseFoods(),
    ]);
    return (results[0] as List<Meal>, results[1] as List<FoodItem>);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Meal>, List<FoodItem>)>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final (meals, foodBank) = snapshot.data!;

        return Column(
          children: [
            for (final meal in meals)
              _MealCard(
                meal: meal,
                mealAsFood: _mealToFoodItem(meal),
                foodBank: foodBank,
                mealSlot: meal.mealSlot,
              ),
          ],
        );
      },
    );
  }

  static FoodItem _mealToFoodItem(Meal meal) => FoodItem(
        id: 'meal_${meal.id ?? meal.name}',
        name: meal.name,
        category: 'Meals',
        calories: meal.calories.toDouble(),
        proteinG: meal.proteinG,
        fatG: meal.fatG,
        carbsG: meal.carbsG,
        sugarG: meal.sugarG,
        sodiumMg: meal.sodiumMg,
        fiberG: meal.fiberG,
        source: 'meal',
      );
}

// ── Single meal card ──────────────────────────────────────────────────────────

class _MealCard extends StatelessWidget {
  final Meal meal;
  final FoodItem mealAsFood;
  final List<FoodItem> foodBank;
  final String mealSlot;

  const _MealCard({
    required this.meal,
    required this.mealAsFood,
    required this.foodBank,
    this.mealSlot = 'any',
  });

  @override
  Widget build(BuildContext context) {
    final hasSuggestions = mealAsFood.isUnhealthy &&
        NutritionalProximityAlgorithm.findAlternatives(
          mealAsFood,
          foodBank,
          mealSlot: mealSlot,
          maxResults: 1,
        ).isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(meal.name,
                    style: Theme.of(context).textTheme.bodyMedium),
                Text('${meal.calories} kcal',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 3),
            Text(meal.description,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            MacroChipRow(
              proteinG: meal.proteinG,
              fatG: meal.fatG,
              carbsG: meal.carbsG,
            ),
            if (hasSuggestions)
              SmartSwapPanel(
                food: mealAsFood,
                foodBank: foodBank,
                mealSlot: mealSlot,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Side-by-side: sliders left, meal plan right ───────────────────────────────

class _TargetMealPlan extends StatelessWidget {
  const _TargetMealPlan();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Expanded(child: _TargetSliders()),
          Expanded(child: _MealPlan()),
        ],
      ),
    );
  }
}
