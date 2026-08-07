import 'package:flutter/material.dart';

import '../../services/skincare_scope.dart';
import '../../services/skincare_service.dart';
import '../../utils/app_haptics.dart';
import 'skincare_sheet.dart';

/// Compact, directly-interactive skincare check-in for the Home
/// screen: a checkbox per step of whichever routine (morning or
/// night) still needs attention, so checking off a step doesn't
/// require opening [SkincareSheet] for the common case. That sheet
/// stays reachable (tap the header row) for switching between
/// morning/night explicitly or customizing which steps each one
/// includes — this card doesn't replace it, just covers the
/// "check off what I just did" tap.
///
/// Reads and writes through [SkincareScope]'s existing
/// [SkincareService.toggleStep], so this card, [SkincareSheet], and
/// the Home screen's "Skincare Check-in" reminder card all stay in
/// sync automatically.
class SkincareCheckInCard extends StatelessWidget {
  const SkincareCheckInCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final skincare = SkincareScope.of(context);

    final routine = skincare.routineNeedingAttention;
    final steps = skincare.enabledStepsFor(routine);
    final completed = skincare.completedCountFor(routine);
    final total = skincare.totalCountFor(routine);
    final routineLabel = routine == SkincareRoutine.morning
        ? 'Morning'
        : 'Night';

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
              onTap: () => showSkincareSheet(context),
              borderRadius: BorderRadius.circular(14),
              child: Row(
                children: [
                  Icon(Icons.spa, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Skincare Check-in',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '$routineLabel · $completed of $total',
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
          if (steps.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'No steps enabled for $routineLabel yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  for (final step in steps)
                    _StepCheckboxRow(
                      step: step,
                      checked: skincare.isStepCompleted(step, routine),
                      onChanged: () {
                        AppHaptics.light();
                        skincare.toggleStep(step, routine);
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StepCheckboxRow extends StatelessWidget {
  const _StepCheckboxRow({
    required this.step,
    required this.checked,
    required this.onChanged,
  });

  final SkincareStep step;
  final bool checked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onChanged,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                checked
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 22,
                color: checked ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Icon(
                step.icon,
                size: 16,
                color: checked ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    color: checked
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
