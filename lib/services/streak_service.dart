import 'package:flutter/foundation.dart';

import 'exercise_completion_service.dart';
import 'hydration_service.dart';
import 'rest_day_service.dart';
import 'skincare_service.dart';

/// Which single habit a streak is tracking. [overall] is special: it
/// only counts a day once every other kind was hit that same day.
enum StreakKind { workout, hydration, skincare, overall }

/// A computed streak snapshot for one [StreakKind]: how many
/// consecutive days (ending today or yesterday) the habit was kept,
/// and the longest such run ever recorded.
class StreakInfo {
  const StreakInfo({
    required this.kind,
    required this.currentStreak,
    required this.longestStreak,
    required this.activeToday,
    this.isRestDayToday = false,
  });

  final StreakKind kind;

  /// Consecutive days, ending today (or yesterday if today isn't done
  /// yet), that this habit was completed.
  final int currentStreak;

  /// The longest such run found anywhere in recorded history.
  final int longestStreak;

  /// Whether today itself already counts as a completed day for this
  /// habit — i.e. whether the streak is "locked in" for today already
  /// or still depends on the user doing something before midnight.
  final bool activeToday;

  /// Whether today is a scheduled rest day (see [RestDayService]).
  /// Only meaningful for [StreakKind.workout] and [StreakKind.overall]
  /// — the two kinds a rest day can keep [activeToday] `true` for
  /// without any exercise actually being completed — so UI can show
  /// "Resting today" instead of implying the user still needs to work
  /// out to keep the streak alive.
  final bool isRestDayToday;
}

/// Derives the user's daily-habit streaks — workout, hydration,
/// skincare, and a combined "overall wellness" streak — from the
/// three services that already persist per-day completion data.
///
/// This is intentionally a pure read-through layer rather than its
/// own persisted store: [ExerciseCompletionService], [HydrationService],
/// and [SkincareService] already record, per calendar day, whether
/// each habit was done. Recomputing streaks from that history on
/// every call means there's nothing to keep in sync and streaks
/// "update" automatically the instant any of those services changes
/// or a new day begins — there's no separate daily rollover job that
/// could drift out of sync with the underlying data.
///
/// A [ChangeNotifier] so screens can listen for streak changes
/// directly, but in practice a screen that already listens to
/// [CompletionScope], [HydrationScope], and [SkincareScope] (e.g. via
/// `context.dependOnInheritedWidgetOfExactType`) will already rebuild
/// whenever the underlying data — and therefore any streak computed
/// from it — changes. [StreakService] re-broadcasts those same
/// changes so a widget only needs to depend on [StreakScope] to stay
/// current, without also depending on all three source scopes.
class StreakService extends ChangeNotifier {
  StreakService({
    required ExerciseCompletionService completion,
    required HydrationService hydration,
    required SkincareService skincare,
    RestDayService? restDays,
  }) : _completion = completion,
       _hydration = hydration,
       _skincare = skincare,
       _restDays = restDays {
    _completion.addListener(_onSourceChanged);
    _hydration.addListener(_onSourceChanged);
    _skincare.addListener(_onSourceChanged);
    _restDays?.addListener(_onSourceChanged);
  }

  final ExerciseCompletionService _completion;
  final HydrationService _hydration;
  final SkincareService _skincare;

  /// Optional: when provided, a scheduled rest day pauses workout
  /// (and therefore overall-wellness) streak loss on that day — see
  /// [_wasActiveOn]. Nullable so existing callers/tests that don't
  /// care about rest days can keep constructing [StreakService]
  /// without one; when omitted, streaks behave exactly as before.
  final RestDayService? _restDays;

  void _onSourceChanged() => notifyListeners();

  @override
  void dispose() {
    _completion.removeListener(_onSourceChanged);
    _hydration.removeListener(_onSourceChanged);
    _skincare.removeListener(_onSourceChanged);
    _restDays?.removeListener(_onSourceChanged);
    super.dispose();
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Whether [kind]'s habit counts as done on [date]. This is the one
  /// place that knows how each streak's "day counts" rule maps onto
  /// the underlying services, so every streak calculation below stays
  /// in lockstep by construction.
  ///
  /// A scheduled rest day (see [RestDayService]) counts as "done" for
  /// the workout streak specifically, even with no completed
  /// exercise — that's the whole point of scheduling one: it pauses
  /// workout-streak loss instead of resetting the streak to zero.
  /// Hydration and skincare are deliberately excluded from that
  /// exception, since a rest day is a break from exercise, not from
  /// hydration or skincare tracking; those two keep requiring the
  /// same daily activity as always. Because [StreakKind.overall]
  /// requires all three underlying habits, a rest day still needs
  /// hydration and skincare to be done for the *overall* streak to
  /// hold — it only forgives the workout half of that requirement.
  bool _wasActiveOn(StreakKind kind, DateTime date) {
    switch (kind) {
      case StreakKind.workout:
        return _completion.hasActivityOn(date) ||
            (_restDays?.isRestDay(date) ?? false);
      case StreakKind.hydration:
        return _hydration.goalReachedOn(date);
      case StreakKind.skincare:
        return _skincare.isDayComplete(date);
      case StreakKind.overall:
        return _wasActiveOn(StreakKind.workout, date) &&
            _wasActiveOn(StreakKind.hydration, date) &&
            _wasActiveOn(StreakKind.skincare, date);
    }
  }

  /// The current consecutive-day streak for [kind], ending today.
  ///
  /// If [kind]'s habit hasn't been done yet today, today doesn't
  /// break the streak by itself — the count starts from yesterday
  /// instead, so a streak only resets once a full day passes with
  /// nothing logged (rather than the instant the clock ticks past
  /// midnight, which would be needlessly punishing for something the
  /// user just hasn't gotten to yet today).
  int currentStreak(StreakKind kind, {DateTime? asOf}) {
    var cursor = _dateOnly(asOf ?? DateTime.now());
    if (!_wasActiveOn(kind, cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (_wasActiveOn(kind, cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// The longest run of consecutive active days for [kind] found
  /// anywhere in the combined history of the underlying services
  /// (including the current streak, if that happens to be longest).
  ///
  /// Scans every day between the earliest recorded activity across
  /// all three source services and today, since [StreakKind.overall]
  /// needs to check all three on each day regardless of which
  /// service(s) have data for it.
  int longestStreak(StreakKind kind, {DateTime? asOf}) {
    final earliest = _earliestRecordedDay();
    final today = _dateOnly(asOf ?? DateTime.now());
    if (earliest == null) return 0;

    var longest = 0;
    var current = 0;
    for (
      var day = earliest;
      !day.isAfter(today);
      day = day.add(const Duration(days: 1))
    ) {
      if (_wasActiveOn(kind, day)) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }
    return longest;
  }

  /// The earliest calendar day with any recorded activity across
  /// workout completions, hydration logs, or skincare check-offs —
  /// i.e. the earliest day worth scanning forward from for
  /// [longestStreak]. Returns `null` if nothing has ever been logged.
  DateTime? _earliestRecordedDay() {
    DateTime? earliest;
    void consider(DateTime? day) {
      if (day == null) return;
      if (earliest == null || day.isBefore(earliest!)) earliest = day;
    }

    consider(_completion.earliestActivityDay);
    consider(_hydration.earliestLoggedDay);
    consider(_skincare.earliestCompletedDay);
    return earliest;
  }

  /// A full [StreakInfo] snapshot for [kind]: current streak, longest
  /// streak, and whether today already counts.
  StreakInfo infoFor(StreakKind kind, {DateTime? asOf}) {
    final today = _dateOnly(asOf ?? DateTime.now());
    final restToday = _restDays?.isRestDay(today) ?? false;
    return StreakInfo(
      kind: kind,
      currentStreak: currentStreak(kind, asOf: today),
      longestStreak: longestStreak(kind, asOf: today),
      activeToday: _wasActiveOn(kind, today),
      isRestDayToday:
          restToday &&
          (kind == StreakKind.workout || kind == StreakKind.overall),
    );
  }

  /// Snapshots for all four streak kinds at once, in a fixed display
  /// order (workout, hydration, skincare, overall) — convenient for
  /// screens that render every streak together, like the Home
  /// dashboard and the Progress tab.
  List<StreakInfo> allStreaks({DateTime? asOf}) {
    final today = _dateOnly(asOf ?? DateTime.now());
    return [
      infoFor(StreakKind.workout, asOf: today),
      infoFor(StreakKind.hydration, asOf: today),
      infoFor(StreakKind.skincare, asOf: today),
      infoFor(StreakKind.overall, asOf: today),
    ];
  }
}
