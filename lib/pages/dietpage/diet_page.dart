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
  // ── Goal preset options ───────────────────────────────────────────────────

  static const _mealPresetNames = [
    'Healthy Gain',
    'Manage Deficiency',
    'Muscle Gain',
    'Custom',
  ];

  // Protein / Fat / Carbs slider weights for each preset (sum to 100 each).
  static const _macroPresets = [
    [30.0, 30.0, 40.0], // Healthy Gain
    [25.0, 25.0, 50.0], // Manage Deficiency
    [40.0, 20.0, 40.0], // Muscle Gain
    [50.0, 50.0, 50.0], // Custom — equal weights → 33%/33%/33%
  ];

  // ── TDEE calculator fields ────────────────────────────────────────────────

  static const _calculatorFields = [
    (label: 'Height (CM)', max: 300),
    (label: 'Weight (KG)', max: 500),
    (label: 'Age',         max: 120),
    (label: 'Activity',    max: 5),
  ];

  // ── State ─────────────────────────────────────────────────────────────────

  final List<int> _tdeeValues = [0, 0, 0, 0];
  int _selectedPreset = 0;
  List<double> _macros = List.of(_macroPresets[0]);

  // Meal plan data — owned here so swaps can trigger a reload.
  List<Meal> _meals = [];
  List<FoodItem> _foodBank = [];
  bool _dataLoaded = false;

  int get _tdeeCalories => CalorieCalculator.calculate(
        heightCm:      _tdeeValues[0],
        weightKg:      _tdeeValues[1],
        age:           _tdeeValues[2],
        activityLevel: _tdeeValues[3],
      );

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // FoodRepository is already initialised by the splash screen, so
    // getAllBaseFoods() returns instantly from memory. Only the DB query
    // has real latency (~50ms).
    final results = await Future.wait([
      DbHelper.getMeals(),
      FoodRepository.getAllBaseFoods(),
    ]);
    if (mounted) {
      setState(() {
        _meals    = results[0] as List<Meal>;
        _foodBank = results[1] as List<FoodItem>;
        _dataLoaded = true;
      });
    }
  }

  // Called after a successful swap so the meal cards reflect the new data.
  Future<void> _onMealSwapped() => _loadData();

  void _onPresetSelected(int index) {
    setState(() {
      _selectedPreset = index;
      _macros = List.of(_macroPresets[index]);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Diet Plan',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),

              // Goal preset buttons
              _MealGrid(
                meals: _mealPresetNames,
                selectedIndex: _selectedPreset,
                onSelected: _onPresetSelected,
              ),
              const SizedBox(height: 16),

              // TDEE calculator
              _CalculatorGrid(
                fields: _calculatorFields,
                onChanged: (i, v) =>
                    setState(() => _tdeeValues[i] = v),
              ),
              const SizedBox(height: 8),
              _CalorieCard(calories: _tdeeCalories),

              // Macro sliders (left) + meal plan (right)
              _TargetMealPlan(
                macros: _macros,
                onMacrosChanged: (v) => setState(() => _macros = v),
                meals: _meals,
                foodBank: _foodBank,
                dataLoaded: _dataLoaded,
                onMealSwapped: _onMealSwapped,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Goal preset grid ──────────────────────────────────────────────────────────

class _MealGrid extends StatelessWidget {
  final List<String> meals;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _MealGrid({
    required this.meals,
    required this.selectedIndex,
    required this.onSelected,
  });

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
      itemCount: meals.length,
      itemBuilder: (context, index) {
        final isSelected = selectedIndex == index;
        return FilledButton.tonal(
          onPressed: () => onSelected(index),
          style: isSelected
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                )
              : FilledButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          child: Text(meals[index]),
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
            calories > 0
                ? 'Your TDEE is: $calories calories'
                : 'Your TDEE is: —',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}

// ── Macro target sliders ──────────────────────────────────────────────────────

class _TargetSliders extends StatelessWidget {
  final List<double> values;
  final ValueChanged<List<double>> onChanged;

  static const _macroNames = ['Protein', 'Fat', 'Carbs'];

  const _TargetSliders({required this.values, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final total = values.fold(0.0, (sum, v) => sum + v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _macroNames.length; i++)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_macroNames[i],
                      style: Theme.of(context).textTheme.bodyLarge),
                  Text(
                    total > 0
                        ? '${(values[i] / total * 100).round()}%'
                        : '—',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              Slider(
                value: values[i],
                max: 100,
                onChanged: (val) {
                  final updated = List<double>.of(values);
                  updated[i] = val;
                  onChanged(updated);
                },
              ),
            ],
          ),
      ],
    );
  }
}

// ── Side-by-side: sliders left, meal plan right ───────────────────────────────

class _TargetMealPlan extends StatelessWidget {
  final List<double> macros;
  final ValueChanged<List<double>> onMacrosChanged;
  final List<Meal> meals;
  final List<FoodItem> foodBank;
  final bool dataLoaded;
  final Future<void> Function() onMealSwapped;

  const _TargetMealPlan({
    required this.macros,
    required this.onMacrosChanged,
    required this.meals,
    required this.foodBank,
    required this.dataLoaded,
    required this.onMealSwapped,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TargetSliders(values: macros, onChanged: onMacrosChanged),
          ),
          Expanded(
            child: _MealPlan(
              meals: meals,
              foodBank: foodBank,
              dataLoaded: dataLoaded,
              macroTargets: macros,
              onMealSwapped: onMealSwapped,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meal plan list ────────────────────────────────────────────────────────────

class _MealPlan extends StatelessWidget {
  final List<Meal> meals;
  final List<FoodItem> foodBank;
  final bool dataLoaded;
  final List<double> macroTargets;
  final Future<void> Function() onMealSwapped;

  const _MealPlan({
    required this.meals,
    required this.foodBank,
    required this.dataLoaded,
    required this.macroTargets,
    required this.onMealSwapped,
  });

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

  @override
  Widget build(BuildContext context) {
    if (!dataLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (meals.isEmpty) {
      return Center(
        child: Text('No meals found.',
            style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return Column(
      children: [
        for (final meal in meals)
          _MealCard(
            meal: meal,
            mealAsFood: _mealToFoodItem(meal),
            foodBank: foodBank,
            macroTargets: macroTargets,
            onMealSwapped: onMealSwapped,
          ),
      ],
    );
  }
}

// ── Single meal card ──────────────────────────────────────────────────────────

class _MealCard extends StatelessWidget {
  final Meal meal;
  final FoodItem mealAsFood;
  final List<FoodItem> foodBank;
  final List<double> macroTargets;
  final Future<void> Function() onMealSwapped;

  const _MealCard({
    required this.meal,
    required this.mealAsFood,
    required this.foodBank,
    required this.macroTargets,
    required this.onMealSwapped,
  });

  void _openSwapSheet(BuildContext context) {
    // Run the algorithm synchronously — it's fast (<5ms for 250 foods).
    final suggestions = NutritionalProximityAlgorithm.findSimilar(
      mealAsFood,
      foodBank,
      maxResults: 5,
      macroTargets: macroTargets,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => _SwapSheet(
          meal: meal,
          suggestions: suggestions,
          scrollController: scrollController,
          onMealSwapped: onMealSwapped,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => _openSwapSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(meal.name,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  Text('${meal.calories} kcal',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                meal.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              MacroChipRow(
                proteinG: meal.proteinG,
                fatG: meal.fatG,
                carbsG: meal.carbsG,
              ),
              const SizedBox(height: 4),
              Text(
                'Tap for alternatives',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Swap bottom sheet ─────────────────────────────────────────────────────────

class _SwapSheet extends StatelessWidget {
  final Meal meal;
  final List<SwapSuggestion> suggestions;
  final ScrollController scrollController;
  final Future<void> Function() onMealSwapped;

  const _SwapSheet({
    required this.meal,
    required this.suggestions,
    required this.scrollController,
    required this.onMealSwapped,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alternatives for ${meal.name}',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                'Tap "Swap" to replace your meal with this food at the same calories.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),

        // Original meal summary
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current: ${meal.description}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      MacroChipRow(
                        proteinG: meal.proteinG,
                        fatG: meal.fatG,
                        carbsG: meal.carbsG,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('${meal.calories} kcal',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),

        const Divider(height: 1),

        // Suggestions list
        Expanded(
          child: suggestions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No similar foods found in the food bank.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _SwapTile(
                    suggestion: suggestions[i],
                    meal: meal,
                    onMealSwapped: onMealSwapped,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Single alternative tile with swap button ──────────────────────────────────

class _SwapTile extends StatefulWidget {
  final SwapSuggestion suggestion;
  final Meal meal;
  final Future<void> Function() onMealSwapped;

  const _SwapTile({
    required this.suggestion,
    required this.meal,
    required this.onMealSwapped,
  });

  @override
  State<_SwapTile> createState() => _SwapTileState();
}

class _SwapTileState extends State<_SwapTile> {
  bool _swapping = false;

  Future<void> _doSwap() async {
    setState(() => _swapping = true);
    final alt = widget.suggestion.alternative;

    // Calculate the serving size (g) that matches the original meal's calories.
    // Food bank values are per 100g; meals store totals.
    final servingG = alt.calories > 0
        ? (widget.meal.calories / alt.calories * 100)
        : 100.0;
    final factor = servingG / 100.0;

    final updated = Meal(
      id: widget.meal.id,
      name: widget.meal.name,
      description: alt.name,
      calories: widget.meal.calories, // keep same total calories
      mealSlot: widget.meal.mealSlot,
      proteinG: alt.proteinG * factor,
      fatG: alt.fatG * factor,
      carbsG: alt.carbsG * factor,
      sugarG: alt.sugarG * factor,
      sodiumMg: alt.sodiumMg * factor,
      fiberG: alt.fiberG * factor,
    );

    await DbHelper.updateMeal(updated);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Swapped to ${alt.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await widget.onMealSwapped();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final alt = widget.suggestion.alternative;

    // Serving size to match the original meal's calorie total.
    final servingG = alt.calories > 0
        ? (widget.meal.calories / alt.calories * 100).round()
        : 100;
    final factor = servingG / 100.0;

    // Scaled macro values at the computed serving.
    final servingProtein = alt.proteinG * factor;
    final servingFat = alt.fatG * factor;
    final servingCarbs = alt.carbsG * factor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name row + serving + calories
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alt.name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alt.category,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '~${servingG}g',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${widget.meal.calories} kcal',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: Colors.green.shade700),
                  ),
                  Text(
                    '(${alt.calories.round()} per 100g)',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Macro chips at serving size
          MacroChipRow(
            proteinG: servingProtein,
            fatG: servingFat,
            carbsG: servingCarbs,
          ),

          // Delta chips (e.g. "+12% protein", "-8% fat")
          if (widget.suggestion.improvements.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: widget.suggestion.improvements
                  .map((imp) => _ImprovementChip(label: imp))
                  .toList(),
            ),
          ],

          const SizedBox(height: 10),

          // Swap button
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: _swapping ? null : _doSwap,
              child: _swapping
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Swap to this'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Improvement / delta chip ──────────────────────────────────────────────────

class _ImprovementChip extends StatelessWidget {
  final String label;
  const _ImprovementChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPositive = label.startsWith('+');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isPositive ? cs.primaryContainer : cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: isPositive ? cs.onPrimaryContainer : cs.onTertiaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
