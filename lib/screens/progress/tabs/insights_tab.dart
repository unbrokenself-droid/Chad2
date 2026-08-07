import 'package:flutter/material.dart';

import '../../../models/exercise.dart';
import '../../../models/premium_feature.dart';
import '../../../services/completion_scope.dart';
import '../../../services/exercise_completion_service.dart';
import '../../../services/hydration_scope.dart';
import '../../../services/hydration_service.dart';
import '../../../services/premium_scope.dart';
import '../../../widgets/exercises/exercise_card.dart' show ExerciseCategoryLabel;
import '../../../widgets/insights/insight_card.dart';
import '../../../widgets/premium/upgrade_card.dart';
import '../../../widgets/shared/section_header.dart';
import '../../../widgets/shared/staggered_entrance.dart';

/// How many trailing days of history each insight looks back over.
/// A calendar month gives enough signal for day-of-week and category
/// patterns to be meaningful while staying recent enough to reflect
/// the user's current habits rather than their very first week ever.
const int _lookbackDays = 30;

/// Below this many active days in the lookback window, day-of-week
/// and category insights are still shown but flagged as an
/// [InsightConfidence.emerging] "early trend" rather than presented
/// with full confidence.
const int _emergingThreshold = 6;

/// "Insights" tab of the Progress destination.
///
/// Turns the same locally-stored history [ThisWeekTab] and
/// [HistoryTab] already read — [CompletionScope] and [HydrationScope]
/// — into a handful of plain-language, personalized findings: which
/// day of the week the user is most consistent on, which exercise
/// category they complete least often relative to the others, how
/// steady their hydration habit is, their average daily activity, and
/// how this week compares with last week.
///
/// This tab's framing is deliberately different in kind from the
/// other two, not just in time window: [ThisWeekTab] and [HistoryTab]
/// show numbers and charts, while this tab turns those same numbers
/// into short interpreted sentences. That's what keeps it from
/// overlapping with the other two despite reading the same
/// underlying data.
///
/// Every figure here is derived on-device, at build time, from
/// existing local statistics. Nothing is fetched from a server and
/// nothing is stored separately — if the underlying completion or
/// hydration history changes anywhere else in the app, these
/// insights recompute the next time this tab is built.
class InsightsTab extends StatefulWidget {
  const InsightsTab({super.key, required this.allExercises});

  /// The full exercise catalog, loaded once by the parent
  /// `ProgressScreen` and handed down here — needed to weigh category
  /// completions against the catalog for the "most skipped category"
  /// insight.
  final List<Exercise> allExercises;

  @override
  State<InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends State<InsightsTab>
    with AutomaticKeepAliveClientMixin<InsightsTab> {
  // See ThisWeekTab's identical override for why: preserves scroll
  // position across tab swipes instead of rebuilding from scratch.
  @override
  bool get wantKeepAlive => true;

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // ---------------------------------------------------------------
  // Insight 1: Most Consistent Day
  // ---------------------------------------------------------------
  //
  // The completion history only records which calendar day an
  // exercise was completed on, not a time of day, so "best workout
  // time" is computed as the day of the week the user shows up on
  // most often — the most honest reading of "best time" the local
  // data actually supports.
  _DayInsight _computeBestDay(ExerciseCompletionService completion) {
    final today = _dateOnly(DateTime.now());
    final activeCountByWeekday = List<int>.filled(7, 0); // index 0 = Monday
    final totalCountByWeekday = List<int>.filled(7, 0);

    for (var i = 0; i < _lookbackDays; i++) {
      final day = today.subtract(Duration(days: i));
      final weekdayIndex = day.weekday - 1;
      totalCountByWeekday[weekdayIndex]++;
      if (completion.hasActivityOn(day)) {
        activeCountByWeekday[weekdayIndex]++;
      }
    }

    final totalActiveDays = activeCountByWeekday.fold(0, (a, b) => a + b);
    if (totalActiveDays == 0) {
      return const _DayInsight.empty();
    }

    var bestWeekday = 0;
    for (var i = 1; i < 7; i++) {
      if (activeCountByWeekday[i] > activeCountByWeekday[bestWeekday]) {
        bestWeekday = i;
      }
    }

    // A tie at zero (nothing beat index 0 because everything's equal
    // and low) still needs at least one active day on that weekday to
    // be worth reporting.
    if (activeCountByWeekday[bestWeekday] == 0) {
      return const _DayInsight.empty();
    }

    return _DayInsight(
      weekdayName: _weekdayNames[bestWeekday],
      activeCount: activeCountByWeekday[bestWeekday],
      totalCount: totalCountByWeekday[bestWeekday],
      isEmerging: totalActiveDays < _emergingThreshold,
    );
  }

  static const List<String> _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  // ---------------------------------------------------------------
  // Insight 2: Most Skipped Category
  // ---------------------------------------------------------------
  //
  // The app doesn't record exercises that were shown but not done,
  // so "skipped" is read relative to the catalog: each category's
  // share of completions is compared against its share of the
  // catalog. A category that makes up, say, 1/6 of the catalog but
  // only 1/20 of completions is the one being passed over most,
  // regardless of how many exercises happen to exist in it.
  _CategoryInsight _computeMostSkippedCategory(
    ExerciseCompletionService completion,
  ) {
    if (widget.allExercises.isEmpty) {
      return const _CategoryInsight.empty();
    }

    final catalogById = {for (final e in widget.allExercises) e.id: e};
    final today = _dateOnly(DateTime.now());

    final catalogCountByCategory = <ExerciseCategory, int>{};
    for (final exercise in widget.allExercises) {
      catalogCountByCategory.update(
        exercise.category,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final completionCountByCategory = <ExerciseCategory, int>{};
    var totalCompletions = 0;
    for (var i = 0; i < _lookbackDays; i++) {
      final day = today.subtract(Duration(days: i));
      for (final id in completion.idsCompletedOn(day)) {
        final exercise = catalogById[id];
        if (exercise == null) continue;
        completionCountByCategory.update(
          exercise.category,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        totalCompletions++;
      }
    }

    if (totalCompletions == 0) {
      return const _CategoryInsight.empty();
    }

    // For each category, compare its share of completions against its
    // share of the catalog. The category with the lowest ratio is the
    // most under-represented relative to how available it is.
    ExerciseCategory? mostSkipped;
    double lowestRatio = double.infinity;
    for (final category in ExerciseCategory.values) {
      final catalogCount = catalogCountByCategory[category] ?? 0;
      if (catalogCount == 0) continue;
      final catalogShare = catalogCount / widget.allExercises.length;
      final completedCount = completionCountByCategory[category] ?? 0;
      final completedShare = completedCount / totalCompletions;
      final ratio = completedShare / catalogShare;
      if (ratio < lowestRatio) {
        lowestRatio = ratio;
        mostSkipped = category;
      }
    }

    if (mostSkipped == null) {
      return const _CategoryInsight.empty();
    }

    final completedCount = completionCountByCategory[mostSkipped] ?? 0;
    return _CategoryInsight(
      category: mostSkipped,
      completedCount: completedCount,
      totalCompletions: totalCompletions,
      isEmerging: totalCompletions < _emergingThreshold,
    );
  }

  // ---------------------------------------------------------------
  // Insight 3: Hydration Consistency
  // ---------------------------------------------------------------
  _HydrationInsight _computeHydrationConsistency(HydrationService hydration) {
    final today = _dateOnly(DateTime.now());
    var loggedDays = 0;
    var goalDays = 0;

    for (var i = 0; i < _lookbackDays; i++) {
      final day = today.subtract(Duration(days: i));
      if (hydration.intakeOn(day) > 0) loggedDays++;
      if (hydration.goalReachedOn(day)) goalDays++;
    }

    if (loggedDays == 0) {
      return const _HydrationInsight.empty();
    }

    return _HydrationInsight(
      goalDays: goalDays,
      loggedDays: loggedDays,
      windowDays: _lookbackDays,
      isEmerging: loggedDays < _emergingThreshold,
    );
  }

  // ---------------------------------------------------------------
  // Insight 4: Average Daily Activity
  // ---------------------------------------------------------------
  _ActivityInsight _computeAverageDailyActivity(
    ExerciseCompletionService completion,
  ) {
    final catalogById = {for (final e in widget.allExercises) e.id: e};
    final today = _dateOnly(DateTime.now());

    var activeDays = 0;
    var totalExercises = 0;
    var totalMinutes = 0;

    for (var i = 0; i < _lookbackDays; i++) {
      final day = today.subtract(Duration(days: i));
      final ids = completion.idsCompletedOn(day);
      if (ids.isEmpty) continue;
      activeDays++;
      totalExercises += ids.length;
      for (final id in ids) {
        final exercise = catalogById[id];
        if (exercise != null) totalMinutes += exercise.duration.inMinutes;
      }
    }

    if (activeDays == 0) {
      return const _ActivityInsight.empty();
    }

    return _ActivityInsight(
      averageExercises: totalExercises / activeDays,
      averageMinutes: totalMinutes / activeDays,
      activeDays: activeDays,
      windowDays: _lookbackDays,
      isEmerging: activeDays < _emergingThreshold,
    );
  }

  // ---------------------------------------------------------------
  // Insight 5: Weekly Improvement
  // ---------------------------------------------------------------
  _WeeklyImprovementInsight _computeWeeklyImprovement(
    ExerciseCompletionService completion,
  ) {
    final catalogById = {for (final e in widget.allExercises) e.id: e};
    final today = _dateOnly(DateTime.now());
    // Compare the trailing 7 days (including today) against the 7
    // days before that, rather than calendar Mon–Sun weeks, so the
    // comparison is meaningful on any day of the week rather than
    // only reading well right before a Sunday.
    final thisWeekStart = today.subtract(const Duration(days: 6));
    final lastWeekStart = today.subtract(const Duration(days: 13));
    final lastWeekEnd = today.subtract(const Duration(days: 7));

    ({int activeDays, int minutes}) summarize(DateTime start, DateTime end) {
      var activeDays = 0;
      var minutes = 0;
      for (
        var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))
      ) {
        final ids = completion.idsCompletedOn(day);
        if (ids.isEmpty) continue;
        activeDays++;
        for (final id in ids) {
          final exercise = catalogById[id];
          if (exercise != null) minutes += exercise.duration.inMinutes;
        }
      }
      return (activeDays: activeDays, minutes: minutes);
    }

    final thisWeek = summarize(thisWeekStart, today);
    final lastWeek = summarize(lastWeekStart, lastWeekEnd);

    if (thisWeek.activeDays == 0 && lastWeek.activeDays == 0) {
      return const _WeeklyImprovementInsight.empty();
    }

    return _WeeklyImprovementInsight(
      thisWeekMinutes: thisWeek.minutes,
      lastWeekMinutes: lastWeek.minutes,
      thisWeekActiveDays: thisWeek.activeDays,
      lastWeekActiveDays: lastWeek.activeDays,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin.
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final completion = CompletionScope.of(context);
    final hydration = HydrationScope.of(context);
    final premium = PremiumScope.of(context);
    final hasAdvancedInsights =
        premium.isUnlocked(PremiumFeature.advancedInsights);

    final bestDay = _computeBestDay(completion);
    final skippedCategory = _computeMostSkippedCategory(completion);
    final hydrationConsistency = _computeHydrationConsistency(hydration);
    final averageActivity = _computeAverageDailyActivity(completion);
    final weeklyImprovement = _computeWeeklyImprovement(completion);

    final cards = <Widget>[
      bestDay.isEmpty
          ? const InsightEmptyCard(
              icon: Icons.event_available,
              title: 'Most Consistent Day',
              message:
                  'Complete a few exercises on different days and this page '
                  'will tell you which day of the week you show up on most.',
            )
          : InsightCard(
              icon: Icons.event_available,
              title: 'Most Consistent Day',
              headline: bestDay.weekdayName,
              detail: "You've completed exercises on ${bestDay.activeCount} "
                  'of your last ${bestDay.totalCount} '
                  '${bestDay.weekdayName}s — your most consistent day of '
                  'the week.',
              confidence: bestDay.isEmerging
                  ? InsightConfidence.emerging
                  : InsightConfidence.established,
              color: colorScheme.primary,
            ),
      skippedCategory.isEmpty
          ? const InsightEmptyCard(
              icon: Icons.filter_alt_off,
              title: 'Most Skipped Category',
              message:
                  'Once you complete a few exercises across different '
                  'categories, this page will surface the one you tend to '
                  'skip most.',
            )
          : InsightCard(
              icon: Icons.filter_alt_off,
              title: 'Most Skipped Category',
              headline: skippedCategory.category!.label,
              detail: 'Only ${skippedCategory.completedCount} of your last '
                  '${skippedCategory.totalCompletions} completed exercises '
                  "were ${skippedCategory.category!.label} — it's the "
                  'category you complete least relative to how often it '
                  'appears in the catalog.',
              confidence: skippedCategory.isEmerging
                  ? InsightConfidence.emerging
                  : InsightConfidence.established,
              color: const Color(0xFFE08A2C),
            ),
    ];

    final advancedCards = <Widget>[
      hydrationConsistency.isEmpty
          ? const InsightEmptyCard(
              icon: Icons.water_drop,
              title: 'Hydration Consistency',
              message:
                  'Log some water intake and this page will show how often '
                  'you hit your daily hydration goal.',
            )
          : InsightCard(
              icon: Icons.water_drop,
              title: 'Hydration Consistency',
              headline: '${hydrationConsistency.goalPercent}%',
              detail: 'You reached your hydration goal on '
                  '${hydrationConsistency.goalDays} of the last '
                  '${hydrationConsistency.windowDays} days, and logged '
                  'water on ${hydrationConsistency.loggedDays} of them.',
              confidence: hydrationConsistency.isEmerging
                  ? InsightConfidence.emerging
                  : InsightConfidence.established,
              color: const Color(0xFF2196C4),
            ),
      averageActivity.isEmpty
          ? const InsightEmptyCard(
              icon: Icons.bar_chart,
              title: 'Average Daily Activity',
              message:
                  'Complete a few exercises and this page will show your '
                  'typical daily activity level.',
            )
          : InsightCard(
              icon: Icons.bar_chart,
              title: 'Average Daily Activity',
              headline:
                  '${averageActivity.averageMinutesLabel} min',
              detail: 'On days you exercise, you complete '
                  '${averageActivity.averageExercisesLabel} exercises on '
                  'average — active on ${averageActivity.activeDays} of the '
                  'last ${averageActivity.windowDays} days.',
              confidence: averageActivity.isEmerging
                  ? InsightConfidence.emerging
                  : InsightConfidence.established,
              color: const Color(0xFF6C4CD8),
            ),
      weeklyImprovement.isEmpty
          ? const InsightEmptyCard(
              icon: Icons.trending_up,
              title: 'Weekly Improvement',
              message:
                  'Once you have a week or two of activity, this page will '
                  'compare your recent weeks to show if you\'re trending up.',
            )
          : InsightCard(
              icon: Icons.trending_up,
              title: 'Weekly Improvement',
              headline: weeklyImprovement.minutesDeltaLabel,
              detail: '${weeklyImprovement.thisWeekMinutes} min across '
                  '${weeklyImprovement.thisWeekActiveDays} active days this '
                  'week, versus ${weeklyImprovement.lastWeekMinutes} min '
                  'across ${weeklyImprovement.lastWeekActiveDays} active '
                  'days last week.',
              trend: weeklyImprovement.trend,
              color: weeklyImprovement.trend.direction ==
                      InsightTrendDirection.down
                  ? colorScheme.error
                  : const Color(0xFF2E7D32),
            ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const SectionHeader(
              size: SectionHeaderSize.large,
              subtitle: 'Your Insights',
              title: 'What your habits say 💡',
            ),
            const SizedBox(height: 6),
            Text(
              'Generated from your last $_lookbackDays days of local '
              'activity — nothing here is sent anywhere.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < cards.length; i++) ...[
              StaggeredEntrance(index: i, child: cards[i]),
              const SizedBox(height: 14),
            ],
            StaggeredEntrance(
              index: cards.length,
              child: hasAdvancedInsights
                  ? const SizedBox.shrink()
                  : const UpgradeCard(
                      feature: PremiumFeature.advancedInsights,
                      title: 'Unlock deeper insights',
                      message:
                          'See your hydration consistency, average '
                          'daily activity, and week-over-week trend.',
                    ),
            ),
            if (hasAdvancedInsights)
              for (var i = 0; i < advancedCards.length; i++) ...[
                const SizedBox(height: 14),
                StaggeredEntrance(
                  index: cards.length + 1 + i,
                  child: advancedCards[i],
                ),
              ],
          ],
        ),
      ),
    );
  }
}

/// Result of [_InsightsTabState._computeBestDay].
class _DayInsight {
  const _DayInsight({
    required this.weekdayName,
    required this.activeCount,
    required this.totalCount,
    required this.isEmerging,
  }) : isEmpty = false;

  const _DayInsight.empty()
      : weekdayName = '',
        activeCount = 0,
        totalCount = 0,
        isEmerging = false,
        isEmpty = true;

  final String weekdayName;
  final int activeCount;
  final int totalCount;
  final bool isEmerging;
  final bool isEmpty;
}

/// Result of [_InsightsTabState._computeMostSkippedCategory].
class _CategoryInsight {
  const _CategoryInsight({
    required this.category,
    required this.completedCount,
    required this.totalCompletions,
    required this.isEmerging,
  }) : isEmpty = false;

  const _CategoryInsight.empty()
      : category = null,
        completedCount = 0,
        totalCompletions = 0,
        isEmerging = false,
        isEmpty = true;

  final ExerciseCategory? category;
  final int completedCount;
  final int totalCompletions;
  final bool isEmerging;
  final bool isEmpty;
}

/// Result of [_InsightsTabState._computeHydrationConsistency].
class _HydrationInsight {
  const _HydrationInsight({
    required this.goalDays,
    required this.loggedDays,
    required this.windowDays,
    required this.isEmerging,
  }) : isEmpty = false;

  const _HydrationInsight.empty()
      : goalDays = 0,
        loggedDays = 0,
        windowDays = 0,
        isEmerging = false,
        isEmpty = true;

  final int goalDays;
  final int loggedDays;
  final int windowDays;
  final bool isEmerging;
  final bool isEmpty;

  int get goalPercent =>
      windowDays == 0 ? 0 : ((goalDays / windowDays) * 100).round();
}

/// Result of [_InsightsTabState._computeAverageDailyActivity].
class _ActivityInsight {
  const _ActivityInsight({
    required this.averageExercises,
    required this.averageMinutes,
    required this.activeDays,
    required this.windowDays,
    required this.isEmerging,
  }) : isEmpty = false;

  const _ActivityInsight.empty()
      : averageExercises = 0,
        averageMinutes = 0,
        activeDays = 0,
        windowDays = 0,
        isEmerging = false,
        isEmpty = true;

  final double averageExercises;
  final double averageMinutes;
  final int activeDays;
  final int windowDays;
  final bool isEmerging;
  final bool isEmpty;

  String get averageExercisesLabel => averageExercises.toStringAsFixed(1);
  String get averageMinutesLabel => averageMinutes.toStringAsFixed(0);
}

/// Result of [_InsightsTabState._computeWeeklyImprovement].
class _WeeklyImprovementInsight {
  const _WeeklyImprovementInsight({
    required this.thisWeekMinutes,
    required this.lastWeekMinutes,
    required this.thisWeekActiveDays,
    required this.lastWeekActiveDays,
  }) : isEmpty = false;

  const _WeeklyImprovementInsight.empty()
      : thisWeekMinutes = 0,
        lastWeekMinutes = 0,
        thisWeekActiveDays = 0,
        lastWeekActiveDays = 0,
        isEmpty = true;

  final int thisWeekMinutes;
  final int lastWeekMinutes;
  final int thisWeekActiveDays;
  final int lastWeekActiveDays;
  final bool isEmpty;

  int get _minutesDelta => thisWeekMinutes - lastWeekMinutes;

  String get minutesDeltaLabel {
    final delta = _minutesDelta;
    if (delta == 0) return 'No change';
    final sign = delta > 0 ? '+' : '';
    return '$sign$delta min';
  }

  InsightTrend get trend {
    final delta = _minutesDelta;
    if (lastWeekMinutes == 0) {
      // No baseline to compare against — describe the change in
      // absolute minutes rather than an undefined percentage.
      if (delta == 0) return const InsightTrend.flat('No change');
      return InsightTrend(
        direction: InsightTrendDirection.up,
        label: '+$thisWeekMinutes min',
      );
    }
    final percent = ((delta / lastWeekMinutes) * 100).round();
    if (percent == 0) return const InsightTrend.flat('No change');
    final sign = percent > 0 ? '+' : '';
    return InsightTrend(
      direction:
          percent > 0 ? InsightTrendDirection.up : InsightTrendDirection.down,
      label: '$sign$percent%',
    );
  }
}
