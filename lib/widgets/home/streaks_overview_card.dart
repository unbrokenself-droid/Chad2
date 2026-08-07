import 'package:flutter/material.dart';

import '../../services/streak_service.dart';
import '../shared/progress_chip.dart';

/// A card showing all four of the app's daily-habit streaks —
/// workout, hydration, skincare, and the combined overall-wellness
/// streak — each as a small tile with its current run and best-ever
/// run.
///
/// Purely presentational: every figure comes from the [StreakInfo]
/// list the caller supplies (see [StreakService.allStreaks]), so this
/// widget itself has no notion of dates or persistence — it just
/// lays the numbers out. [onScheduleRestDay], if provided, adds a
/// small tappable action for opening the rest-day scheduling sheet.
class StreaksOverviewCard extends StatelessWidget {
  const StreaksOverviewCard({
    super.key,
    required this.streaks,
    this.onScheduleRestDay,
  });

  /// One entry per [StreakKind], in the order they should be
  /// displayed. Typically all four kinds, from
  /// [StreakService.allStreaks].
  final List<StreakInfo> streaks;

  /// Called when the user taps the "Rest day" action. Typically opens
  /// the rest-day scheduling sheet. If `null`, no action is shown.
  final VoidCallback? onScheduleRestDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    StreakInfo? overall;
    for (final streak in streaks) {
      if (streak.kind == StreakKind.overall) {
        overall = streak;
        break;
      }
    }
    final others = streaks.where((s) => s.kind != StreakKind.overall).toList();

    return Material(
      color: colorScheme.surfaceContainerHighest,
      elevation: 3,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.4),
      surfaceTintColor: colorScheme.surfaceTint,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (overall != null) ...[
              _OverallStreakHeader(info: overall),
              const SizedBox(height: 16),
              Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                for (var i = 0; i < others.length; i++) ...[
                  if (i != 0) const SizedBox(width: 10),
                  Expanded(child: _StreakTile(info: others[i])),
                ],
              ],
            ),
            if (onScheduleRestDay != null) ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: onScheduleRestDay,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.self_improvement,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          overall?.isRestDayToday ?? false
                              ? 'Resting today · Manage rest days'
                              : 'Schedule rest days',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Metadata (icon, label, color) that varies per [StreakKind], used
/// by both [_OverallStreakHeader] and [_StreakTile] so their styling
/// stays in sync.
class _StreakPresentation {
  const _StreakPresentation({
    required this.icon,
    required this.label,
    required this.colorOf,
  });

  final IconData icon;
  final String label;
  final Color Function(ColorScheme scheme) colorOf;

  static _StreakPresentation forKind(StreakKind kind) {
    switch (kind) {
      case StreakKind.workout:
        return _StreakPresentation(
          icon: Icons.fitness_center,
          label: 'Workout',
          colorOf: (scheme) => scheme.primary,
        );
      case StreakKind.hydration:
        return _StreakPresentation(
          icon: Icons.water_drop,
          label: 'Hydration',
          colorOf: (scheme) => Colors.lightBlue.shade600,
        );
      case StreakKind.skincare:
        return _StreakPresentation(
          icon: Icons.spa,
          label: 'Skincare',
          colorOf: (scheme) => Colors.pink.shade400,
        );
      case StreakKind.overall:
        return _StreakPresentation(
          icon: Icons.local_fire_department,
          label: 'Overall wellness',
          colorOf: (scheme) => Colors.deepOrange,
        );
    }
  }
}

/// The card's headline row: the combined overall-wellness streak,
/// styled like the app's original single-streak header.
class _OverallStreakHeader extends StatelessWidget {
  const _OverallStreakHeader({required this.info});

  final StreakInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final presentation = _StreakPresentation.forKind(info.kind);
    final color = presentation.colorOf(colorScheme);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(presentation.icon, color: color, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${info.currentStreak}-day streak',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                info.isRestDayToday
                    ? 'Resting today — hydration & skincare still count'
                    : info.activeToday
                    ? 'All habits done today — keep it going!'
                    : 'Finish today\'s habits to extend it',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: ProgressChip(label: 'Best ${info.longestStreak}'),
        ),
      ],
    );
  }
}

/// A single compact streak tile (icon, label, current/best) used for
/// the workout, hydration, and skincare streaks under the main
/// overall-wellness header.
class _StreakTile extends StatelessWidget {
  const _StreakTile({required this.info});

  final StreakInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final presentation = _StreakPresentation.forKind(info.kind);
    final color = presentation.colorOf(colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: info.activeToday
              ? color.withValues(alpha: 0.4)
              : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: Column(
        children: [
          Icon(
            info.isRestDayToday ? Icons.self_improvement : presentation.icon,
            size: 20,
            color: color,
          ),
          const SizedBox(height: 6),
          Text(
            '${info.currentStreak}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            presentation.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Best ${info.longestStreak}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
