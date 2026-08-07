import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../../services/hydration_scope.dart';
import '../../services/hydration_service.dart';
import '../../services/reminder_settings_service.dart';
import '../../services/skincare_service.dart';
import '../../services/wellness_score_service.dart';
import '../home/wellness_score_ring.dart';

/// Everything the calendar's day-detail panel shows for a single
/// selected date, gathered by the caller ([CalendarScreen]) from the
/// app's shared services.
@immutable
class DaySummary {
  const DaySummary({
    required this.date,
    required this.completedExercises,
    required this.hydrationMl,
    required this.hydrationGoalMl,
    required this.morningSteps,
    required this.nightSteps,
    required this.postureEvents,
    required this.wellnessSnapshot,
  });

  final DateTime date;

  /// Exercises completed on [date], in whatever order they were
  /// completed/loaded.
  final List<Exercise> completedExercises;

  /// Milliliters of water logged on [date].
  final int hydrationMl;

  /// The hydration goal that was active for [date] (the service only
  /// tracks one current goal, so this reflects today's setting
  /// applied retroactively — consistent with how the rest of the app
  /// treats the goal as a single current value rather than a
  /// historical one).
  final int hydrationGoalMl;

  /// Morning skincare steps, each paired with whether it was checked
  /// off on [date].
  final List<(SkincareStep step, bool completed)> morningSteps;

  /// Night skincare steps, each paired with whether it was checked
  /// off on [date].
  final List<(SkincareStep step, bool completed)> nightSteps;

  /// Posture reminders acknowledged on [date], most recent first.
  final List<ReminderEvent> postureEvents;

  /// [date]'s full wellness score snapshot.
  final WellnessScoreSnapshot wellnessSnapshot;

  /// Whether nothing at all was tracked on [date] — no exercises, no
  /// water, no skincare steps, and no posture check-ins. Drives an
  /// empty-state message rather than a wall of zeroed-out sections.
  bool get isEmpty {
    return completedExercises.isEmpty &&
        hydrationMl <= 0 &&
        morningSteps.every((entry) => !entry.$2) &&
        nightSteps.every((entry) => !entry.$2) &&
        postureEvents.isEmpty;
  }
}

/// Detail panel shown below the calendar grid for whichever date is
/// currently selected: that day's completed routines, hydration,
/// skincare checklists, posture check-ins, and overall wellness
/// score.
///
/// Purely presentational — takes an already-assembled [DaySummary]
/// rather than reading services directly, mirroring how
/// [WellnessScoreCard] takes a pre-computed snapshot.
class DaySummaryPanel extends StatelessWidget {
  const DaySummaryPanel({super.key, required this.summary});

  final DaySummary summary;

  static const List<String> _weekdayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];

  String _formattedDate() {
    final d = summary.date;
    return '${_weekdayNames[d.weekday - 1]}, ${_monthNames[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      elevation: 2,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
      surfaceTintColor: colorScheme.surfaceTint,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formattedDate(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (summary.isEmpty)
              _EmptyDayNotice(colorScheme: colorScheme, theme: theme)
            else ...[
              Center(
                child: WellnessScoreRing(
                  score: summary.wellnessSnapshot.score,
                  size: 108,
                  strokeWidth: 10,
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel(
                icon: Icons.fitness_center,
                label: 'Completed Routines',
              ),
              const SizedBox(height: 8),
              if (summary.completedExercises.isEmpty)
                _NoneLoggedText(theme: theme, colorScheme: colorScheme)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final exercise in summary.completedExercises)
                      _Pill(
                        icon: exercise.icon,
                        label: exercise.title,
                      ),
                  ],
                ),
              const SizedBox(height: 18),
              _SectionLabel(icon: Icons.water_drop, label: 'Hydration'),
              const SizedBox(height: 8),
              _HydrationRow(
                intakeMl: summary.hydrationMl,
                goalMl: summary.hydrationGoalMl,
              ),
              const SizedBox(height: 18),
              _SectionLabel(icon: Icons.spa, label: 'Skincare'),
              const SizedBox(height: 8),
              _SkincareRow(
                label: 'Morning',
                steps: summary.morningSteps,
              ),
              const SizedBox(height: 8),
              _SkincareRow(
                label: 'Night',
                steps: summary.nightSteps,
              ),
              const SizedBox(height: 18),
              _SectionLabel(
                icon: Icons.accessibility_new,
                label: 'Posture Sessions',
              ),
              const SizedBox(height: 8),
              if (summary.postureEvents.isEmpty)
                _NoneLoggedText(theme: theme, colorScheme: colorScheme)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final event in summary.postureEvents)
                      _Pill(
                        icon: Icons.check_circle_outline,
                        label: _timeLabel(event.time),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _timeLabel(DateTime time) {
    final hour24 = time.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour24 < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _NoneLoggedText extends StatelessWidget {
  const _NoneLoggedText({required this.theme, required this.colorScheme});

  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Nothing logged',
      style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HydrationRow extends StatelessWidget {
  const _HydrationRow({required this.intakeMl, required this.goalMl});

  final int intakeMl;
  final int goalMl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = goalMl <= 0
        ? 0.0
        : (intakeMl / goalMl).clamp(0.0, 1.0).toDouble();
    final unit = HydrationScope.of(context).unit;

    // Computed directly here (rather than via
    // HydrationService.formatAmountCoarse for both numbers) to keep
    // this row's compact "X / Y unit" style — one trailing unit
    // label, not two — rather than the more verbose "X unit / Y unit"
    // that calling the shared formatter twice would produce.
    final String amountText;
    final String unitSuffix;
    switch (unit) {
      case HydrationUnit.metric:
        final liters = (intakeMl / 1000).toStringAsFixed(1);
        final goalLiters = (goalMl / 1000).toStringAsFixed(1);
        amountText = '$liters / $goalLiters';
        unitSuffix = 'L';
      case HydrationUnit.imperial:
        final gallons = (HydrationService.mlToFlOz(intakeMl) / 128)
            .toStringAsFixed(1);
        final goalGallons = (HydrationService.mlToFlOz(goalMl) / 128)
            .toStringAsFixed(1);
        amountText = '$gallons / $goalGallons';
        unitSuffix = 'gal';
    }

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$amountText $unitSuffix',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SkincareRow extends StatelessWidget {
  const _SkincareRow({required this.label, required this.steps});

  final String label;
  final List<(SkincareStep step, bool completed)> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (steps.isEmpty) {
      return Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: _NoneLoggedText(theme: theme, colorScheme: colorScheme),
          ),
        ],
      );
    }

    final completedCount = steps.where((entry) => entry.$2).length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in steps)
                _StepChip(step: entry.$1, completed: entry.$2),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2, left: 6),
          child: Text(
            '$completedCount/${steps.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.step, required this.completed});

  final SkincareStep step;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = completed
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.5);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: completed
            ? colorScheme.primary.withValues(alpha: 0.1)
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              completed ? Icons.check_circle : Icons.circle_outlined,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              step.label,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDayNotice extends StatelessWidget {
  const _EmptyDayNotice({required this.theme, required this.colorScheme});

  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 20,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nothing was tracked on this day.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
