import 'package:flutter/material.dart';

import '../../models/wellness_article.dart';
import '../../services/accessibility_scope.dart';
import '../shared/min_tap_target.dart' show kLargeTouchTargetSize;

/// A horizontally-scrolling row of Material 3 [FilterChip]s, one per
/// [WellnessTopic], plus an optional "Bookmarked" chip — for
/// narrowing the Wellness Library.
///
/// Multi-select: any number of topics can be active at once, and an
/// empty [selected] set is treated by the caller as "no filter" —
/// this widget only reports which chips are toggled on. Deliberately
/// mirrors [CategoryFilterChips]'s shape and styling so the library
/// reads as part of the same design system as the Exercises catalog.
class TopicFilterChips extends StatelessWidget {
  const TopicFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
    this.bookmarkedOnly = false,
    this.onBookmarkedOnlyChanged,
  });

  /// The set of currently-active topic filters.
  final Set<WellnessTopic> selected;

  /// Called with the topic that was tapped and its new selected
  /// state.
  final void Function(WellnessTopic topic, bool isSelected) onChanged;

  /// Whether the "Bookmarked" chip is currently active.
  final bool bookmarkedOnly;

  /// Called when the "Bookmarked" chip is toggled. Leave `null` to
  /// hide the chip entirely.
  final ValueChanged<bool>? onBookmarkedOnlyChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showBookmarkedChip = onBookmarkedOnlyChanged != null;
    final itemCount =
        WellnessTopic.values.length + (showBookmarkedChip ? 1 : 0);

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
          if (showBookmarkedChip && index == 0) {
            return FilterChip(
              avatar: Icon(
                bookmarkedOnly ? Icons.bookmark : Icons.bookmark_border,
                size: 16,
                color: bookmarkedOnly
                    ? colorScheme.onPrimary
                    : colorScheme.primary,
              ),
              label: const Text('Bookmarked'),
              selected: bookmarkedOnly,
              onSelected: onBookmarkedOnlyChanged,
              showCheckmark: false,
              visualDensity: density,
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                color: bookmarkedOnly
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: colorScheme.surfaceContainerHighest,
              selectedColor: colorScheme.primary,
              side: BorderSide(
                color: bookmarkedOnly
                    ? Colors.transparent
                    : colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            );
          }

          final topic =
              WellnessTopic.values[index - (showBookmarkedChip ? 1 : 0)];
          final isSelected = selected.contains(topic);

          return FilterChip(
            avatar: Icon(
              topic.icon,
              size: 16,
              color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
            ),
            label: Text(topic.chipLabel),
            selected: isSelected,
            onSelected: (value) => onChanged(topic, value),
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
