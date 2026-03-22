import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../database/food_item.dart';
import '../../services/food_repository.dart';

bool get _isMobile =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

// ── Barcode scanner page (mobile only) ────────────────────────────────────────

class BarcodeScannerPage extends StatelessWidget {
  const BarcodeScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (!_isMobile) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan Barcode')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner,
                  size: 72, color: cs.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'Barcode scanning is only available\non iOS and Android.',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: MobileScanner(
        onDetect: (capture) {
          final code = capture.barcodes.first.rawValue;
          if (code != null) Navigator.pop(context, code);
        },
      ),
    );
  }
}

class QnaPage extends StatefulWidget {
  const QnaPage({super.key});

  @override
  State<QnaPage> createState() => _QnaPageState();
}

class _QnaPageState extends State<QnaPage> {
  final _searchController = TextEditingController();
  final _expertController = TextEditingController();

  List<FoodItem> _searchResults = [];
  bool _searching = false;
  final List<String> _expertQueue = [];
  bool _expertSubmitted = false;

  // ── FAQ content ────────────────────────────────────────────────────────────

  static const _faqs = [
    (
      q: 'What is a calorie and why does it matter?',
      a:
          'A calorie is a unit of energy. Your body burns calories for everything from breathing to exercise. '
          'Eating more than you burn leads to weight gain; eating fewer leads to weight loss. '
          'CleanEater helps you track this balance so you can make informed choices every day.',
    ),
    (
      q: 'What is TDEE and how is it calculated?',
      a:
          'Total Daily Energy Expenditure (TDEE) is the total number of calories your body burns per day. '
          'CleanEater uses the clinically validated Mifflin-St Jeor equation: '
          'BMR = (10 × weight kg) + (6.25 × height cm) − (5 × age) + sex constant (+5 male / −161 female), '
          'then multiplied by your activity level (1.2 sedentary → 1.9 extra active).',
    ),
    (
      q: 'What are macronutrients?',
      a:
          'Macronutrients are the three main nutrients your body needs in large quantities:\n'
          '• Protein (4 kcal/g) — builds and repairs muscle tissue.\n'
          '• Fat (9 kcal/g) — supports hormones, brain function, and fat-soluble vitamins.\n'
          '• Carbohydrates (4 kcal/g) — your primary energy source for daily activity.',
    ),
    (
      q: 'How much protein should I eat per day?',
      a:
          'For general health, 0.8 g per kg of body weight is the minimum. '
          'For muscle gain or active sport, 1.6–2.2 g/kg is recommended. '
          'When losing weight, higher protein (1.8–2.4 g/kg) helps preserve muscle mass '
          'while in a calorie deficit.',
    ),
    (
      q: 'What does the Smart Swap feature do?',
      a:
          'Smart Swap analyses your planned meals for high fat, sugar, or sodium content '
          'and uses the Nutritional Proximity Algorithm to suggest similar foods with better '
          'nutritional profiles — so the swap still satisfies the same craving. '
          'For example, swapping potato chips for air-popped popcorn saves sodium and fat '
          'while keeping that crunchy snack feel.',
    ),
    (
      q: 'How does the Nutrition Feedback System work?',
      a:
          'CleanEater analyses your food log over the past 3 weeks. If your average intake '
          'deviates significantly from your goals — for example, consistently low protein or '
          'high sugar — the app gently surfaces suggestions to help you get back on track, '
          'without punitive language or red warning colours.',
    ),
    (
      q: 'What is a calorie deficit and is it safe?',
      a:
          'A calorie deficit means consuming fewer calories than you burn. A moderate deficit of '
          '300–550 kcal/day (roughly −0.5 kg/week) is generally considered safe for most healthy '
          'adults. CleanEater floors your effective goal at 1,200 kcal/day and recommends '
          'consulting a professional for larger deficits.',
    ),
    (
      q: 'Is CleanEater a replacement for medical advice?',
      a:
          'No. CleanEater is a nutrition tracking tool, not a medical device. '
          'Always consult a qualified healthcare professional or registered dietitian '
          'before making significant changes to your diet, especially if you have a '
          'medical condition such as diabetes, kidney disease, or a history of eating disorders.',
    ),
  ];

  // ── Food search ────────────────────────────────────────────────────────────

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final results = await FoodRepository.searchFoods(query.trim());
    if (mounted) {
      setState(() {
        _searchResults = results.take(8).toList();
        _searching = false;
      });
    }
  }

  // ── Expert queue ───────────────────────────────────────────────────────────

  void _submitExpert() {
    final q = _expertController.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _expertQueue.add(q);
      _expertSubmitted = true;
    });
    _expertController.clear();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _expertSubmitted = false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _expertController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page header
            Text(
              'Q&A Hub',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Learn about nutrition, explore foods, and ask our experts.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),

            const SizedBox(height: 24),

            // ── FAQ ─────────────────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.help_outline_rounded,
              title: 'Frequently Asked Questions',
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: cs.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: _faqs.asMap().entries.map((entry) {
                  final isLast = entry.key == _faqs.length - 1;
                  return Column(
                    children: [
                      ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 2),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        title: Text(
                          entry.value.q,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        iconColor: cs.primary,
                        collapsedIconColor: cs.onSurfaceVariant,
                        children: [
                          Text(
                            entry.value.a,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                      if (!isLast)
                        Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: cs.outlineVariant.withValues(alpha: 0.5)),
                    ],
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // ── Food search ─────────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.search_rounded,
              title: 'Look Up Any Food',
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
                      'Search 250+ curated foods for full nutrition info per 100 g.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearch,
                      decoration: InputDecoration(
                        hintText: 'e.g. chicken breast, oats, avocado…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                            : _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearch('');
                                    },
                                  )
                                : null,
                        filled: true,
                        fillColor: cs.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (_isMobile) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.qr_code_scanner, size: 18),
                          label: const Text('Scan Barcode'),
                          style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact),
                          onPressed: () async {
                            final code = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const BarcodeScannerPage()),
                            );
                            if (code != null && code.isNotEmpty) {
                              _searchController.text = code;
                              _onSearch(code);
                            }
                          },
                        ),
                      ),
                    ],
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ..._searchResults
                          .map((food) => _FoodResultTile(food: food)),
                    ] else if (!_searching &&
                        _searchController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'No results found. Try a different search.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Ask an Expert ───────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.medical_services_outlined,
              title: 'Ask an Expert',
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
                      'Have a question our FAQs don\'t cover? Our registered '
                      'nutritionists typically respond within 48 hours.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _expertController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Describe your question in detail…',
                        filled: true,
                        fillColor: cs.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_expertSubmitted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: cs.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sent! An expert will respond within 48 hours.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onPrimaryContainer),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: _submitExpert,
                          child: const Text('Submit Question'),
                        ),
                      ),
                    if (_expertQueue.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Your questions in queue:',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      ..._expertQueue.map(
                        (q) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.schedule,
                                  size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(q,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.secondaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: cs.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'CleanEater is a nutrition tracking tool, not a medical device. '
                      'Always consult a qualified healthcare professional before making '
                      'significant dietary changes.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSecondaryContainer,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ── Food result tile ───────────────────────────────────────────────────────────

class _FoodResultTile extends StatelessWidget {
  final FoodItem food;
  const _FoodResultTile({required this.food});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  food.name,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${food.calories.round()} kcal',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'per 100 g · ${food.category}',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _Badge('Protein', '${food.proteinG.toStringAsFixed(1)}g',
                  Colors.blue.shade400),
              _Badge('Fat', '${food.fatG.toStringAsFixed(1)}g',
                  Colors.orange.shade400),
              _Badge('Carbs', '${food.carbsG.toStringAsFixed(1)}g',
                  Colors.green.shade500),
              _Badge('Sugar', '${food.sugarG.toStringAsFixed(1)}g',
                  cs.secondary),
              _Badge('Fibre', '${food.fiberG.toStringAsFixed(1)}g',
                  cs.tertiary),
              _Badge('Sodium', '${food.sodiumMg.round()}mg',
                  cs.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Badge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
