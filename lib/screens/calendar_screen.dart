import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../services/app_notifications.dart';
import '../services/completion_scope.dart';
import '../services/exercise_repository.dart';
import '../services/hydration_scope.dart';
import '../services/reminder_settings_scope.dart';
import '../services/skincare_scope.dart';
import '../services/skincare_service.dart';
import '../services/wellness_score_scope.dart';
import '../widgets/calendar/day_summary_panel.dart';
import '../widgets/progress/month_calendar_grid.dart';
import '../widgets/shared/section_header.dart';

/// Width at which the grid and detail panel move from stacked to
/// side-by-side.
const double _wideBreakpoint = 800;

/// Calendar page.
///
/// Lets the user browse any past month and pick a day to see exactly
/// what was tracked on it: completed routines, hydration, skincare
/// checklists, posture check-ins, and that day's overall wellness
/// score. Every figure is derived live from the same locally-stored
/// services the rest of the app reads and writes — [CompletionScope],
/// [HydrationScope], [SkincareScope], [ReminderSettingsScope], and
/// [WellnessScoreScope] — so nothing shown here can drift out of sync
/// with what's recorded elsewhere in the app, and there's no separate
/// "calendar" data store.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const ExerciseRepository _repository = ExerciseRepository();

  List<Exercise> _allExercises = const [];

  late DateTime _displayedMonth;
  late DateTime _selectedDate;
  late final DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = _dateOnly(DateTime.now());
    _displayedMonth = DateTime(_today.year, _today.month, 1);
    _selectedDate = _today;
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    try {
      final exercises = await _repository.loadExercises();
      if (!mounted) return;
      setState(() => _allExercises = exercises);
    } catch (_) {
      // Swallow load errors here, matching the Progress and
      // Statistics screens: the Exercises tab already surfaces a
      // proper error state with retry, so this page just stays at
      // zero/empty rather than duplicating that handling.
    }
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool get _isDisplayingCurrentMonth =>
      _displayedMonth.year == _today.year &&
      _displayedMonth.month == _today.month;

  void _goToPreviousMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
        1,
      );
    });
  }

  void _goToNextMonth() {
    if (_isDisplayingCurrentMonth) return;
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
        1,
      );
    });
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
  }

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];

  /// Builds one [CalendarDayData] per day in the displayed month,
  /// classifying each day's overall activity level from completion,
  /// hydration, and skincare state (matching how [StreakService]
  /// defines an "overall wellness" day, but graded into none/
  /// partial/full for the grid instead of a strict boolean), plus
  /// that day's wellness score for the small in-cell label.
  List<CalendarDayData> _computeMonthData(BuildContext context) {
    final completion = CompletionScope.of(context);
    final hydration = HydrationScope.of(context);
    final skincare = SkincareScope.of(context);
    final wellness = WellnessScoreScope.of(context);

    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;

    return List<CalendarDayData>.generate(daysInMonth, (i) {
      final date = DateTime(_displayedMonth.year, _displayedMonth.month, i + 1);
      if (date.isAfter(_today)) {
        return CalendarDayData(date: date, level: CalendarDayLevel.none);
      }

      final hasWorkout = completion.hasActivityOn(date);
      final hasHydration = hydration.goalReachedOn(date);
      final hasSkincare = skincare.isDayComplete(date);
      final trackedCount =
          (hasWorkout ? 1 : 0) + (hasHydration ? 1 : 0) + (hasSkincare ? 1 : 0);

      final level = trackedCount == 0
          ? CalendarDayLevel.none
          : trackedCount == 3
              ? CalendarDayLevel.full
              : CalendarDayLevel.partial;

      return CalendarDayData(
        date: date,
        level: level,
        wellnessScore: wellness.snapshotFor(date).score,
      );
    });
  }

  /// Assembles the full [DaySummary] for [_selectedDate] from every
  /// relevant service.
  DaySummary _computeDaySummary(BuildContext context) {
    final completion = CompletionScope.of(context);
    final hydration = HydrationScope.of(context);
    final skincare = SkincareScope.of(context);
    final reminders = ReminderSettingsScope.of(context);
    final wellness = WellnessScoreScope.of(context);

    final catalogById = {
      for (final exercise in _allExercises) exercise.id: exercise,
    };
    final completedExercises = completion
        .idsCompletedOn(_selectedDate)
        .where(catalogById.containsKey)
        .map((id) => catalogById[id]!)
        .toList(growable: false);

    List<(SkincareStep step, bool completed)> stepsFor(
      SkincareRoutine routine,
    ) {
      return [
        for (final step in skincare.stepsFor(routine))
          (step, skincare.isStepCompleted(step, routine, _selectedDate)),
      ];
    }

    return DaySummary(
      date: _selectedDate,
      completedExercises: completedExercises,
      hydrationMl: hydration.intakeOn(_selectedDate),
      hydrationGoalMl: hydration.goalMl,
      morningSteps: stepsFor(SkincareRoutine.morning),
      nightSteps: stepsFor(SkincareRoutine.night),
      postureEvents: reminders.historyFor(ReminderKind.posture, _selectedDate),
      wellnessSnapshot: wellness.snapshotFor(_selectedDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final monthData = _computeMonthData(context);
    final daySummary = _computeDaySummary(context);

    final grid = MonthCalendarGrid(
      month: _displayedMonth,
      days: monthData,
      today: _today,
      selectedDate: _selectedDate,
      onDaySelected: _selectDate,
    );

    final detailPanel = DaySummaryPanel(summary: daySummary);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        centerTitle: false,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.4],
            colors: [
              Color.lerp(colorScheme.surface, colorScheme.primary, 0.05)!,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= _wideBreakpoint;
              final horizontalPadding = isWide ? 32.0 : 20.0;

              final header = SectionHeader(
                size: SectionHeaderSize.large,
                subtitle: 'Your History',
                title: 'Browse any day 🗓️',
              );

              final monthNav = Row(
                children: [
                  IconButton(
                    onPressed: _goToPreviousMonth,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous month',
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_monthNames[_displayedMonth.month - 1]} '
                        '${_displayedMonth.year}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isDisplayingCurrentMonth ? null : _goToNextMonth,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next month',
                  ),
                ],
              );

              final content = isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [monthNav, const SizedBox(height: 8), grid],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(child: detailPanel),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        monthNav,
                        const SizedBox(height: 8),
                        grid,
                        const SizedBox(height: 20),
                        detailPanel,
                      ],
                    );

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
                    children: [
                      header,
                      const SizedBox(height: 24),
                      content,
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
