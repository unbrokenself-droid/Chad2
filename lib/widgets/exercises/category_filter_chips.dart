import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../../services/accessibility_scope.dart';
import '../shared/min_tap_target.dart' show kLargeTouchTargetSize;
import 'exercise_card.dart' show ExerciseCategoryLabel;

/// A horizontally-scrolling row of Material 3 [FilterChip]s, one per
/// [ExerciseCategory], for narrowing the Exercises catalog by category.
///
/// Multi-select: any number of categories can be active at once, and
/// an empty [selected] set is treated by the caller as "no filter" —
/// this widget only reports which chips are toggled on, it doesn't
/// interpret what an empty selection means.
///
/// Purely controlled: [selected] is the source of truth and this
/// widget holds no state of its own, so it always reflects whatever
/// the parent currently has active (e.g. after a "Clear filters"
/// action resets it).
class CategoryFilterChips extends StatelessWidget {
  const CategoryFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
    this.favoritesOnly = false,
    this.onFavoritesOnlyChanged,
  });

  /// The set of currently-active category filters.
  final Set<ExerciseCategory> selected;

  /// Called with the category that was tapped and its new selected
  /// state, so the caller can add/remove it from its own selection
  /// set.
  final void Function(ExerciseCategory category, bool isSelected) onChanged;

  /// Whether the "Favorites" chip is currently active.
  final bool favoritesOnly;

  /// Called when the "Favorites" chip is toggled. Leave `null` to hide
  /// the chip entirely, so this widget stays usable in contexts
  /// without a favorites concept.
  final ValueChanged<bool>? onFavoritesOnlyChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showFavoritesChip = onFavoritesOnlyChanged != null;
    final itemCount =
        ExerciseCategory.values.length + (showFavoritesChip ? 1 : 0);

    final largeTargets = AccessibilityScope.of(context).largeTouchTargets;
    final rowHeight = largeTargets ? kLargeTouchTargetSize : 36.0;
    final density = largeTargets
        ? VisualDensity.standard
        : VisualDensity.compact;

    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (showFavoritesChip && index == 0) {
            return FilterChip(
              avatar: Icon(
                favoritesOnly ? Icons.favorite : Icons.favorite_border,
                size: 16,
                color: favoritesOnly
                    ? colorScheme.onPrimary
                    : const Color(0xFFE0435B),
              ),
              label: const Text('Favorites'),
              selected: favoritesOnly,
              onSelected: onFavoritesOnlyChanged,
              showCheckmark: false,
              visualDensity: density,
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                color: favoritesOnly
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: colorScheme.surfaceContainerHighest,
              selectedColor: colorScheme.primary,
              side: BorderSide(
                color: favoritesOnly
                    ? Colors.transparent
                    : colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            );
          }

          final category =
              ExerciseCategory.values[index - (showFavoritesChip ? 1 : 0)];
          final isSelected = selected.contains(category);

          return FilterChip(
            label: Text(category.label),
            selected: isSelected,
            onSelected: (value) => onChanged(category, value),
            showCheckmark: false,
            visualDensity: density,
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              color:
                  isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: colorScheme.surfaceContainerHighest,
            selectedColor: colorScheme.primary,
            side: BorderSide(
              color: isSelected
                  ? Colors.transparent
                  : colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          );
        },
      ),
    );
  }
}
