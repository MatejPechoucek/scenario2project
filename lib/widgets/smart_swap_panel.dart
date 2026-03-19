import 'package:flutter/material.dart';

import '../algorithm/nutritional_proximity.dart';
import '../database/food_item.dart';

/// A collapsible panel that appears on a meal card when the meal's
/// nutritional profile is flagged as potentially improvable.
///
/// When collapsed (default): shows a subtle "Healthier option available" chip.
/// When expanded: shows up to 3 [SwapSuggestionCard] tiles from the algorithm.
///
/// Design principles (from CleanEater spec ethical analysis):
///   • Non-judgmental language — "You might also enjoy..." not "BAD FOOD".
///   • Neutral colours — no danger red; uses the app's purple seed palette.
///   • Optional — the panel can be dismissed without penalty.
///   • Only suggests foods from compatible categories and the correct meal slot.
class SmartSwapPanel extends StatefulWidget {
  /// The food item to find alternatives for.
  final FoodItem food;

  /// The pool of candidate foods (typically FoodRepository.getAllBaseFoods()).
  final List<FoodItem> foodBank;

  /// The meal slot context: 'breakfast', 'lunch', 'dinner', or 'snack'.
  /// Filters suggestions to only foods appropriate for this time of day.
  final String mealSlot;

  const SmartSwapPanel({
    super.key,
    required this.food,
    required this.foodBank,
    this.mealSlot = 'any',
  });

  @override
  State<SmartSwapPanel> createState() => _SmartSwapPanelState();
}

class _SmartSwapPanelState extends State<SmartSwapPanel> {
  bool _expanded = false;
  late final List<SwapSuggestion> _suggestions;

  @override
  void initState() {
    super.initState();
    // Run algorithm once on init — it's synchronous and fast (<5ms for 250 foods).
    _suggestions = NutritionalProximityAlgorithm.findAlternatives(
      widget.food,
      widget.foodBank,
      mealSlot: widget.mealSlot,
      maxResults: 3,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_suggestions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          // ── Collapsed header chip ──────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 14,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _expanded
                        ? 'Hide alternatives'
                        : 'You might also enjoy... (${_suggestions.length})',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 13,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded suggestion list ───────────────────────────────────
          if (_expanded) ...[
            const SizedBox(height: 8),
            ..._suggestions.map((s) => _SwapSuggestionCard(suggestion: s)),
          ],
        ],
      ),
    );
  }
}

/// A single alternative food card shown inside the expanded [SmartSwapPanel].
class _SwapSuggestionCard extends StatelessWidget {
  final SwapSuggestion suggestion;

  const _SwapSuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final alt = suggestion.alternative;

    // Calorie delta (can be negative = fewer calories).
    final calDelta =
        (alt.calories - suggestion.original.calories).round();
    final calSign = calDelta <= 0 ? '' : '+';
    final calColour =
        calDelta <= 0 ? Colors.green.shade700 : colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + calorie delta row
          Row(
            children: [
              Expanded(
                child: Text(
                  alt.name,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$calSign$calDelta kcal',
                style: theme.textTheme.labelSmall?.copyWith(color: calColour),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Reason
          Text(
            suggestion.reason,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 5),

          // Improvement chips
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: suggestion.improvements
                .map((imp) => _ImprovementChip(label: imp))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// A small chip showing a single nutritional improvement label.
/// Uses theme colours — never danger-red per the ethical design spec.
class _ImprovementChip extends StatelessWidget {
  final String label;
  const _ImprovementChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPositive = label.startsWith('+');
    final bgColor = isPositive
        ? colorScheme.primaryContainer
        : colorScheme.tertiaryContainer;
    final textColor = isPositive
        ? colorScheme.onPrimaryContainer
        : colorScheme.onTertiaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// A compact row of three macro summary chips: P / F / C.
/// Used inside meal cards on the Diet Plan page.
class MacroChipRow extends StatelessWidget {
  final double proteinG;
  final double fatG;
  final double carbsG;

  const MacroChipRow({
    super.key,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MacroChip(label: 'P', value: proteinG, color: Colors.blue.shade700),
        const SizedBox(width: 4),
        _MacroChip(label: 'F', value: fatG, color: Colors.orange.shade700),
        const SizedBox(width: 4),
        _MacroChip(label: 'C', value: carbsG, color: Colors.green.shade700),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: ${value.toStringAsFixed(0)}g',
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
