import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../database/app_user.dart';
import '../../database/db_helper.dart';
import '../../database/food_log_entry.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AppUser? _user;
  List<FoodLogEntry> _recentLog = []; // up to 6 weeks
  Map<String, double> _rollingAvg = {};
  int _streak = 0;
  bool _loading = true;
  int _chartWeeks = 1;

  static const _kShortDays = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final today = DateTime.now();
    final startStr = _dateStr(today.subtract(const Duration(days: 42)));
    final endStr = _dateStr(today);

    final results = await Future.wait([
      DbHelper.getUser(),
      DbHelper.getFoodLogForDateRange(startStr, endStr),
      DbHelper.getRollingAverages(21),
    ]);

    if (mounted) {
      final user = results[0] as AppUser;
      final log = results[1] as List<FoodLogEntry>;
      final avg = results[2] as Map<String, double>;
      setState(() {
        _user = user;
        _recentLog = log;
        _rollingAvg = avg;
        _streak = _computeStreak(log, user);
        _loading = false;
      });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int _computeStreak(List<FoodLogEntry> log, AppUser user) {
    final byDate = <String, double>{};
    for (final e in log) {
      byDate[e.loggedDate] = (byDate[e.loggedDate] ?? 0) + e.calories;
    }
    final goal = user.dailyCalorieGoal.toDouble();
    if (goal <= 0) return 0;

    var streak = 0;
    final today = DateTime.now();
    for (var i = 0; i < 42; i++) {
      final day = today.subtract(Duration(days: i));
      final kcal = byDate[_dateStr(day)] ?? 0.0;
      // A "good" day: logged at least 500 kcal and didn't exceed goal by more than 15%
      if (kcal >= 500 && kcal <= goal * 1.15) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  Map<String, int> get _weeklyStats {
    final byDate = <String, double>{};
    for (final e in _recentLog) {
      byDate[e.loggedDate] = (byDate[e.loggedDate] ?? 0) + e.calories;
    }
    final goal = _user?.dailyCalorieGoal.toDouble() ?? 0;
    var daysHit = 0;
    var daysLogged = 0;
    final today = DateTime.now();
    for (var i = 0; i < 7; i++) {
      final day = today.subtract(Duration(days: i));
      final kcal = byDate[_dateStr(day)] ?? 0.0;
      if (kcal > 0) {
        daysLogged++;
        if (kcal <= goal * 1.10) daysHit++;
      }
    }
    return {'hit': daysHit, 'logged': daysLogged};
  }

  List<(String, double)> _chartDays() {
    final days = _chartWeeks * 7;
    final today = DateTime.now();
    final byDate = <String, double>{};
    for (final e in _recentLog) {
      byDate[e.loggedDate] = (byDate[e.loggedDate] ?? 0) + e.calories;
    }
    return List.generate(days, (i) {
      final day = today.subtract(Duration(days: days - 1 - i));
      final label = _chartWeeks == 1
          ? _kShortDays[day.weekday % 7]
          : '${day.day}';
      return (label, byDate[_dateStr(day)] ?? 0.0);
    });
  }

  List<String> _buildFeedback(AppUser user) {
    final days = _rollingAvg['days'] ?? 0;
    if (days < 2) return [];

    final messages = <String>[];
    final avgCal = _rollingAvg['calories'] ?? 0;
    final avgProtein = _rollingAvg['protein'] ?? 0;
    final avgSugar = _rollingAvg['sugar'] ?? 0;
    final avgFiber = _rollingAvg['fiber'] ?? 0;
    final goal = user.dailyCalorieGoal.toDouble();
    final proteinGoal = user.proteinGGoal;

    if (goal > 0 && avgCal > 0) {
      final pct = avgCal / goal;
      if (pct > 1.12) {
        messages.add(
          'Your 3-week average (${avgCal.round()} kcal/day) is '
          '${((pct - 1) * 100).round()}% above your goal. '
          'Try our Smart Swap feature to find lower-calorie alternatives you\'ll enjoy.',
        );
      } else if (pct < 0.78) {
        messages.add(
          'You\'re averaging ${avgCal.round()} kcal/day — well under your goal of '
          '${goal.round()} kcal. Make sure you\'re fuelling your body properly '
          'to avoid fatigue and muscle loss.',
        );
      } else {
        messages.add(
          'Great work — you\'re consistently near your calorie goal '
          '(${avgCal.round()} kcal avg vs ${goal.round()} kcal target)!',
        );
      }
    }

    if (proteinGoal > 0 && avgProtein > 0) {
      final pct = avgProtein / proteinGoal;
      if (pct < 0.75) {
        messages.add(
          'Your protein intake (${avgProtein.round()} g avg) is below your '
          '${proteinGoal.round()} g goal. Try adding grilled chicken, Greek yogurt, '
          'lentils, or eggs to your meals.',
        );
      } else if (pct >= 0.90) {
        messages.add(
          'Your protein intake is on track (${avgProtein.round()} g avg). '
          'This supports muscle health and helps keep you feeling full.',
        );
      }
    }

    if (avgSugar > 55) {
      messages.add(
        'Your average sugar intake (${avgSugar.round()} g) is on the higher side. '
        'You might enjoy fresh fruit, Greek yogurt with berries, or dark chocolate '
        '(70%+) as lower-sugar sweet alternatives.',
      );
    }

    if (avgFiber > 0 && avgFiber < 18) {
      messages.add(
        'Your fibre intake could be higher (${avgFiber.round()} g avg vs the '
        '25–30 g recommended daily). Try adding oats, legumes, vegetables, or '
        'wholegrain bread to your meals.',
      );
    }

    return messages;
  }

  // ── Edit profile sheet ─────────────────────────────────────────────────────

  Future<void> _showEditSheet() async {
    if (_user == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      // Controllers live inside _EditGoalsSheet so they are disposed
      // with the sheet's own State — not after the closing animation.
      builder: (_) => _EditGoalsSheet(user: _user!),
    );
    // Reload regardless of whether Save was pressed or sheet was dismissed.
    await _load();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = _user!;
    final feedback = _buildFeedback(user);
    final stats = _weeklyStats;
    final chartDays = _chartDays();

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── User card ──────────────────────────────────────────────────
            Card(
              elevation: 0,
              color: cs.primaryContainer,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: cs.primary,
                      child: Text(
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            '${user.dailyCalorieGoal} kcal/day goal',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onPrimaryContainer
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: _showEditSheet,
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Stats row ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Day Streak',
                    value: '$_streak',
                    sub: _streak == 1 ? 'day' : 'days',
                    color: cs.primary,
                    background: cs.primaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Goals Hit',
                    value: '${stats['hit']}/${stats['logged']}',
                    sub: 'this week',
                    color: cs.secondary,
                    background: cs.secondaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.bar_chart_rounded,
                    label: '3-Wk Avg',
                    value: (_rollingAvg['calories'] ?? 0) > 0
                        ? '${(_rollingAvg['calories']!).round()}'
                        : '—',
                    sub: 'kcal/day',
                    color: cs.tertiary,
                    background: cs.tertiaryContainer,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Calorie history chart ──────────────────────────────────────
            _buildChartCard(theme, cs, chartDays, user),

            const SizedBox(height: 16),

            // ── Nutrition Feedback ─────────────────────────────────────────
            if (feedback.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.insights_rounded, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Nutrition Insights',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Based on your last 3 weeks of logging:',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                      ...feedback.map(
                        (msg) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 5),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  msg,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Goal prediction ────────────────────────────────────────────
            if (user.weeklyLossKg > 0) ...[
              _buildPredictionCard(theme, cs, user),
              const SizedBox(height: 16),
            ],

            // ── Daily goals summary ────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.pie_chart_outline_rounded,
                    size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Daily Goals',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: cs.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _GoalRow(
                      label: 'Calories',
                      value: '${user.dailyCalorieGoal} kcal',
                      icon: Icons.bolt_rounded,
                      color: cs.primary,
                    ),
                    const Divider(height: 20),
                    _GoalRow(
                      label: 'Protein',
                      value: '${user.proteinGGoal.round()} g',
                      icon: Icons.fitness_center_rounded,
                      color: Colors.blue.shade500,
                    ),
                    const SizedBox(height: 10),
                    _GoalRow(
                      label: 'Fat',
                      value: '${user.fatGGoal.round()} g',
                      icon: Icons.water_drop_outlined,
                      color: Colors.orange.shade500,
                    ),
                    const SizedBox(height: 10),
                    _GoalRow(
                      label: 'Carbohydrates',
                      value: '${user.carbsGGoal.round()} g',
                      icon: Icons.grain_rounded,
                      color: Colors.green.shade500,
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _showEditSheet,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit goals'),
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chart card ─────────────────────────────────────────────────────────────

  Widget _buildChartCard(
    ThemeData theme,
    ColorScheme cs,
    List<(String, double)> days,
    AppUser user,
  ) {
    final goalKcal = user.dailyCalorieGoal.toDouble();
    final maxY =
        days.map((d) => d.$2).fold(goalKcal, (a, b) => a > b ? a : b);
    final chartMax = (maxY * 1.2).clamp(500.0, double.infinity);
    final todayIndex = days.length - 1;
    final labelEvery =
        _chartWeeks <= 2 ? 1 : _chartWeeks <= 4 ? 2 : 3;
    final barWidth = _chartWeeks == 1
        ? 26.0
        : _chartWeeks <= 2
            ? 13.0
            : 7.0;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 16, 10),
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
                        'Calorie History',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _chartWeeks == 1
                            ? 'Last 7 days'
                            : 'Last $_chartWeeks weeks',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                // Week selector
                Row(
                  children: [1, 2, 4, 6].map((w) {
                    final selected = _chartWeeks == w;
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _chartWeeks = w),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                selected ? cs.primary : cs.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            w == 1 ? '1W' : '${w}W',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? cs.onPrimary
                                  : cs.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: chartMax,
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                        '${rod.toY.round()} kcal',
                        TextStyle(
                          color: cs.onPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= days.length) {
                            return const SizedBox();
                          }
                          if (idx % labelEvery != 0 &&
                              idx != todayIndex) {
                            return const SizedBox();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            space: 4,
                            child: Text(
                              days[idx].$1,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: idx == todayIndex
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: idx == todayIndex
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(days.length, (i) {
                    final kcal = days[i].$2;
                    final isToday = i == todayIndex;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: kcal > 0 ? kcal : 40,
                          color: kcal > 0
                              ? (isToday
                                  ? cs.primary
                                  : cs.primary.withValues(alpha: 0.45))
                              : cs.outlineVariant,
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
            if (goalKcal > 0) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 2,
                      color: cs.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${goalKcal.round()} kcal goal',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Prediction card ────────────────────────────────────────────────────────

  Widget _buildPredictionCard(
      ThemeData theme, ColorScheme cs, AppUser user) {
    final weeklyLoss = user.weeklyLossKg;
    final monthlyLoss = weeklyLoss * 4.3;
    final daysToFiveKg =
        weeklyLoss > 0 ? (5.0 / weeklyLoss * 7).round() : null;

    return Card(
      elevation: 0,
      color: cs.secondaryContainer,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.trending_down_rounded,
                size: 32, color: cs.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Goal Prediction',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'At your −${user.dailyDeficit} kcal/day deficit, '
                    'you\'re on pace to lose ~${monthlyLoss.toStringAsFixed(1)} kg per month.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSecondaryContainer,
                      height: 1.5,
                    ),
                  ),
                  if (daysToFiveKg != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'At this rate, you could reach a 5 kg loss in about $daysToFiveKg days.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            cs.onSecondaryContainer.withValues(alpha: 0.75),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit goals sheet (StatefulWidget so controllers own their lifecycle) ─────────

class _EditGoalsSheet extends StatefulWidget {
  final AppUser user;
  const _EditGoalsSheet({required this.user});

  @override
  State<_EditGoalsSheet> createState() => _EditGoalsSheetState();
}

class _EditGoalsSheetState extends State<_EditGoalsSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _kcalCtrl;
  late final TextEditingController _protCtrl;
  late final TextEditingController _fatCtrl;
  late final TextEditingController _carbsCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _kcalCtrl = TextEditingController(
        text: widget.user.dailyCalorieGoal.toString());
    _protCtrl = TextEditingController(
        text: widget.user.proteinGGoal.round().toString());
    _fatCtrl =
        TextEditingController(text: widget.user.fatGGoal.round().toString());
    _carbsCtrl = TextEditingController(
        text: widget.user.carbsGGoal.round().toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _kcalCtrl.dispose();
    _protCtrl.dispose();
    _fatCtrl.dispose();
    _carbsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Edit Profile & Goals',
            style:
                theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _kcalCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Daily Calorie Goal',
              border: OutlineInputBorder(),
              suffixText: 'kcal',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _protCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Protein',
                    border: OutlineInputBorder(),
                    suffixText: 'g',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _fatCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Fat',
                    border: OutlineInputBorder(),
                    suffixText: 'g',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _carbsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Carbs',
                    border: OutlineInputBorder(),
                    suffixText: 'g',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final updated = widget.user.copyWith(
                  name: _nameCtrl.text.trim().isNotEmpty
                      ? _nameCtrl.text.trim()
                      : widget.user.name,
                  dailyCalorieGoal:
                      int.tryParse(_kcalCtrl.text) ??
                          widget.user.dailyCalorieGoal,
                  proteinGGoal:
                      double.tryParse(_protCtrl.text) ??
                          widget.user.proteinGGoal,
                  fatGGoal: double.tryParse(_fatCtrl.text) ??
                      widget.user.fatGGoal,
                  carbsGGoal:
                      double.tryParse(_carbsCtrl.text) ??
                          widget.user.carbsGGoal,
                );
                await DbHelper.updateUser(updated);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final Color background;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: background,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              sub,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Goal row ───────────────────────────────────────────────────────────────────

class _GoalRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _GoalRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          value,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
