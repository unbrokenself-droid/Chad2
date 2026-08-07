import 'package:flutter/material.dart';

import '../../../models/exercise.dart';
import '../../../services/completion_scope.dart';
import '../../../services/hydration_scope.dart';
import '../../../services/hydration_service.dart';
import '../../../services/streak_scope.dart';
import '../../../services/streak_service.dart';
import '../../../widgets/progress/bar_chart_card.dart';
import '../../../widgets/progress/stat_summary_card.dart';
import '../../../widgets/progress/weekly_activity_calendar.dart';
import '../../../widgets/shared/section_header.dart';
import '../../../widgets/shared/staggered_entrance.dart';

/// Width at which the stats grid switches from 2 to 3 columns and the
/// calendar/trends sections move from stacked to side-by-side.
const double _wideBreakpoint = 700;

/// "This Week" tab of the Progress destination — a live snapshot of
/// where the user stands right now.
///
/// Covers, in order: current streaks and this-week/all-time totals
/// (the stats grid), the current week at a glance (calendar), and
/// this week's day-by-day exercise and hydration totals (charts).
/// Everything here is scoped to the current week or to "right now" —
/// the longer-range view of the same underlying data (multi-week and
/// multi-month trends) lives in [HistoryTab] instead, so the same
/// figure isn't shown twice across the two tabs.
///
/// Built entirely from real, locally-stored data — no placeholders.
/// [CompletionScope] backs the streak, completion-count, and per-day
/// activity figures; [HydrationScope] backs water intake;
/// [StreakScope] backs the workout/hydration/skincare/overall
/// streaks (derived from the other services, so nothing here can
/// drift out of sync with what's shown elsewhere in the app).
class ThisWeekTab extends StatefulWidget {
  const ThisWeekTab({super.key, required this.allExercises});

  /// The full exercise catalog, loaded once by the parent
  /// `ProgressScreen` and handed down here — needed to look up each
  /// completed exercise's duration and category.
  final List<Exercise> allExercises;

  @override
  State<ThisWeekTab> createState() => _ThisWeekTabState();
}

class _ThisWeekTabState extends State<ThisWeekTab>
    with AutomaticKeepAliveClientMixin<ThisWeekTab> {
  // Keeps this tab's scroll position and entrance animations from
  // resetting every time the user swipes away and back — the same
  // "don't rebuild from scratch on switch" behavior
  // `MainNavigationScreen` gets from `IndexedStack` for the bottom
  // nav's tabs, achieved here via the mechanism that actually pairs
  // with a swipeable `TabBarView`.
  @override
  bool get wantKeepAlive => true;

  static const List<String> _dayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  List<Widget> _buildStatCards(_ThisWeekSummary summary) {
    return [
      StatSummaryCard(
        icon: Icons.local_fire_department,
        value: '${summary.workoutStreak.currentStreak}',
        label: 'Workout Streak',
        caption: 'Best: ${summary.workoutStreak.longestStreak} days',
      ),
      StatSummaryCard(
        icon: Icons.fitness_center,
        value: '${summary.totalCompletedCount}',
        label: 'Exercises Completed',
        caption: 'All time',
      ),
      StatSummaryCard(
        icon: Icons.timer_outlined,
        value: '${summary.minutesThisWeek}',
        label: 'Minutes Exercised',
        caption: 'This week',
      ),
      StatSummaryCard(
        icon: Icons.water_drop,
        value: '${summary.hydrationStreak.currentStreak}',
        label: 'Hydration Streak',
        caption: 'Best: ${summary.hydrationStreak.longestStreak} days',
      ),
      StatSummaryCard(
        icon: Icons.local_drink,
        value: summary.waterLitersThisWeekLabel,
        label: 'Water Consumed',
        caption: 'This week',
      ),
      StatSummaryCard(
        icon: Icons.spa,
        value: '${summary.skincareStreak.currentStreak}',
        label: 'Skincare Streak',
        caption: 'Best: ${summary.skincareStreak.longestStreak} days',
      ),
      StatSummaryCard(
        icon: Icons.emoji_events,
        value: '${summary.overallStreak.currentStreak}',
        label: 'Overall Wellness',
        caption: 'Best: ${summary.overallStreak.longestStreak} days',
      ),
    ];
  }

  /// Gathers every figure this tab shows, computed fresh from
  /// [widget.allExercises] and the app's shared services.
  ///
  /// The workout streak reads [StreakKind.workout] from
  /// [StreakService] rather than a raw completed-exercise streak, so
  /// a scheduled rest day correctly keeps the streak alive instead of
  /// reading as a break — the same figure History's "Active Days per
  /// Week" chart is ultimately built from, so the two can't disagree.
  _ThisWeekSummary _computeSummary(BuildContext context) {
    final completion = CompletionScope.of(context);
    final streakService = StreakScope.of(context);
    final hydration = HydrationScope.of(context);
    final catalogById = {
      for (final exercise in widget.allExercises) exercise.id: exercise,
    };
    final catalogTotal = catalogById.length;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));

    final weekActivity = <DayActivityLevel>[];
    final minutesPerDay = <double>[];
    final hydrationMlPerDay = <double>[];
    var minutesThisWeek = 0;
    var waterMlThisWeek = 0;
    var hydrationGoalDaysThisWeek = 0;

    for (var i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final completedIds = completion
          .idsCompletedOn(day)
          .where(catalogById.containsKey)
          .toList(growable: false);
      final dayMinutes = completedIds.fold<int>(
        0,
        (sum, id) => sum + catalogById[id]!.duration.inMinutes,
      );

      weekActivity.add(
        completedIds.isEmpty
            ? DayActivityLevel.none
            : (catalogTotal > 0 && completedIds.length >= catalogTotal)
                ? DayActivityLevel.full
                : DayActivityLevel.partial,
      );
      minutesPerDay.add(dayMinutes.toDouble());

      if (day.isAfter(today)) {
        // Don't count a day that hasn't happened yet.
        hydrationMlPerDay.add(0.0);
        continue;
      }

      minutesThisWeek += dayMinutes;
      final intake = hydration.intakeOn(day);
      hydrationMlPerDay.add(intake.toDouble());
      waterMlThisWeek += intake;
      if (hydration.goalReachedOn(day)) hydrationGoalDaysThisWeek++;
    }

    return _ThisWeekSummary(
      workoutStreak: streakService.infoFor(StreakKind.workout),
      totalCompletedCount: completion.totalCompletedCount,
      minutesThisWeek: minutesThisWeek,
      waterMlThisWeek: waterMlThisWeek,
      hydrationUnit: hydration.unit,
      weekActivity: weekActivity,
      todayIndex: today.weekday - 1,
      minutesPerDay: minutesPerDay,
      hydrationMlPerDay: hydrationMlPerDay,
      hydrationGoalDaysThisWeek: hydrationGoalDaysThisWeek,
      hydrationStreak: streakService.infoFor(StreakKind.hydration),
      skincareStreak: streakService.infoFor(StreakKind.skincare),
      overallStreak: streakService.infoFor(StreakKind.overall),
    );
  }

  List<Widget> _buildSections(_ThisWeekSummary summary, bool isWide) {
    const header = SectionHeader(
      size: SectionHeaderSize.large,
      subtitle: 'Your Progress',
      title: 'Consistency at a glance 📈',
    );

    const statsHeader = SectionHeader(title: 'This Week in Numbers');

    final statCards = _buildStatCards(summary);
    final statsGrid = GridView.count(
      crossAxisCount: isWide ? 3 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isWide ? 1.15 : 0.95,
      children: [
        for (var i = 0; i < statCards.length; i++)
          StaggeredEntrance(index: i, child: statCards[i]),
      ],
    );

    const calendarHeader = SectionHeader(title: 'Weekly Calendar');

    final calendarCard = WeeklyActivityCalendar(
      weekLabel: 'This Week',
      days: summary.weekActivity,
      today: summary.todayIndex,
    );

    const trendsHeader = SectionHeader(title: 'Trends');

    final minutesChart = BarChartCard(
      title: 'Minutes Exercised',
      subtitle: 'This week',
      values: summary.minutesPerDay,
      labels: _dayLabels,
      valueSuffix: ' min',
    );

    final hydrationChart = BarChartCard(
      title: 'Hydration',
      subtitle:
          '${summary.hydrationGoalDaysThisWeek}/7 goal days · '
          '${summary.waterLitersThisWeekLabel} this week',
      values: summary.hydrationValuesForChart,
      labels: _dayLabels,
      valueSuffix: summary.hydrationChartSuffix,
    );

    // Each entry pairs a section with the space to leave after it.
    final List<({Widget child, double gap})> items;
    if (isWide) {
      items = [
        (child: header, gap: 28),
        (child: statsHeader, gap: 12),
        (child: statsGrid, gap: 28),
        (
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    calendarHeader,
                    const SizedBox(height: 12),
                    calendarCard,
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    trendsHeader,
                    const SizedBox(height: 12),
                    minutesChart,
                    const SizedBox(height: 16),
                    hydrationChart,
                  ],
                ),
              ),
            ],
          ),
          gap: 0,
        ),
      ];
    } else {
      items = [
        (child: header, gap: 24),
        (child: statsHeader, gap: 12),
        (child: statsGrid, gap: 28),
        (child: calendarHeader, gap: 12),
        (child: calendarCard, gap: 28),
        (child: trendsHeader, gap: 12),
        (child: minutesChart, gap: 16),
        (child: hydrationChart, gap: 0),
      ];
    }

    final sections = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      sections.add(items[i].child);
      if (items[i].gap > 0) sections.add(SizedBox(height: items[i].gap));
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin.
    final summary = _computeSummary(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        final horizontalPadding = isWide ? 32.0 : 20.0;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20,
                horizontalPadding,
                32,
              ),
              children: _buildSections(summary, isWide),
            ),
          ),
        );
      },
    );
  }
}

/// Bundles every figure [ThisWeekTab] shows, computed once per build
/// by [_ThisWeekTabState._computeSummary] from the loaded exercise
/// catalog and the app's shared services.
class _ThisWeekSummary {
  const _ThisWeekSummary({
    required this.workoutStreak,
    required this.totalCompletedCount,
    required this.minutesThisWeek,
    required this.waterMlThisWeek,
    required this.hydrationUnit,
    required this.weekActivity,
    required this.todayIndex,
    required this.minutesPerDay,
    required this.hydrationMlPerDay,
    required this.hydrationGoalDaysThisWeek,
    required this.hydrationStreak,
    required this.skincareStreak,
    required this.overallStreak,
  });

  /// Consecutive days, ending today, with either a completed exercise
  /// or a scheduled rest day, from [StreakService]'s
  /// [StreakKind.workout].
  final StreakInfo workoutStreak;

  /// Total exercise completions ever recorded, across every day.
  final int totalCompletedCount;

  /// Total minutes of completed exercises so far this week (Monday
  /// through today).
  final int minutesThisWeek;

  /// Total milliliters of water logged so far this week (Monday
  /// through today), from [HydrationService].
  final int waterMlThisWeek;

  /// The display unit active when this summary was computed —
  /// captured here rather than read live, since this is a plain,
  /// immutable snapshot rather than something that re-reads
  /// [HydrationService] on every access.
  final HydrationUnit hydrationUnit;

  /// [waterMlThisWeek] formatted for display in [hydrationUnit]: e.g.
  /// '1.8 L' or '0.5 gal', matching how water intake is normally
  /// communicated rather than showing a raw milliliter count.
  String get waterLitersThisWeekLabel =>
      HydrationService.formatAmountCoarse(waterMlThisWeek, hydrationUnit);

  /// This week's activity level, Monday through Sunday, for
  /// [WeeklyActivityCalendar].
  final List<DayActivityLevel> weekActivity;

  /// Index (0 = Monday .. 6 = Sunday) of today within [weekActivity].
  final int todayIndex;

  /// Minutes of completed exercises per day this week, Monday through
  /// Sunday, for the minutes-exercised bar chart.
  final List<double> minutesPerDay;

  /// Milliliters of water logged per day this week, Monday through
  /// Sunday. Stays in milliliters regardless of [hydrationUnit] —
  /// use [hydrationValuesForChart] for a display-ready version.
  final List<double> hydrationMlPerDay;

  /// [hydrationMlPerDay] converted to [hydrationUnit] for display —
  /// [hydrationMlPerDay] itself stays in milliliters regardless (as
  /// its name promises), since converting it in place would make the
  /// values silently stop matching what the field is called.
  List<double> get hydrationValuesForChart {
    switch (hydrationUnit) {
      case HydrationUnit.metric:
        return hydrationMlPerDay;
      case HydrationUnit.imperial:
        return hydrationMlPerDay
            .map((ml) => HydrationService.mlToFlOz(ml.round()))
            .toList();
    }
  }

  /// Suffix for [hydrationValuesForChart]'s bars, matching whichever
  /// unit those values are actually in.
  String get hydrationChartSuffix =>
      hydrationUnit == HydrationUnit.metric ? ' ml' : ' fl oz';

  /// How many days this week (so far) reached the hydration goal.
  final int hydrationGoalDaysThisWeek;

  /// The hydration streak (goal reached every day), from
  /// [StreakService].
  final StreakInfo hydrationStreak;

  /// The skincare streak (both routines fully checked off every
  /// day), from [StreakService].
  final StreakInfo skincareStreak;

  /// The combined overall-wellness streak (workout, hydration, and
  /// skincare all done the same day), from [StreakService].
  final StreakInfo overallStreak;
}
