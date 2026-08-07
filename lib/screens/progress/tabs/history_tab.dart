import 'package:flutter/material.dart';

import '../../../services/completion_scope.dart';
import '../../../services/streak_scope.dart';
import '../../../services/streak_service.dart';
import '../../../services/wellness_score_scope.dart';
import '../../../widgets/progress/bar_chart_card.dart';
import '../../../widgets/progress/line_chart_card.dart';
import '../../../widgets/shared/section_header.dart';

/// Width at which the chart pairs move from stacked to side-by-side.
const double _wideBreakpoint = 700;

/// "History" tab of the Progress destination — the longer view.
///
/// Covers, in order: wellness score history (last 14 days), active
/// days per week (last 6 weeks), and monthly consistency (last 6
/// months) — each a strictly longer look-back than anything shown in
/// [ThisWeekTab], so the two tabs never show the same window of time
/// twice. Deliberately has no stats grid of its own: current/best
/// streak figures are "right now" information and live in
/// [ThisWeekTab]'s stats grid instead; this tab's "Active Days per
/// Week" chart is the historical trend those same streaks are built
/// from, extended out to 6 weeks.
///
/// Every figure is derived live from the same locally-stored services
/// the rest of the app already reads and writes — [CompletionScope],
/// [StreakScope], and [WellnessScoreScope] — so there is no separate
/// "history" data store and nothing here can drift out of sync with
/// what's shown elsewhere in the app. Unlike [ThisWeekTab] and
/// [InsightsTab], none of this tab's figures depend on exercise
/// duration or category, so it doesn't need the loaded exercise
/// catalog at all.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab>
    with AutomaticKeepAliveClientMixin<HistoryTab> {
  // See ThisWeekTab's identical override for why: preserves scroll
  // position across tab swipes instead of rebuilding from scratch.
  @override
  bool get wantKeepAlive => true;

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _monthAbbrev(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    // Handle month values that rolled outside 1..12 from date math.
    final normalized = ((month - 1) % 12 + 12) % 12;
    return names[normalized];
  }

  /// Gathers every figure this tab shows, computed fresh from the
  /// app's shared services.
  _HistorySummary _computeSummary(BuildContext context) {
    final completion = CompletionScope.of(context);
    final streakService = StreakScope.of(context);
    final wellness = WellnessScoreScope.of(context);

    final today = _dateOnly(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));

    // --- Monthly consistency (last 6 calendar months) ---
    final monthLabels = <String>[];
    final monthlyConsistency = <double>[];
    for (var i = 5; i >= 0; i--) {
      final monthDate = DateTime(today.year, today.month - i, 1);
      final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
      final lastDay = DateTime(monthDate.year, monthDate.month, daysInMonth);
      final endDay = lastDay.isAfter(today) ? today : lastDay;

      var activeDays = 0;
      var countedDays = 0;
      for (
        var day = DateTime(monthDate.year, monthDate.month, 1);
        !day.isAfter(endDay);
        day = day.add(const Duration(days: 1))
      ) {
        countedDays++;
        if (completion.hasActivityOn(day)) activeDays++;
      }

      monthLabels.add(_monthAbbrev(monthDate.month));
      monthlyConsistency.add(
        countedDays == 0 ? 0.0 : (activeDays / countedDays) * 100,
      );
    }

    // --- Wellness score history (last 14 days) ---
    final wellnessLabels = <String>[];
    final wellnessHistory = <double>[];
    for (var i = 13; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      wellnessHistory.add(wellness.snapshotFor(day).score.toDouble());
      wellnessLabels.add(i == 0 ? 'Today' : '${day.day}');
    }
    // Thin labels down for readability: keep every other one plus today.
    final thinnedWellnessLabels = [
      for (var i = 0; i < wellnessLabels.length; i++)
        (i == wellnessLabels.length - 1 || i.isEven) ? wellnessLabels[i] : '',
    ];

    // --- Active days per week (last 6 weeks) ---
    final streakWeekLabels = <String>[];
    final streakActiveDaysPerWeek = <double>[];
    for (var i = 5; i >= 0; i--) {
      final weekStart = monday.subtract(Duration(days: 7 * i));
      var activeDays = 0;
      for (var d = 0; d < 7; d++) {
        final day = weekStart.add(Duration(days: d));
        if (day.isAfter(today)) break;
        if (streakService.infoFor(StreakKind.overall, asOf: day).activeToday) {
          activeDays++;
        }
      }
      streakActiveDaysPerWeek.add(activeDays.toDouble());
      streakWeekLabels.add(i == 0 ? 'This wk' : '-${i}w');
    }

    return _HistorySummary(
      monthLabels: monthLabels,
      monthlyConsistency: monthlyConsistency,
      wellnessLabels: thinnedWellnessLabels,
      wellnessHistory: wellnessHistory,
      streakWeekLabels: streakWeekLabels,
      streakActiveDaysPerWeek: streakActiveDaysPerWeek,
    );
  }

  List<Widget> _buildSections(_HistorySummary summary, bool isWide) {
    const header = SectionHeader(
      size: SectionHeaderSize.large,
      subtitle: 'Your History',
      title: 'The bigger picture 📊',
    );

    final wellnessChart = LineChartCard(
      title: 'Wellness Score History',
      subtitle: 'Last 14 days',
      values: summary.wellnessHistory,
      labels: summary.wellnessLabels,
    );

    final activeDaysChart = BarChartCard(
      title: 'Active Days per Week',
      subtitle: 'Overall wellness days, last 6 weeks',
      values: summary.streakActiveDaysPerWeek,
      labels: summary.streakWeekLabels,
      valueSuffix: ' d',
    );

    final consistencyChart = LineChartCard(
      title: 'Monthly Consistency',
      subtitle: '% of days active, last 6 months',
      values: summary.monthlyConsistency,
      labels: summary.monthLabels,
    );

    // Each entry pairs a section with the space to leave after it.
    final List<({Widget child, double gap})> items;
    if (isWide) {
      items = [
        (child: header, gap: 28),
        (
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: wellnessChart),
              const SizedBox(width: 16),
              Expanded(child: activeDaysChart),
            ],
          ),
          gap: 16,
        ),
        (child: consistencyChart, gap: 0),
      ];
    } else {
      items = [
        (child: header, gap: 24),
        (child: wellnessChart, gap: 16),
        (child: activeDaysChart, gap: 16),
        (child: consistencyChart, gap: 0),
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

/// Bundles every figure [HistoryTab] shows, computed once per build
/// by [_HistoryTabState._computeSummary] from the app's shared
/// services.
class _HistorySummary {
  const _HistorySummary({
    required this.monthLabels,
    required this.monthlyConsistency,
    required this.wellnessLabels,
    required this.wellnessHistory,
    required this.streakWeekLabels,
    required this.streakActiveDaysPerWeek,
  });

  /// Month abbreviations for [monthlyConsistency], oldest first.
  final List<String> monthLabels;

  /// Percentage of days with at least one completed exercise, one
  /// entry per of the last 6 calendar months, oldest first.
  final List<double> monthlyConsistency;

  /// Sparse day-of-month labels for [wellnessHistory] (every other
  /// day, plus today).
  final List<String> wellnessLabels;

  /// Wellness score (0–100) for each of the last 14 days, oldest
  /// first.
  final List<double> wellnessHistory;

  /// Week labels for [streakActiveDaysPerWeek], oldest first.
  final List<String> streakWeekLabels;

  /// Number of "overall wellness" active days in each of the last 6
  /// weeks, oldest first.
  final List<double> streakActiveDaysPerWeek;
}
