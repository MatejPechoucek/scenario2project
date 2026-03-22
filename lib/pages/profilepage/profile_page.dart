import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _showMacroComparisonDialog(BuildContext context) {
    const baselineGoals = {
      'Protein': 150.0,
      'Fat': 70.0,
      'Carbs': 250.0,
    };

    final recentIntake = <Map<String, double>>[
      {'Protein': 130.0, 'Fat': 65.0, 'Carbs': 230.0},
      {'Protein': 160.0, 'Fat': 90.0, 'Carbs': 270.0},
      {'Protein': 140.0, 'Fat': 55.0, 'Carbs': 210.0},
      {'Protein': 155.0, 'Fat': 75.0, 'Carbs': 260.0},
    ];

    double avg(String key) =>
        recentIntake.map((day) => day[key] ?? 0).reduce((a, b) => a + b) /
        recentIntake.length;

    final averageIntake = {
      for (final key in baselineGoals.keys) key: avg(key),
    };

    final deviations = {
      for (final key in baselineGoals.keys)
        key: (averageIntake[key]! - baselineGoals[key]!) / baselineGoals[key]!,
    };

    final suggestions = <String>[];
    final foodSuggestions = {
      'Protein': ['Grilled chicken', 'Greek yogurt', 'Lentils'],
      'Fat': ['Avocado', 'Walnuts', 'Olive oil'],
      'Carbs': ['Sweet potato', 'Quinoa', 'Oats'],
    };

    deviations.forEach((macro, ratio) {
      if (ratio.abs() >= 0.20) {
        final label = ratio > 0 ? 'above' : 'below';
        suggestions.add(
          '$macro is ${(ratio * 100).abs().toStringAsFixed(0)}% $label goal (target ${baselineGoals[macro]!.toStringAsFixed(0)}g, actual ${averageIntake[macro]!.toStringAsFixed(0)}g).',
        );
      }
    });

    final targetsToSuggest = deviations.entries
        .where((entry) => entry.value.abs() >= 0.20)
        .map((entry) => entry.key)
        .toList();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Macro Intake Comparison'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Last 4 days average vs baseline goals:'),
                const SizedBox(height: 8),
                DataTable(
                  columns: const [
                    DataColumn(label: Text('Macro')),
                    DataColumn(label: Text('Goal (g)')),
                    DataColumn(label: Text('Actual (g)')),
                    DataColumn(label: Text('Diff')),
                  ],
                  rows: baselineGoals.keys.map((macro) {
                    final actual = averageIntake[macro]!;
                    final goal = baselineGoals[macro]!;
                    final diffPct = deviations[macro]! * 100;
                    return DataRow(cells: [
                      DataCell(Text(macro)),
                      DataCell(Text(goal.toStringAsFixed(0))),
                      DataCell(Text(actual.toStringAsFixed(0))),
                      DataCell(Text('${diffPct.isNegative ? '' : '+'}${diffPct.toStringAsFixed(1)}%')),
                    ]);
                  }).toList(),
                ),
                const SizedBox(height: 12),
                if (targetsToSuggest.isEmpty)
                  const Text('Your intake is within 20% of goals for all macros. Great job!')
                else ...[
                  const Text('Recommendations for next time:'),
                  const SizedBox(height: 6),
                  ...targetsToSuggest.expand((macro) => [
                        Text('• $macro needs adjustment (±20% threshold).'),
                        const SizedBox(height: 2),
                        Text('  Try: ${foodSuggestions[macro]!.join(', ')}.'),
                        const SizedBox(height: 8),
                      ]),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 16),

            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.deepPurple,
                      child: Icon(Icons.person, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('John Doe',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              )),
                          SizedBox(height: 4),
                          Text('john.doe@example.com',
                              style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () {},
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ),
            ),

            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Performance', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('Summary of your recent calorie and nutrient targets.',
                        style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.only(right: 8.0, top: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Intake Distribution',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 220,
                            child: PieChart(
                              PieChartData(
                                centerSpaceColor: theme.colorScheme.primary,
                                sections: [
                                  PieChartSectionData(
                                    value: 40,
                                    color: Colors.red,
                                    title: 'Underate',
                                    radius: 50,
                                    titleStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    value: 30,
                                    color: Colors.green,
                                    title: 'Achieved',
                                    radius: 50,
                                    titleStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    value: 20,
                                    color: Colors.orange,
                                    title: 'Overate',
                                    radius: 50,
                                    titleStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                                sectionsSpace: 2,
                                centerSpaceRadius: 36,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.only(left: 8.0, top: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Weekly Intake',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 220,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget:
                                          (double value, TitleMeta meta) {
                                        const style = TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        );
                                        Widget text;
                                        switch (value.toInt()) {
                                          case 1:
                                            text = const Text('Mon', style: style);
                                            break;
                                          case 2:
                                            text = const Text('Tue', style: style);
                                            break;
                                          case 3:
                                            text = const Text('Wed', style: style);
                                            break;
                                          case 4:
                                            text = const Text('Thu', style: style);
                                            break;
                                          case 5:
                                            text = const Text('Fri', style: style);
                                            break;
                                          case 6:
                                            text = const Text('Sat', style: style);
                                            break;
                                          case 7:
                                            text = const Text('Sun', style: style);
                                            break;
                                          default:
                                            text = const Text('');
                                        }
                                        return SideTitleWidget(
                                          meta: meta,
                                          space: 4,
                                          child: text,
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                barGroups: [
                                  BarChartGroupData(x: 1, barRods: [
                                    BarChartRodData(
                                        toY: 2550, color: Colors.blueAccent)
                                  ], showingTooltipIndicators: [0]),
                                  BarChartGroupData(x: 2, barRods: [
                                    BarChartRodData(
                                        toY: 1500, color: Colors.greenAccent)
                                  ], showingTooltipIndicators: [0]),
                                  BarChartGroupData(x: 3, barRods: [
                                    BarChartRodData(
                                        toY: 2310, color: Colors.orangeAccent)
                                  ], showingTooltipIndicators: [0]),
                                  BarChartGroupData(x: 4, barRods: [
                                    BarChartRodData(
                                        toY: 2015,
                                        color: const Color.fromARGB(255, 255, 64, 64))
                                  ], showingTooltipIndicators: [0]),
                                  BarChartGroupData(x: 5, barRods: [
                                    BarChartRodData(
                                        toY: 2310,
                                        color: const Color.fromARGB(255, 255, 64, 210))
                                  ], showingTooltipIndicators: [0]),
                                  BarChartGroupData(x: 6, barRods: [
                                    BarChartRodData(
                                        toY: 2310,
                                        color: const Color.fromARGB(255, 223, 255, 64))
                                  ], showingTooltipIndicators: [0]),
                                  BarChartGroupData(x: 7, barRods: [
                                    BarChartRodData(
                                        toY: 2310,
                                        color: const Color.fromARGB(255, 64, 226, 255))
                                  ], showingTooltipIndicators: [0]),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.surfaceVariant,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'If you keep it up, you\'ll hit your weight goal in roughly ... days!',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.trending_up, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  child: const Text('Settings'),
                ),
                const SizedBox(width: 10),
                FilledButton.tonal(
                  onPressed: () {},
                  child: const Text('Toggle Tracking'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () => _showMacroComparisonDialog(context),
                  child: const Text('Macro Analysis'),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
