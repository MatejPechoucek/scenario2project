import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../database/app_user.dart';
import '../../database/db_helper.dart';
import '../../database/food_log_entry.dart';
import '../foodsearch/food_search_page.dart';

/// The main daily food tracker page.
///
/// Shows today's food log grouped by meal slot, a calorie donut chart,
/// and macro ring charts. The floating action button opens the food search
/// page so the user can log what they ate.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late String _viewDate;
  late DateTime _viewDay;

  AppUser? _user;
  List<FoodLogEntry> _log = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _viewDay = DateTime.now();
    _viewDate = _toDateString(_viewDay);
    _load();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      DbHelper.getUser(),
      DbHelper.getFoodLogForDate(_viewDate),
    ]);
    if (mounted) {
      setState(() {
        _user = results[0] as AppUser;
        _log = results[1] as List<FoodLogEntry>;
        _loading = false;
      });
    }
  }

  Future<void> _deleteEntry(int id) async {
    await DbHelper.deleteFoodLogEntry(id);
    _load();
  }

  // ── Date navigation ────────────────────────────────────────────────────────

  void _goToDay(int delta) {
    _viewDay = _viewDay.add(Duration(days: delta));
    _viewDate = _toDateString(_viewDay);
    _load();
  }

  static String _toDateString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _isToday {
    final today = DateTime.now();
    return _viewDay.year == today.year &&
        _viewDay.month == today.month &&
        _viewDay.day == today.day;
  }

  // ── Navigation to food search ──────────────────────────────────────────────

  Future<void> _openSearch({String mealSlot = 'any'}) async {
    final logged = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FoodSearchPage(initialMealSlot: mealSlot),
      ),
    );
    if (logged == true) _load();
  }

  // ── Derived totals ─────────────────────────────────────────────────────────

  double get _totalCalories => _log.fold(0.0, (s, e) => s + e.calories);
  double get _totalProtein  => _log.fold(0.0, (s, e) => s + e.proteinG);
  double get _totalFat      => _log.fold(0.0, (s, e) => s + e.fatG);
  double get _totalCarbs    => _log.fold(0.0, (s, e) => s + e.carbsG);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _user;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildDateHeader(theme)),

                  if (user != null) ...[
                    // Calorie donut + macro rings in one row
                    SliverToBoxAdapter(
                      child: _buildSummaryRow(theme, user),
                    ),
                  ],

                  for (final slot in _kSlots)
                    ..._buildMealSection(theme, slot),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSearch(),
        icon: const Icon(Icons.add),
        label: const Text('Add Food'),
      ),
    );
  }

  // ── Date navigation header ─────────────────────────────────────────────────

  Widget _buildDateHeader(ThemeData theme) {
    final label = _isToday
        ? 'Today'
        : '${_kMonths[_viewDay.month - 1]} ${_viewDay.day}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _goToDay(-1),
          ),
          Column(
            children: [
              Text(label,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              if (!_isToday)
                Text(
                  '${_viewDay.day} ${_kMonths[_viewDay.month - 1]} ${_viewDay.year}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _isToday ? null : () => _goToDay(1),
          ),
        ],
      ),
    );
  }

  // ── Summary row: calorie donut (left) + 3 macro rings (right) ─────────────

  Widget _buildSummaryRow(ThemeData theme, AppUser user) {
    final consumed = _totalCalories;
    final goal = user.dailyCalorieGoal.toDouble();
    final remaining = (goal - consumed).clamp(0.0, double.infinity);
    final overGoal = consumed > goal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ── Calorie donut ──────────────────────────────────────────────
              _CalorieDonut(
                consumed: consumed,
                goal: goal,
                remaining: remaining,
                overGoal: overGoal,
                theme: theme,
              ),

              const SizedBox(width: 16),

              // ── Three macro rings ──────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Macros',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MacroRing(
                          label: 'Protein',
                          consumed: _totalProtein,
                          goal: user.proteinGGoal,
                          color: Colors.blue.shade500,
                        ),
                        _MacroRing(
                          label: 'Fat',
                          consumed: _totalFat,
                          goal: user.fatGGoal,
                          color: Colors.orange.shade500,
                        ),
                        _MacroRing(
                          label: 'Carbs',
                          consumed: _totalCarbs,
                          goal: user.carbsGGoal,
                          color: Colors.green.shade500,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Meal section builder ───────────────────────────────────────────────────

  static const _kSlots = ['breakfast', 'lunch', 'dinner', 'snack'];
  static const _kSlotLabels = {
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snack',
  };
  static const _kSlotIcons = {
    'breakfast': Icons.wb_sunny_outlined,
    'lunch': Icons.lunch_dining_outlined,
    'dinner': Icons.dinner_dining_outlined,
    'snack': Icons.local_cafe_outlined,
  };

  List<Widget> _buildMealSection(ThemeData theme, String slot) {
    final entries = _log.where((e) => e.mealSlot == slot).toList();
    final slotCalories = entries.fold(0.0, (s, e) => s + e.calories);

    return [
      SliverToBoxAdapter(
        child: _MealSectionHeader(
          label: _kSlotLabels[slot]!,
          icon: _kSlotIcons[slot]!,
          calories: slotCalories,
          onAdd: () => _openSearch(mealSlot: slot),
        ),
      ),
      if (entries.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(left: 56, bottom: 4),
            child: Text('Nothing logged yet',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
        )
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _FoodLogTile(
              entry: entries[i],
              onDelete: () => _deleteEntry(entries[i].id!),
            ),
            childCount: entries.length,
          ),
        ),
    ];
  }

  static const _kMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

// ── Calorie donut chart ────────────────────────────────────────────────────────

class _CalorieDonut extends StatelessWidget {
  final double consumed;
  final double goal;
  final double remaining;
  final bool overGoal;
  final ThemeData theme;

  const _CalorieDonut({
    required this.consumed,
    required this.goal,
    required this.remaining,
    required this.overGoal,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final consumedPct = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    final remainingPct = (1.0 - consumedPct).clamp(0.001, 1.0);

    final activeColor = overGoal ? cs.tertiary : cs.primary;
    final bgColor = cs.onPrimaryContainer.withValues(alpha: 0.12);

    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: consumedPct.clamp(0.001, 1.0),
                      color: activeColor,
                      title: '',
                      radius: 18,
                      borderSide: BorderSide.none,
                    ),
                    PieChartSectionData(
                      value: remainingPct,
                      color: bgColor,
                      title: '',
                      radius: 18,
                      borderSide: BorderSide.none,
                    ),
                  ],
                  centerSpaceRadius: 42,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    consumed.toStringAsFixed(0),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    'kcal',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Remaining / Over label below the ring
        Text(
          overGoal
              ? '+${(consumed - goal).toStringAsFixed(0)} over'
              : '${remaining.toStringAsFixed(0)} left',
          style: theme.textTheme.labelSmall?.copyWith(
            color: overGoal
                ? theme.colorScheme.tertiary
                : theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'of ${goal.toStringAsFixed(0)} kcal',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ── Macro donut ring ───────────────────────────────────────────────────────────

class _MacroRing extends StatelessWidget {
  final String label;
  final double consumed;
  final double goal;
  final Color color;

  const _MacroRing({
    required this.label,
    required this.consumed,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    final remaining = (1.0 - progress).clamp(0.001, 1.0);
    final over = consumed > goal;

    return Column(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: progress.clamp(0.001, 1.0),
                      color: over ? theme.colorScheme.tertiary : color,
                      title: '',
                      radius: 10,
                      borderSide: BorderSide.none,
                    ),
                    PieChartSectionData(
                      value: remaining,
                      color: color.withValues(alpha: 0.15),
                      title: '',
                      radius: 10,
                      borderSide: BorderSide.none,
                    ),
                  ],
                  centerSpaceRadius: 22,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                ),
              ),
              Text(
                '${consumed.toStringAsFixed(0)}g',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onPrimaryContainer,
            )),
        Text('of ${goal.toStringAsFixed(0)}g',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
            )),
      ],
    );
  }
}

// ── Meal section header ────────────────────────────────────────────────────────

class _MealSectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final double calories;
  final VoidCallback onAdd;

  const _MealSectionHeader({
    required this.label,
    required this.icon,
    required this.calories,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(label,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          if (calories > 0)
            Text(
              '${calories.toStringAsFixed(0)} kcal',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const Spacer(),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Food log entry tile ────────────────────────────────────────────────────────

class _FoodLogTile extends StatelessWidget {
  final FoodLogEntry entry;
  final VoidCallback onDelete;

  const _FoodLogTile({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete_outline,
            color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            const SizedBox(width: 28),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.foodName,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    '${entry.servingG.toStringAsFixed(0)}g  ·  '
                    'P ${entry.proteinG.toStringAsFixed(1)}  '
                    'F ${entry.fatG.toStringAsFixed(1)}  '
                    'C ${entry.carbsG.toStringAsFixed(1)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
      ),
    );
  }
}
