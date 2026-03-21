import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../algorithm/nutritional_proximity.dart';
import '../../database/app_user.dart';
import '../../database/db_helper.dart';
import '../../database/food_item.dart';
import '../../database/food_log_entry.dart';
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

class _DietPageState extends State<DietPage> with TickerProviderStateMixin {
  late final TabController _tabController;
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

  // Persisted calculator values — restored from DB on load.
  List<int> _tdeeValues = [0, 0, 0, 0];
  // Biological sex: 0=not set, 1=male, 2=female. Persisted to app_user.
  int _sex = 0;
  // Tracks whether the user data has loaded so spinners can be built with
  // the correct initial values (using ValueKey to force a fresh widget).
  bool _userLoaded = false;
  // Optional TDEE override — when non-null, replaces the calculated value.
  int? _tdeeOverride;

  int _selectedPreset = 0;
  List<double> _macros = List.of(_macroPresets[0]);

  // Meal plan data — owned here so swaps can trigger a reload.
  List<Meal> _meals = [];
  List<FoodItem> _foodBank = [];
  bool _dataLoaded = false;

  // Food log history (all entries, newest first).
  List<FoodLogEntry> _foodLog = [];

  // Current user — needed to persist TDEE and goals.
  AppUser? _user;

  // Debounce timer for auto-saving calculator inputs.
  Timer? _saveDebounce;

  /// Raw TDEE from the Mifflin-St Jeor calculator (ignores override).
  int get _calculatedTdee => CalorieCalculator.calculate(
        heightCm:      _tdeeValues[0],
        weightKg:      _tdeeValues[1],
        age:           _tdeeValues[2],
        activityLevel: _tdeeValues[3],
        sex:           _sex,
      );

  /// Effective TDEE — uses the user's custom override if set, otherwise
  /// falls back to the calculated value.
  int get _tdeeCalories => (_tdeeOverride != null && _tdeeOverride! > 0)
      ? _tdeeOverride!
      : _calculatedTdee;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _saveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      DbHelper.getMeals(),
      FoodRepository.getAllBaseFoods(),
      DbHelper.getAllFoodLog(),
      DbHelper.getUser(),
    ]);
    if (mounted) {
      final user = results[3] as AppUser;
      setState(() {
        _meals    = results[0] as List<Meal>;
        _foodBank = results[1] as List<FoodItem>;
        _foodLog  = results[2] as List<FoodLogEntry>;
        _user     = user;
        // Restore calculator inputs from persisted user data.
        _tdeeValues = [
          user.heightCm,
          user.weightKg,
          user.age,
          user.activityLevel,
        ];
        _sex         = user.sex;
        _userLoaded  = true;
        _dataLoaded  = true;
      });
    }
  }

  // ── Spinner change — debounce-save to DB ───────────────────────────────────

  void _onSpinnerChanged(int index, int value) {
    setState(() => _tdeeValues[index] = value);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _saveCalculatorInputs);
  }

  Future<void> _saveCalculatorInputs() async {
    if (_user == null) return;
    final updated = _user!.copyWith(
      heightCm:      _tdeeValues[0],
      weightKg:      _tdeeValues[1],
      age:           _tdeeValues[2],
      activityLevel: _tdeeValues[3],
      sex:           _sex,
    );
    await DbHelper.updateUser(updated);
    if (mounted) setState(() => _user = updated);
  }

  Future<void> _onSexChanged(int sex) async {
    setState(() => _sex = sex);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), _saveCalculatorInputs);
  }

  void _onTdeeOverride(int? value) => setState(() => _tdeeOverride = value);

  // ── Weight loss goal selector ──────────────────────────────────────────────

  Future<void> _setWeeklyLoss(double kg) async {
    if (_user == null) return;
    final updated = _user!.copyWith(weeklyLossKg: kg);
    await DbHelper.updateUser(updated);
    if (mounted) setState(() => _user = updated);
  }

  // ── Set as goal (TDEE minus deficit) ──────────────────────────────────────

  Future<void> _saveTdeeAsGoal() async {
    final tdee = _tdeeCalories;
    if (tdee <= 0 || _user == null) return;

    final deficit      = _user!.dailyDeficit;
    final effectiveKcal = (tdee - deficit).clamp(1200, 99999);

    final total      = _macros.fold(0.0, (s, v) => s + v);
    final proteinPct = total > 0 ? _macros[0] / total : 0.30;
    final fatPct     = total > 0 ? _macros[1] / total : 0.30;
    final carbsPct   = total > 0 ? _macros[2] / total : 0.40;

    final proteinG = (effectiveKcal * proteinPct) / 4.0;
    final fatG     = (effectiveKcal * fatPct)     / 9.0;
    final carbsG   = (effectiveKcal * carbsPct)   / 4.0;

    final updated = _user!.copyWith(
      dailyCalorieGoal: effectiveKcal,
      proteinGGoal: proteinG,
      fatGGoal: fatG,
      carbsGGoal: carbsG,
      heightCm:      _tdeeValues[0],
      weightKg:      _tdeeValues[1],
      age:           _tdeeValues[2],
      activityLevel: _tdeeValues[3],
    );
    await DbHelper.updateUser(updated);
    if (mounted) {
      setState(() => _user = updated);
      final deficitLabel = deficit > 0 ? ' − $deficit deficit' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Goal set to $effectiveKcal kcal/day'
            '$deficitLabel  '
            '(P ${proteinG.toStringAsFixed(0)}g  '
            'F ${fatG.toStringAsFixed(0)}g  '
            'C ${carbsG.toStringAsFixed(0)}g)',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          // ── Tab bar ──────────────────────────────────────────────────────
          ColoredBox(
            color: cs.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.tune, size: 18), text: 'My Plan'),
                Tab(icon: Icon(Icons.insights_outlined, size: 18), text: 'Insights'),
                Tab(icon: Icon(Icons.bar_chart_outlined, size: 18), text: 'History'),
              ],
              labelStyle: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              unselectedLabelStyle: theme.textTheme.labelMedium,
              indicatorSize: TabBarIndicatorSize.tab,
            ),
          ),

          // ── Tab views ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPlanTab(),
                _buildInsightsTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab: My Plan ──────────────────────────────────────────────────────────

  Widget _buildPlanTab() {
    final user = _user;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Goal preset buttons
          _MealGrid(
            meals: _mealPresetNames,
            selectedIndex: _selectedPreset,
            onSelected: _onPresetSelected,
          ),
          const SizedBox(height: 16),

          // TDEE calculator
          if (_userLoaded) ...[
            _CalculatorGrid(
              fields: _calculatorFields,
              initialValues: _tdeeValues,
              onChanged: _onSpinnerChanged,
            ),
            const SizedBox(height: 8),
            _SexSelector(selected: _sex, onChanged: _onSexChanged),
          ] else
            const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 8),

          _CalorieCard(
            calculatedCalories: _calculatedTdee,
            overrideCalories: _tdeeOverride,
            onSetGoal: _tdeeCalories > 0 ? _saveTdeeAsGoal : null,
            onOverride: _onTdeeOverride,
          ),

          // Weight loss selector — only shown once TDEE is calculated
          if (_tdeeCalories > 0 && user != null) ...[
            const SizedBox(height: 8),
            _WeightLossSelector(
              selected: user.weeklyLossKg,
              tdee: _tdeeCalories,
              onSelected: _setWeeklyLoss,
            ),
          ],

          const SizedBox(height: 16),

          // Macro sliders (left) + meal plan with Smart Swap (right)
          _TargetMealPlan(
            macros: _macros,
            onMacrosChanged: (v) => setState(() => _macros = v),
            meals: _meals,
            foodBank: _foodBank,
            dataLoaded: _dataLoaded,
            onMealSwapped: _onMealSwapped,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Tab: Insights ─────────────────────────────────────────────────────────

  Widget _buildInsightsTab() {
    final user = _user;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NutritionFeedbackPanel(user: user),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Tab: History ──────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FoodHistory(log: _foodLog, user: _user),
          const SizedBox(height: 24),
        ],
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
  final List<int> initialValues;
  final void Function(int index, int value) onChanged;

  const _CalculatorGrid({
    required this.fields,
    required this.initialValues,
    required this.onChanged,
  });

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
        initialValue: initialValues[index],
        onChanged: (val) => onChanged(index, val),
      ),
    );
  }
}

// ── TDEE display card ─────────────────────────────────────────────────────────

class _CalorieCard extends StatefulWidget {
  final int calculatedCalories;
  final int? overrideCalories;
  final VoidCallback? onSetGoal;
  final ValueChanged<int?> onOverride;

  const _CalorieCard({
    required this.calculatedCalories,
    required this.onOverride,
    this.overrideCalories,
    this.onSetGoal,
  });

  @override
  State<_CalorieCard> createState() => _CalorieCardState();
}

class _CalorieCardState extends State<_CalorieCard> {
  bool _showOverrideField = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _displayCalories =>
      widget.overrideCalories ?? widget.calculatedCalories;

  void _applyOverride() {
    final val = int.tryParse(_controller.text.trim());
    widget.onOverride(val != null && val > 0 ? val : null);
    setState(() => _showOverrideField = false);
  }

  void _clearOverride() {
    _controller.clear();
    widget.onOverride(null);
    setState(() => _showOverrideField = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasCalc = widget.calculatedCalories > 0;
    final hasOverride = widget.overrideCalories != null;

    return Card(
      color: _displayCalories > 0 ? cs.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasOverride ? 'Your TDEE (custom)' : 'Your TDEE',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _displayCalories > 0
                              ? cs.onPrimaryContainer.withValues(alpha: 0.7)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _displayCalories > 0
                            ? '$_displayCalories kcal / day'
                            : '—',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _displayCalories > 0
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                        ),
                      ),
                      if (hasOverride && hasCalc)
                        Text(
                          'Calculated: ${widget.calculatedCalories} kcal',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color:
                                cs.onPrimaryContainer.withValues(alpha: 0.55),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.onSetGoal != null)
                  FilledButton.tonal(
                    onPressed: widget.onSetGoal,
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                    child: const Text('Set as goal'),
                  ),
              ],
            ),
            // Override row
            const SizedBox(height: 6),
            if (_showOverrideField)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        hintText: 'Enter your TDEE',
                        border: const OutlineInputBorder(),
                        suffixText: 'kcal',
                      ),
                      onSubmitted: (_) => _applyOverride(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(onPressed: _applyOverride, child: const Text('Apply')),
                  TextButton(
                    onPressed: () => setState(() => _showOverrideField = false),
                    child: const Text('Cancel'),
                  ),
                ],
              )
            else
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _showOverrideField = true),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Override TDEE'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor:
                          cs.onPrimaryContainer.withValues(alpha: 0.6),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  if (hasOverride) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _clearOverride,
                      icon: const Icon(Icons.close, size: 14),
                      label: const Text('Reset'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor:
                            cs.onPrimaryContainer.withValues(alpha: 0.6),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Weight loss selector ──────────────────────────────────────────────────────

class _WeightLossSelector extends StatelessWidget {
  final double selected;  // weeklyLossKg
  final int tdee;
  final ValueChanged<double> onSelected;

  const _WeightLossSelector({
    required this.selected,
    required this.tdee,
    required this.onSelected,
  });

  static const _options = [
    (kg: 0.0,   label: 'Maintain',      sub: 'No deficit'),
    (kg: 0.25,  label: '−0.25 kg/wk',   sub: '−275 kcal/day'),
    (kg: 0.5,   label: '−0.5 kg/wk',    sub: '−550 kcal/day'),
    (kg: 1.0,   label: '−1 kg/wk',      sub: '−1100 kcal/day'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly weight-loss goal',
                style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final opt in _options) ...[
                  Expanded(child: _LossButton(
                    label: opt.label,
                    sub: opt.sub,
                    effective: (tdee - (opt.kg * 7700 / 7).round())
                        .clamp(1200, 99999),
                    isSelected: (selected - opt.kg).abs() < 0.01,
                    onTap: () => onSelected(opt.kg),
                  )),
                  if (opt != _options.last) const SizedBox(width: 6),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LossButton extends StatelessWidget {
  final String label;
  final String sub;
  final int effective;
  final bool isSelected;
  final VoidCallback onTap;

  const _LossButton({
    required this.label,
    required this.sub,
    required this.effective,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected ? cs.onPrimary : cs.onSurface,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              '$effective kcal',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? cs.onPrimary.withValues(alpha: 0.85)
                    : cs.primary,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              sub,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? cs.onPrimary.withValues(alpha: 0.6)
                    : cs.onSurfaceVariant,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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

// ── Food log history ──────────────────────────────────────────────────────────

/// Shows the full food log history with a multi-week calorie bar chart at the
/// top and a scrollable list of all entries grouped by date below it.
class _FoodHistory extends StatefulWidget {
  final List<FoodLogEntry> log;
  final AppUser? user;

  const _FoodHistory({required this.log, this.user});

  @override
  State<_FoodHistory> createState() => _FoodHistoryState();
}

class _FoodHistoryState extends State<_FoodHistory> {
  // Chart time span in weeks (1–6).
  int _weeks = 1;

  // ── Derived helpers ────────────────────────────────────────────────────────

  Map<String, List<FoodLogEntry>> get _byDate {
    final map = <String, List<FoodLogEntry>>{};
    for (final e in widget.log) {
      map.putIfAbsent(e.loggedDate, () => []).add(e);
    }
    return map;
  }

  /// Returns (dayLabel, totalKcal) tuples for the last [_weeks] * 7 days.
  List<(String, double)> _lastNDays() {
    final totalDays = _weeks * 7;
    final today = DateTime.now();
    return List.generate(totalDays, (i) {
      final day = today.subtract(Duration(days: totalDays - 1 - i));
      final dateStr = '${day.year}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
      final entries = widget.log.where((e) => e.loggedDate == dateStr);
      final total = entries.fold(0.0, (s, e) => s + e.calories);
      // For multi-week spans label as day-of-month; single week uses short day name
      final label = _weeks == 1
          ? _kShortDays[day.weekday % 7]
          : '${day.day}';
      return (label, total);
    });
  }

  static const _kShortDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _kMonths = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final month = int.tryParse(parts[1]) ?? 1;
    return '${_kMonths[month - 1]} ${parts[2]}, ${parts[0]}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekLabel = _weeks == 1 ? 'Last 7 days' : 'Last $_weeks weeks';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Food History',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text('$weekLabel & all logged foods',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ],
              ),
            ),
            // Week selector (1–6)
            _WeekSelector(selected: _weeks, onChanged: (w) => setState(() => _weeks = w)),
          ],
        ),
        const SizedBox(height: 16),
        _buildChart(theme),
        const SizedBox(height: 20),
        if (widget.log.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No foods logged yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ),
          )
        else
          ..._buildGroupedList(theme),
      ],
    );
  }

  // ── Bar chart (adjustable time span) ──────────────────────────────────────

  Widget _buildChart(ThemeData theme) {
    final days = _lastNDays();
    final goalKcal = widget.user?.dailyCalorieGoal.toDouble() ?? 0;
    final maxY = days.map((d) => d.$2).fold(goalKcal, (a, b) => a > b ? a : b);
    final chartMax = (maxY * 1.2).clamp(500.0, double.infinity);
    final cs = theme.colorScheme;

    final todayIndex = days.length - 1;

    // How many bottom-axis labels to show (avoid crowding for 6-week spans)
    final labelEvery = _weeks <= 2 ? 1 : _weeks <= 4 ? 2 : 3;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                children: [
                  Text(
                    _weeks == 1 ? 'Calories — last 7 days' : 'Calories — last $_weeks weeks',
                    style: theme.textTheme.labelLarge,
                  ),
                  if (goalKcal > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 16,
                      height: 2,
                      color: cs.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Goal',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: chartMax,
                  minY: 0,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final d = days[group.x];
                        return BarTooltipItem(
                          '${d.$1}\n${rod.toY.toStringAsFixed(0)} kcal',
                          TextStyle(
                            color: cs.onInverseSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  extraLinesData: goalKcal > 0
                      ? ExtraLinesData(horizontalLines: [
                          HorizontalLine(
                            y: goalKcal,
                            color: cs.primary.withValues(alpha: 0.45),
                            strokeWidth: 1.5,
                            dashArray: [6, 4],
                          ),
                        ])
                      : null,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= days.length) {
                            return const SizedBox.shrink();
                          }
                          if (idx % labelEvery != 0 && idx != todayIndex) {
                            return const SizedBox.shrink();
                          }
                          final label = days[idx].$1;
                          final isToday = idx == todayIndex;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isToday
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                                fontWeight: isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: chartMax / 4,
                        getTitlesWidget: (value, meta) => Text(
                          value == 0
                              ? '0'
                              : '${(value / 1000).toStringAsFixed(1)}k',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: chartMax / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(days.length, (i) {
                    final kcal = days[i].$2;
                    final isToday = i == todayIndex;
                    // Bar width scales down for multi-week views
                    final barWidth = _weeks <= 1 ? 22.0 : _weeks <= 2 ? 14.0 : _weeks <= 3 ? 10.0 : 7.0;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: kcal == 0 ? 0.5 : kcal,
                          color: kcal == 0
                              ? cs.outlineVariant.withValues(alpha: 0.3)
                              : isToday
                                  ? cs.primary
                                  : cs.primary.withValues(alpha: 0.55),
                          width: barWidth,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grouped history list ───────────────────────────────────────────────────

  List<Widget> _buildGroupedList(ThemeData theme) {
    final grouped = _byDate;
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return [
      for (final date in sortedDates) ...[
        _HistoryDateHeader(
          label: _formatDate(date),
          totalKcal: grouped[date]!.fold(0.0, (s, e) => s + e.calories),
          theme: theme,
        ),
        for (final entry in grouped[date]!)
          _HistoryEntryTile(entry: entry, theme: theme),
        const SizedBox(height: 8),
      ],
    ];
  }
}

// ── History date section header ────────────────────────────────────────────────

class _HistoryDateHeader extends StatelessWidget {
  final String label;
  final double totalKcal;
  final ThemeData theme;

  const _HistoryDateHeader({
    required this.label,
    required this.totalKcal,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      child: Row(
        children: [
          Text(label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              )),
          const Spacer(),
          Text(
            '${totalKcal.toStringAsFixed(0)} kcal total',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single history entry row ───────────────────────────────────────────────────

class _HistoryEntryTile extends StatelessWidget {
  final FoodLogEntry entry;
  final ThemeData theme;

  const _HistoryEntryTile({required this.entry, required this.theme});

  static const _slotColors = {
    'breakfast': Color(0xFFFFA000),
    'lunch': Color(0xFF43A047),
    'dinner': Color(0xFF7B1FA2),
    'snack': Color(0xFF00897B),
  };

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final slotColor = _slotColors[entry.mealSlot] ?? const Color(0xFF9E9E9E);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: slotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.foodName,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${entry.servingG.toStringAsFixed(0)}g · '
                  'P${entry.proteinG.toStringAsFixed(1)} '
                  'F${entry.fatG.toStringAsFixed(1)} '
                  'C${entry.carbsG.toStringAsFixed(1)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: slotColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              entry.mealSlot,
              style: theme.textTheme.labelSmall?.copyWith(
                color: slotColor,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${entry.calories.toStringAsFixed(0)} kcal',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Week selector (1–6 weeks) ─────────────────────────────────────────────────

class _WeekSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _WeekSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int w = 1; w <= 6; w++)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: GestureDetector(
              onTap: () => onChanged(w),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selected == w ? cs.primary : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${w}W',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected == w ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Biological sex selector ────────────────────────────────────────────────────

class _SexSelector extends StatelessWidget {
  final int selected; // 0=not set, 1=male, 2=female
  final ValueChanged<int> onChanged;

  const _SexSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    const options = [
      (value: 0, label: 'Not specified'),
      (value: 1, label: 'Male'),
      (value: 2, label: 'Female'),
    ];

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Text('Biological sex',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(width: 8),
            Text(
              '(affects TDEE)',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
            ),
            const Spacer(),
            for (final opt in options) ...[
              GestureDetector(
                onTap: () => onChanged(opt.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected == opt.value
                        ? cs.primary
                        : cs.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected == opt.value
                          ? cs.primary
                          : cs.outlineVariant,
                    ),
                  ),
                  child: Text(
                    opt.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected == opt.value
                          ? cs.onPrimary
                          : cs.onSurface,
                    ),
                  ),
                ),
              ),
              if (opt != options.last) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Nutrition Feedback Panel (3-week rolling analysis) ────────────────────────

class _NutritionFeedbackPanel extends StatefulWidget {
  final AppUser user;

  const _NutritionFeedbackPanel({required this.user});

  @override
  State<_NutritionFeedbackPanel> createState() =>
      _NutritionFeedbackPanelState();
}

class _NutritionFeedbackPanelState extends State<_NutritionFeedbackPanel> {
  Map<String, double>? _avgs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_NutritionFeedbackPanel old) {
    super.didUpdateWidget(old);
    if (old.user.dailyCalorieGoal != widget.user.dailyCalorieGoal) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final avgs = await DbHelper.getRollingAverages(21);
    if (mounted) setState(() { _avgs = avgs; _loading = false; });
  }

  // Generates non-punitive insight strings based on 3-week averages vs goals.
  List<_Insight> _buildInsights(Map<String, double> avgs) {
    final insights = <_Insight>[];
    final days = avgs['days'] ?? 0;
    if (days < 3) return insights; // not enough data

    final calGoal = widget.user.dailyCalorieGoal.toDouble();
    final proGoal = widget.user.proteinGGoal;
    final avgCal = avgs['calories'] ?? 0;
    final avgPro = avgs['protein'] ?? 0;
    final avgSug = avgs['sugar'] ?? 0;
    final avgFib = avgs['fiber'] ?? 0;

    // Calorie insights
    if (calGoal > 0) {
      final ratio = avgCal / calGoal;
      if (ratio >= 0.9 && ratio <= 1.10) {
        insights.add(_Insight(
          icon: Icons.check_circle_outline,
          title: 'Calorie target on track',
          body: 'Your average has been ${avgCal.toStringAsFixed(0)} kcal/day — '
              'right in line with your ${calGoal.toStringAsFixed(0)} kcal goal. '
              'Keep it up!',
          positive: true,
        ));
      } else if (ratio > 1.15) {
        insights.add(_Insight(
          icon: Icons.info_outline,
          title: 'Slightly above your calorie goal',
          body: 'Over the past 3 weeks you\'ve averaged '
              '${avgCal.toStringAsFixed(0)} kcal/day. '
              'Swapping one high-calorie snack per day could make a big difference.',
          positive: false,
        ));
      } else if (ratio < 0.80) {
        insights.add(_Insight(
          icon: Icons.info_outline,
          title: 'Calorie intake is quite low',
          body: 'You\'ve averaged ${avgCal.toStringAsFixed(0)} kcal/day — '
              'well below your ${calGoal.toStringAsFixed(0)} kcal target. '
              'Eating enough fuels your goals. Consider adding a nutritious snack.',
          positive: false,
        ));
      }
    }

    // Protein insights
    if (proGoal > 0) {
      final ratio = avgPro / proGoal;
      if (ratio < 0.75) {
        insights.add(_Insight(
          icon: Icons.restaurant_outlined,
          title: 'Protein a little low lately',
          body: 'Your 3-week protein average is ${avgPro.toStringAsFixed(0)}g/day '
              '(goal: ${proGoal.toStringAsFixed(0)}g). '
              'Foods like eggs, Greek yogurt, chicken, or salmon are easy wins.',
          positive: false,
        ));
      } else if (ratio >= 0.95) {
        insights.add(_Insight(
          icon: Icons.fitness_center_outlined,
          title: 'Great protein consistency',
          body: 'Averaging ${avgPro.toStringAsFixed(0)}g of protein per day — '
              'solid work supporting your muscle and satiety goals.',
          positive: true,
        ));
      }
    }

    // Sugar insights
    if (avgSug > 60) {
      insights.add(_Insight(
        icon: Icons.local_cafe_outlined,
        title: 'You might enjoy some lower-sugar swaps',
        body: 'Your average sugar intake has been '
            '${avgSug.toStringAsFixed(0)}g/day. '
            'Swapping sweetened drinks for water or fruit for dessert can help '
            'without feeling like a sacrifice.',
        positive: false,
      ));
    }

    // Fiber insights
    if (avgFib < 20 && avgFib > 0) {
      insights.add(_Insight(
        icon: Icons.eco_outlined,
        title: 'Room to boost your fibre',
        body: 'You\'ve averaged ${avgFib.toStringAsFixed(1)}g of fibre/day. '
            'Adding legumes, wholegrains, or an extra serving of veg each day '
            'supports digestion and keeps you fuller longer.',
        positive: false,
      ));
    }

    return insights;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final avgs = _avgs;
    if (avgs == null || (avgs['days'] ?? 0) < 3) {
      return Card(
        elevation: 0,
        color: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.insights_outlined, color: cs.onSurfaceVariant, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Log at least 3 days of meals to unlock nutrition insights.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final insights = _buildInsights(avgs);
    final days = avgs['days']!.toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nutrition Insights',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    'Based on your last 3 weeks ($days days with data)',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_outlined, size: 18),
              onPressed: _load,
              tooltip: 'Refresh',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Summary row
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AvgChip(label: 'Avg kcal', value: avgs['calories']!.toStringAsFixed(0), unit: 'kcal'),
                _AvgChip(label: 'Avg protein', value: avgs['protein']!.toStringAsFixed(0), unit: 'g'),
                _AvgChip(label: 'Avg sugar', value: avgs['sugar']!.toStringAsFixed(0), unit: 'g'),
                _AvgChip(label: 'Avg fibre', value: avgs['fiber']!.toStringAsFixed(0), unit: 'g'),
              ],
            ),
          ),
        ),
        if (insights.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final insight in insights) ...[
            _InsightCard(insight: insight),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

// ── Nutrition insight data model ──────────────────────────────────────────────

class _Insight {
  final IconData icon;
  final String title;
  final String body;
  final bool positive;

  const _Insight({
    required this.icon,
    required this.title,
    required this.body,
    required this.positive,
  });
}

// ── Single insight card ────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final _Insight insight;

  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bgColor = insight.positive ? cs.secondaryContainer : cs.surfaceContainerHighest;
    final iconColor = insight.positive ? cs.onSecondaryContainer : cs.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: insight.positive
              ? cs.secondary.withValues(alpha: 0.3)
              : cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(insight.icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: insight.positive
                          ? cs.onSecondaryContainer
                          : cs.onSurface,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 3),
                Text(insight.body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: insight.positive
                          ? cs.onSecondaryContainer.withValues(alpha: 0.8)
                          : cs.onSurfaceVariant,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Average value chip ────────────────────────────────────────────────────────

class _AvgChip extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _AvgChip({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant, fontSize: 9)),
        const SizedBox(height: 2),
        Text(value,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(unit,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant, fontSize: 9)),
      ],
    );
  }
}
