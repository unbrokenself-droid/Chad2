import 'package:flutter/material.dart';

/// How much of a day's tracked activity was completed, driving how
/// filled-in its cell appears in a [MonthCalendarGrid]. Deliberately
/// mirrors [DayActivityLevel] from the weekly calendar so the two
/// widgets read consistently, but is redeclared here rather than
/// shared since a month grid has its own out-of-month/future-day
/// states that the weekly widget doesn't need.
enum CalendarDayLevel {
  /// Nothing logged.
  none,

  /// Some, but not all, of the day's routines were completed.
  partial,

  /// Everything tracked for the day was completed.
  full,
}

/// One day cell's data for [MonthCalendarGrid].
@immutable
class CalendarDayData {
  const CalendarDayData({
    required this.date,
    required this.level,
    this.wellnessScore,
  });

  /// The calendar date this cell represents.
  final DateTime date;

  /// How complete this day's tracked activity was.
  final CalendarDayLevel level;

  /// That day's wellness score (0–100), if there's enough data to
  /// show one. `null` renders as an empty cell rather than a zero
  /// score, distinguishing "no data" from "a genuinely low score".
  final int? wellnessScore;
}

/// A month-at-a-glance calendar grid: one cell per day, shaded by
/// [CalendarDayLevel] and (optionally) labelled with that day's
/// wellness score, with the current month's days emphasized over
/// leading/trailing days from adjacent months.
///
/// Purely presentational and stateless — month navigation, data
/// loading, and tap handling all live in the caller (see
/// [CalendarScreen]). Days after [today] and days outside the
/// currently-displayed month render dimmed and are not tappable,
/// since there's nothing to show for a day that hasn't happened yet
/// or that belongs to a month not currently in view.
class MonthCalendarGrid extends StatelessWidget {
  const MonthCalendarGrid({
    super.key,
    required this.month,
    required this.days,
    required this.today,
    this.selectedDate,
    this.onDaySelected,
  });

  /// The first day of the month currently displayed. Only its year
  /// and month are used.
  final DateTime month;

  /// One entry per day actually in [month] (i.e. `days.length` equals
  /// that month's day count), in day-of-month order.
  final List<CalendarDayData> days;

  /// Today's date, used to dim future days and to outline today's
  /// cell.
  final DateTime today;

  /// The currently-selected date, if any, highlighted with a filled
  /// outline distinct from today's.
  final DateTime? selectedDate;

  /// Called with the tapped date when a selectable day cell is
  /// tapped. Omitted (cells still render, just inert) if the caller
  /// doesn't need selection.
  final ValueChanged<DateTime>? onDaySelected;

  static const List<String> _weekdayLabels = [
    'M', 'T', 'W', 'T', 'F', 'S', 'S',
  ];

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final firstOfMonth = DateTime(month.year, month.month, 1);
    // Monday-first leading blank count: firstOfMonth.weekday is
    // 1 (Mon) .. 7 (Sun) already, so 1..7 maps directly to 0..6
    // leading blanks.
    final leadingBlanks = firstOfMonth.weekday - 1;

    Color fillFor(CalendarDayLevel level, {required bool isFuture}) {
      if (isFuture) return colorScheme.primary.withValues(alpha: 0.04);
      switch (level) {
        case CalendarDayLevel.none:
          return colorScheme.primary.withValues(alpha: 0.08);
        case CalendarDayLevel.partial:
          return colorScheme.primary.withValues(alpha: 0.45);
        case CalendarDayLevel.full:
          return colorScheme.primary;
      }
    }

    Color contentColorFor(CalendarDayLevel level, {required bool isFuture}) {
      if (isFuture) return colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
      return level == CalendarDayLevel.full
          ? colorScheme.onPrimary
          : colorScheme.onSurface;
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
                for (final label in _weekdayLabels)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.82,
              children: [
                for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
                for (var i = 0; i < days.length; i++)
                  Builder(
                    builder: (context) {
                      final data = days[i];
                      final isFuture = data.date.isAfter(today);
                      final isToday = _isSameDay(data.date, today);
                      final isSelected = selectedDate != null &&
                          _isSameDay(data.date, selectedDate!);
                      final score = data.wellnessScore;

                      final cell = AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: fillFor(data.level, isFuture: isFuture),
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(
                                  color: colorScheme.primary,
                                  width: 2,
                                )
                              : isToday
                                  ? Border.all(
                                      color: colorScheme.primary
                                          .withValues(alpha: 0.6),
                                      width: 1.4,
                                    )
                                  : null,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${data.date.day}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: contentColorFor(
                                    data.level,
                                    isFuture: isFuture,
                                  ),
                                  fontWeight: isToday
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                              if (score != null && !isFuture)
                                Text(
                                  '$score',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 9,
                                    color: contentColorFor(
                                      data.level,
                                      isFuture: isFuture,
                                    ).withValues(alpha: 0.85),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );

                      final levelLabel = switch (data.level) {
                        CalendarDayLevel.none => 'no activity',
                        CalendarDayLevel.partial => 'some activity',
                        CalendarDayLevel.full => 'fully completed',
                      };

                      return Semantics(
                        label: '${data.date.month}/${data.date.day}'
                            '${isToday ? ' (today)' : ''}, $levelLabel',
                        button: !isFuture && onDaySelected != null,
                        child: (isFuture || onDaySelected == null)
                            ? cell
                            : InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => onDaySelected!(data.date),
                                child: cell,
                              ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _LegendDot(
                  color: fillFor(CalendarDayLevel.full, isFuture: false),
                  label: 'Full',
                ),
                const SizedBox(width: 16),
                _LegendDot(
                  color: fillFor(CalendarDayLevel.partial, isFuture: false),
                  label: 'Partial',
                ),
                const SizedBox(width: 16),
                _LegendDot(
                  color: fillFor(CalendarDayLevel.none, isFuture: false),
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
