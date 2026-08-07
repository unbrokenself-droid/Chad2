import 'package:flutter/material.dart';

import '../../services/hydration_scope.dart';
import '../../services/hydration_service.dart';
import '../../utils/app_haptics.dart';
import 'hydration_sheet.dart';

/// Compact, directly-interactive hydration check-in for the Home
/// screen: one checkbox per glass toward today's goal, so logging
/// water doesn't require opening [HydrationSheet] for the common
/// case. That sheet stays reachable (tap the header row) for
/// quick-add amounts in other increments, editing the goal, or
/// resetting today's total — this card doesn't replace it, just
/// covers the "I just drank a glass" tap.
///
/// Reads and writes through [HydrationScope]'s existing
/// [HydrationService.addIntake], so this card, [HydrationSheet], and
/// the Home screen's "Stay Hydrated" reminder card all stay in sync
/// automatically — there's no separate glass-counted state of its
/// own to drift out of sync with the real logged amount.
class HydrationCheckInCard extends StatelessWidget {
  const HydrationCheckInCard({super.key});

  /// Treated as one "glass" for the checkbox row — matches the
  /// existing quick-add amounts' middle option
  /// ([HydrationService.quickAddAmountsMl]) for whichever unit is
  /// active (250 ml, or 8 fl oz), so a checked box always corresponds
  /// to an amount [HydrationSheet] already offers, not an arbitrary
  /// new increment.
  static int _glassSizeMl(HydrationService hydration) =>
      hydration.quickAddAmountsMl[1];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hydration = HydrationScope.of(context);

    final glassSize = _glassSizeMl(hydration);
    // At least 1, so a goal smaller than one glass still shows
    // something to check off; capped so an unusually large goal
    // doesn't produce a checkbox row too long to comfortably fit.
    // Uncommon goals are still fully served by HydrationSheet's ring
    // and quick-add buttons — this card is the fast common-case path,
    // not the only way to log water.
    final totalGlasses = (hydration.goalMl / glassSize).ceil().clamp(1, 12);
    final filledGlasses = (hydration.todayIntakeMl / glassSize)
        .round()
        .clamp(0, totalGlasses);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => showHydrationSheet(context),
              borderRadius: BorderRadius.circular(14),
              child: Row(
                children: [
                  Icon(
                    Icons.water_drop,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hydration Check-in',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${hydration.formatMl(hydration.todayIntakeMl)} of '
                    '${hydration.formatMl(hydration.goalMl)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < totalGlasses; i++)
                _GlassCheckbox(
                  filled: i < filledGlasses,
                  onTap: () {
                    AppHaptics.light();
                    // Tapping a filled glass unchecks it (and, since
                    // fill state is always contiguous from 0, every
                    // glass after it too); tapping an unfilled one
                    // fills it and everything before it — the usual
                    // "tap to set the level" behavior of a checkbox
                    // row standing in for a running total, same as a
                    // star rating.
                    final targetGlasses = i < filledGlasses ? i : i + 1;
                    final targetMl = targetGlasses * glassSize;
                    hydration.addIntake(targetMl - hydration.todayIntakeMl);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassCheckbox extends StatelessWidget {
  const _GlassCheckbox({required this.filled, required this.onTap});

  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: filled ? 'Glass logged' : 'Log a glass of water',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: filled
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: filled ? colorScheme.primary : colorScheme.outlineVariant,
              width: 1.5,
            ),
          ),
          child: Icon(
            filled ? Icons.check_rounded : Icons.water_drop_outlined,
            size: 18,
            color: filled ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
