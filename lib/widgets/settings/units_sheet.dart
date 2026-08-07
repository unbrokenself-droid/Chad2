import 'package:flutter/material.dart';

import '../../services/hydration_scope.dart';
import '../../services/hydration_service.dart';

/// Opens the units picker bottom sheet.
///
/// Convenience wrapper around [showModalBottomSheet], matching how
/// [showThemeModeSheet] and [showReminderSheet] are exposed, so
/// Settings doesn't need to know the sheet's shape/styling details.
Future<void> showUnitsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const UnitsSheet(),
  );
}

/// Bottom sheet offering both [HydrationUnit] options.
///
/// Reads and writes through [HydrationScope], so choosing a unit here
/// takes effect immediately across every screen that displays
/// hydration amounts, and persists across restarts. There's
/// currently only one unit-based measurement in the app (hydration,
/// in milliliters) — see [HydrationUnit]'s doc comment — so this
/// sheet is intentionally hydration-specific rather than a more
/// general "units" abstraction with nothing else to apply to yet.
class UnitsSheet extends StatelessWidget {
  const UnitsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hydration = HydrationScope.of(context);
    final currentUnit = hydration.unit;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.straighten,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Units',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'How hydration amounts are shown',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (final unit in HydrationUnit.values) ...[
              _UnitOption(
                unit: unit,
                selected: unit == currentUnit,
                onTap: () => hydration.setUnit(unit),
              ),
              if (unit != HydrationUnit.values.last)
                const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single selectable unit option, showing a short example amount
/// so the difference is concrete rather than just a label — "8 fl oz"
/// reads more clearly than the word "Imperial" alone.
class _UnitOption extends StatelessWidget {
  const _UnitOption({
    required this.unit,
    required this.selected,
    required this.onTap,
  });

  final HydrationUnit unit;
  final bool selected;
  final VoidCallback onTap;

  String get _example =>
      unit == HydrationUnit.metric ? 'e.g. 250 ml' : 'e.g. 8 fl oz';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? colorScheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _example,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: selected ? 1 : 0,
              child: Icon(Icons.check_circle, color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
