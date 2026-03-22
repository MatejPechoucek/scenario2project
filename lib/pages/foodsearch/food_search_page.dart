import 'package:flutter/material.dart';

import '../../database/db_helper.dart';
import '../../database/food_item.dart';
import '../../database/food_log_entry.dart';
import '../../services/food_repository.dart';

/// Full-screen food search page.
///
/// Shown when the user taps "Add Food" on the Home page.
/// Lets the user search the food bank, pick a serving size and meal slot,
/// then log the food to the food_log table.
///
/// On success, pops with `true` so the caller can refresh its state.
class FoodSearchPage extends StatefulWidget {
  /// Pre-select a meal slot when opened from a specific meal section.
  final String initialMealSlot;

  const FoodSearchPage({super.key, this.initialMealSlot = 'any'});

  @override
  State<FoodSearchPage> createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage> {
  final _searchCtrl = TextEditingController();
  List<FoodItem> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final results = await FoodRepository.searchFoods(query.trim());
    if (mounted) setState(() { _results = results; _searching = false; });
  }

  Future<void> _showLogDialog(FoodItem item) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LogFoodSheet(
        item: item,
        initialMealSlot: widget.initialMealSlot,
        onLogged: () => Navigator.of(context).pop(true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search foods…',
            border: InputBorder.none,
            hintStyle: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
          style: theme.textTheme.bodyLarge,
          onChanged: _search,
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _results = []);
              },
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchCtrl.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text('Type to search foods', style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text('No results found', style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        )),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final item = _results[i];
        return ListTile(
          title: Text(item.name, style: theme.textTheme.bodyMedium),
          subtitle: Text(item.category, style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.calories.toStringAsFixed(0)} kcal',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('per 100g', style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
            ],
          ),
          onTap: () => _showLogDialog(item),
        );
      },
    );
  }
}

// ── Log food bottom sheet ──────────────────────────────────────────────────────

class _LogFoodSheet extends StatefulWidget {
  final FoodItem item;
  final String initialMealSlot;
  final VoidCallback onLogged;

  const _LogFoodSheet({
    required this.item,
    required this.initialMealSlot,
    required this.onLogged,
  });

  @override
  State<_LogFoodSheet> createState() => _LogFoodSheetState();
}

class _LogFoodSheetState extends State<_LogFoodSheet> {
  final _servingCtrl = TextEditingController(text: '100');
  late String _mealSlot;
  bool _logging = false;

  static const _slots = ['breakfast', 'lunch', 'dinner', 'snack'];
  static const _slotLabels = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  void initState() {
    super.initState();
    _mealSlot = _slots.contains(widget.initialMealSlot)
        ? widget.initialMealSlot
        : 'any';
    if (_mealSlot == 'any') _mealSlot = 'breakfast';
  }

  @override
  void dispose() {
    _servingCtrl.dispose();
    super.dispose();
  }

  double get _serving => double.tryParse(_servingCtrl.text) ?? 100.0;
  double get _factor => _serving / 100.0;

  Future<void> _log() async {
    final serving = _serving;
    if (serving <= 0) return;
    setState(() => _logging = true);
    final entry = FoodLogEntry.fromFoodItem(widget.item, serving, _mealSlot);
    await DbHelper.logFood(entry);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onLogged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final f = _factor;

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(item.category,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Serving size input ─────────────────────────────────────────────
          Text('Serving size (g)', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _servingCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              suffixText: 'g',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // ── Meal slot selector ─────────────────────────────────────────────
          Text('Meal', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: List.generate(
              _slots.length,
              (i) => ButtonSegment(value: _slots[i], label: Text(_slotLabels[i])),
            ),
            selected: {_mealSlot},
            onSelectionChanged: (s) => setState(() => _mealSlot = s.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 16),

          // ── Nutrient preview ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NutrientBadge(
                  label: 'Calories',
                  value: '${(item.calories * f).toStringAsFixed(0)} kcal',
                  color: theme.colorScheme.primary,
                ),
                _NutrientBadge(
                  label: 'Protein',
                  value: '${(item.proteinG * f).toStringAsFixed(1)}g',
                  color: Colors.blue.shade700,
                ),
                _NutrientBadge(
                  label: 'Fat',
                  value: '${(item.fatG * f).toStringAsFixed(1)}g',
                  color: Colors.orange.shade700,
                ),
                _NutrientBadge(
                  label: 'Carbs',
                  value: '${(item.carbsG * f).toStringAsFixed(1)}g',
                  color: Colors.green.shade700,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Log button ─────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _logging ? null : _log,
              icon: _logging
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add),
              label: const Text('Log Food'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutrientBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _NutrientBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: color, fontWeight: FontWeight.bold)),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
      ],
    );
  }
}
