import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and broadcasts the user's scheduled rest days.
///
/// A rest day can be scheduled two ways, which combine:
///  * a specific calendar date (e.g. "take Friday the 12th off"), or
///  * a recurring weekday (e.g. "Sundays are always a rest day").
///
/// A day counts as a rest day if it matches either. This mirrors how
/// [ReminderSettingsService] separates "one-off" state from a
/// recurring rule, but kept intentionally simple since rest days have
/// no time-of-day component — just whole calendar days.
///
/// Rest days exist to pause *workout*-streak loss: a scheduled rest
/// day should never break the workout or overall-wellness streak,
/// even though no exercise was completed that day. They deliberately
/// have no effect on hydration or skincare tracking — see
/// [StreakService], which is the only other place that reads this
/// service — so a user can still log water and skincare on a rest day
/// exactly as on any other day, and those streaks are graded exactly
/// as before.
///
/// Backed by [SharedPreferences]: specific dates are stored as a
/// single JSON-encoded list of `'yyyy-MM-dd'` strings, and recurring
/// weekdays as a JSON-encoded list of weekday integers (1 = Monday…7
/// = Sunday, matching [DateTime.weekday]).
///
/// A [ChangeNotifier] so every screen showing or editing rest days —
/// the scheduling sheet, Home's streak card, and Settings — stays in
/// sync the instant a rest day is added or removed anywhere.
class RestDayService extends ChangeNotifier {
  RestDayService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _specificDatesStorageKey = 'rest_days_specific_dates';
  static const String _recurringWeekdaysStorageKey =
      'rest_days_recurring_weekdays';

  final SharedPreferencesAsync _preferences;

  /// Specific rest-day dates, keyed by `'yyyy-MM-dd'`.
  Set<String> _specificDates = <String>{};

  /// Recurring rest-day weekdays, using [DateTime.weekday] values
  /// (1 = Monday … 7 = Sunday).
  Set<int> _recurringWeekdays = <int>{};

  bool _loaded = false;

  /// Whether [load] has completed at least once. Callers that need to
  /// read rest-day state before the app's first frame (rare) can
  /// await [load] directly instead of checking this.
  bool get isLoaded => _loaded;

  /// Loads persisted rest-day state from disk. Safe to call more than
  /// once; subsequent calls just re-sync from storage. Callers should
  /// await this once near app startup — until it resolves, [isRestDay]
  /// reports `false` for every date rather than throwing.
  Future<void> load() async {
    final storedDates = await _preferences.getStringList(
      _specificDatesStorageKey,
    );
    final storedWeekdays = await _preferences.getStringList(
      _recurringWeekdaysStorageKey,
    );
    _specificDates = (storedDates ?? const <String>[]).toSet();
    _recurringWeekdays = (storedWeekdays ?? const <String>[])
        .map(int.parse)
        .toSet();
    _loaded = true;
    notifyListeners();
  }

  /// Discards the time-of-day component of [date], leaving just its
  /// calendar day.
  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Formats [date] as the `'yyyy-MM-dd'` key used internally.
  static String _keyFor(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime _parseKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Every specific date scheduled as a rest day, most recent first.
  /// Does not include dates that are only rest days because of a
  /// recurring weekday — see [recurringWeekdays] for those.
  List<DateTime> get scheduledDates {
    final dates = _specificDates.map(_parseKey).toList()
      ..sort((a, b) => b.compareTo(a));
    return dates;
  }

  /// The set of weekdays ([DateTime.weekday] values, 1 = Monday … 7 =
  /// Sunday) that are always rest days.
  Set<int> get recurringWeekdays => Set.unmodifiable(_recurringWeekdays);

  /// Whether [date] is a scheduled rest day — either because that
  /// specific date was scheduled, or because its weekday is a
  /// recurring rest day.
  bool isRestDay(DateTime date) {
    final day = _dateOnly(date);
    if (_recurringWeekdays.contains(day.weekday)) return true;
    return _specificDates.contains(_keyFor(day));
  }

  /// Whether today is a scheduled rest day. Shorthand for
  /// `isRestDay(DateTime.now())`.
  bool get isRestToday => isRestDay(DateTime.now());

  Future<void> _persistDates() async {
    await _preferences.setStringList(
      _specificDatesStorageKey,
      _specificDates.toList(),
    );
  }

  Future<void> _persistWeekdays() async {
    await _preferences.setStringList(
      _recurringWeekdaysStorageKey,
      _recurringWeekdays.map((w) => w.toString()).toList(),
    );
  }

  /// Schedules [date] as a one-off rest day and persists the change.
  /// A no-op (but still notifies) if it was already scheduled.
  Future<void> scheduleDate(DateTime date) async {
    final key = _keyFor(_dateOnly(date));
    if (!_specificDates.add(key)) {
      notifyListeners();
      return;
    }
    notifyListeners();
    await _persistDates();
  }

  /// Un-schedules [date] as a one-off rest day and persists the
  /// change. Does not affect a recurring weekday that might also
  /// cover this date — see [removeRecurringWeekday] for that. A no-op
  /// (but still notifies) if it wasn't scheduled.
  Future<void> unscheduleDate(DateTime date) async {
    final key = _keyFor(_dateOnly(date));
    if (!_specificDates.remove(key)) {
      notifyListeners();
      return;
    }
    notifyListeners();
    await _persistDates();
  }

  /// Toggles whether [date] is scheduled as a one-off rest day, and
  /// persists the change. Returns the new state (`true` if now
  /// scheduled).
  Future<bool> toggleDate(DateTime date) async {
    final key = _keyFor(_dateOnly(date));
    if (_specificDates.contains(key)) {
      await unscheduleDate(date);
      return false;
    } else {
      await scheduleDate(date);
      return true;
    }
  }

  /// Makes [weekday] ([DateTime.weekday] value, 1 = Monday … 7 =
  /// Sunday) a recurring rest day every week, and persists the
  /// change.
  Future<void> addRecurringWeekday(int weekday) async {
    if (!_recurringWeekdays.add(weekday)) {
      notifyListeners();
      return;
    }
    notifyListeners();
    await _persistWeekdays();
  }

  /// Removes [weekday] from the recurring rest-day set, and persists
  /// the change. Specific dates scheduled independently are
  /// unaffected.
  Future<void> removeRecurringWeekday(int weekday) async {
    if (!_recurringWeekdays.remove(weekday)) {
      notifyListeners();
      return;
    }
    notifyListeners();
    await _persistWeekdays();
  }

  /// Toggles whether [weekday] is a recurring rest day, and persists
  /// the change. Returns the new state (`true` if now recurring).
  Future<bool> toggleRecurringWeekday(int weekday) async {
    if (_recurringWeekdays.contains(weekday)) {
      await removeRecurringWeekday(weekday);
      return false;
    } else {
      await addRecurringWeekday(weekday);
      return true;
    }
  }
}
