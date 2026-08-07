import 'package:flutter/material.dart';

/// How much activity was logged on a given day, driving how filled-in
/// its cell appears in a [WeeklyActivityCalendar].
enum DayActivityLevel {
  /// Nothing logged.
  none,

  /// Some, but not all, of the day's routines were completed.
  partial,

  /// Everything planned for the day was completed.
  full,
}

/// A week-at-a-glance calendar placeholder for the Progress screen.
///
/// Renders seven day cells (Monday through Sunday) shaded by
/// [DayActivityLevel], plus a small legend. Purely presentational —
/// [weekLabel] and [days] are supplied by the caller as static/dummy
/// data; there is no date logic or navigation here yet.
class WeeklyActivityCalendar extends StatelessWidget {
  const WeeklyActivityCalendar({
    super.key,
    required this.weekLabel,
    required this.days,
    this.today,
  }) : assert(days.length == 7, 'days must have 7 entries');

  /// A label for the displayed week, e.g. 'This Week' or 'Jun 30 – Jul 6'.
  final String weekLabel;

  /// Activity level for each day, Monday through Sunday.
  final List<DayActivityLevel> days;

  /// Index (0 = Monday .. 6 = Sunday) of today, if it falls within the
  /// displayed week. Used only to draw a small outline on that cell.
  final int? today;

  static const List<String> _dayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final todayIndex = today;

    Color fillFor(DayActivityLevel level) {
      switch (level) {
        case DayActivityLevel.none:
          return colorScheme.primary.withValues(alpha: 0.08);
        case DayActivityLevel.partial:
          return colorScheme.primary.withValues(alpha: 0.45);
        case DayActivityLevel.full:
          return colorScheme.primary;
      }
    }

    Color contentColorFor(DayActivityLevel level) {
      return level == DayActivityLevel.full
          ? colorScheme.onPrimary
          : colorScheme.primary;
    }

    return Material(
      color: colorScheme.surfaceContainerHighest,
      elevation: 2,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.35),
      surfaceTintColor: colorScheme.surfaceTint,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    weekLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ExcludeSemantics(
                  child: Row(
                    children: [
                      Icon(
                        Icons.chevron_left,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(days.length, (i) {
                final level = days[i];
                final isToday = todayIndex == i;
                final levelLabel = switch (level) {
                  DayActivityLevel.none => 'no activity',
                  DayActivityLevel.partial => 'some activity',
                  DayActivityLevel.full => 'fully completed',
                };
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == days.length - 1 ? 0 : 8,
                    ),
                    child: Semantics(
                      label: '${_dayLabels[i]}${isToday ? ' (today)' : ''}, '
                          '$levelLabel',
                      child: Column(
                        children: [
                          ExcludeSemantics(
                            child: Text(
                              _dayLabels[i],
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          ExcludeSemantics(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: Duration(milliseconds: 300 + i * 60),
                              curve: Curves.easeOutBack,
                              builder: (context, animatedValue, child) {
                                return Transform.scale(
                                  scale: 0.85 + (0.15 * animatedValue),
                                  child: child,
                                );
                              },
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: fillFor(level),
                                    borderRadius: BorderRadius.circular(10),
                                    border: isToday
                                        ? Border.all(
                                            color: colorScheme.primary,
                                            width: 1.6,
                                          )
                                        : null,
                                  ),
                                  child: level == DayActivityLevel.full
                                      ? Icon(
                                          Icons.check,
                                          size: 14,
                                          color: contentColorFor(level),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _LegendDot(
                  color: fillFor(DayActivityLevel.full),
                  label: 'Full',
                ),
                const SizedBox(width: 16),
                _LegendDot(
                  color: fillFor(DayActivityLevel.partial),
                  label: 'Partial',
                ),
                const SizedBox(width: 16),
                _LegendDot(
                  color: fillFor(DayActivityLevel.none),
                  label: 'None',
                  outlined: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.outlined = false,
  });

  final Color color;
  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: outlined
                ? Border.all(color: colorScheme.onSurfaceVariant, width: 1)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
