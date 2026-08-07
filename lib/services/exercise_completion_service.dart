import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and broadcasts which exercises the user has completed, on
/// which calendar days.
///
/// Backed by [SharedPreferences] under a single JSON-encoded string
/// key mapping each date (as a `'yyyy-MM-dd'` string) to the set of
/// exercise ids completed that day, so completion history survives
/// app restarts without needing a database. State is also cached in
/// memory once loaded, so every query method here can be read
/// synchronously (e.g. from a build method) after [load] completes.
///
/// A [ChangeNotifier] rather than a single-widget [State] field so
/// every screen showing completion — exercise cards, the details
/// screen's completion button, Home's streak card, and Progress's
/// stats and charts — stays in sync the instant an exercise is marked
/// complete anywhere, without needing to pass callbacks up and down
/// the widget tree.
class ExerciseCompletionService extends ChangeNotifier {
  ExerciseCompletionService({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _storageKey = 'exercise_completions_by_date';

  final SharedPreferencesAsync _preferences;

  /// Completed exercise ids, keyed by `'yyyy-MM-dd'`. Every value is
  /// non-empty; a day with no completions simply has no entry.
  Map<String, Set<String>> _completionsByDate = <String, Set<String>>{};
  bool _loaded = false;

  /// Whether [load] has completed at least once. Callers that need to
  /// read completion history before the app's first frame (rare) can
  /// await [load] directly instead of checking this.
  bool get isLoaded => _loaded;

  /// Loads persisted completion history from disk. Safe to call more
  /// than once (e.g. defensively from multiple screens); subsequent
  /// calls just re-sync from storage. Callers should await this once
  /// near app startup — until it resolves, every query below reports
  /// empty/zero rather than throwing.
  Future<void> load() async {
    final stored = await _preferences.getString(_storageKey);
    _completionsByDate = _decode(stored);
    _loaded = true;
    notifyListeners();
  }

  static Map<String, Set<String>> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <String, Set<String>>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, Set<String>.from(value as List)),
      );
    } catch (_) {
      // Corrupt or unexpected stored data shouldn't crash the app;
      // treat it as an empty history rather than propagating.
      return <String, Set<String>>{};
    }
  }

  String _encode() {
    final serializable = _completionsByDate.map(
      (key, ids) => MapEntry(key, ids.toList()),
    );
    return jsonEncode(serializable);
  }

  /// Discards the time-of-day component of [date], leaving just its
  /// calendar day. Every public method below treats dates by calendar
  /// day, so e.g. two different times on the same day are equivalent.
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

  /// Ids of exercises completed on [date] (defaults to today). Reads
  /// from the in-memory cache — reports empty until [load] has
  /// completed once.
  Set<String> idsCompletedOn([DateTime? date]) {
    final key = _keyFor(date ?? DateTime.now());
    return Set.unmodifiable(_completionsByDate[key] ?? const <String>{});
  }

  /// Ids of exercises completed today. Shorthand for
  /// `idsCompletedOn(DateTime.now())`.
  Set<String> get completedTodayIds => idsCompletedOn();

  /// Whether [exerciseId] was completed on [date] (defaults to today).
  bool isCompletedOn(String exerciseId, [DateTime? date]) {
    final key = _keyFor(date ?? DateTime.now());
    return _completionsByDate[key]?.contains(exerciseId) ?? false;
  }

  /// Whether [exerciseId] was completed today. Shorthand for
  /// `isCompletedOn(exerciseId, DateTime.now())`.
  bool isCompletedToday(String exerciseId) => isCompletedOn(exerciseId);

  /// How many distinct exercises were completed on [date] (defaults to
  /// today). Useful for progress bars and calendar-style summaries.
  int countCompletedOn([DateTime? date]) => idsCompletedOn(date).length;

  /// The total number of exercise completions ever recorded, across
  /// every day. Unlike [countCompletedOn], the same exercise completed
  /// on several different days counts once per day.
  int get totalCompletedCount {
    return _completionsByDate.values.fold(0, (sum, ids) => sum + ids.length);
  }

  /// Marks [exerciseId] as completed on [date] (defaults to today) and
  /// persists the change. A no-op (but still notifies) if it was
  /// already marked complete.
  Future<void> markCompleted(String exerciseId, [DateTime? date]) async {
    final key = _keyFor(date ?? DateTime.now());
    final ids = _completionsByDate.putIfAbsent(key, () => <String>{});
    ids.add(exerciseId);
    // Update in-memory state and notify listeners immediately so the
    // UI reflects completion right away; persistence happens right
    // after but doesn't block the UI update.
    notifyListeners();
    await _preferences.setString(_storageKey, _encode());
  }

  /// Un-marks [exerciseId] as completed on [date] (defaults to today)
  /// and persists the change. A no-op (but still notifies) if it
  /// wasn't marked complete.
  Future<void> markIncomplete(String exerciseId, [DateTime? date]) async {
    final key = _keyFor(date ?? DateTime.now());
    final ids = _completionsByDate[key];
    ids?.remove(exerciseId);
    if (ids != null && ids.isEmpty) _completionsByDate.remove(key);
    notifyListeners();
    await _preferences.setString(_storageKey, _encode());
  }

  /// Flips the completed state of [exerciseId] on [date] (defaults to
  /// today) and persists the change. Returns the new state (`true` if
  /// now completed).
  Future<bool> toggleCompleted(String exerciseId, [DateTime? date]) async {
    final nowCompleted = !isCompletedOn(exerciseId, date);
    if (nowCompleted) {
      await markCompleted(exerciseId, date);
    } else {
      await markIncomplete(exerciseId, date);
    }
    return nowCompleted;
  }

  /// Whether at least one exercise was completed on [date] — i.e.
  /// whether [date] counts as an "active" day for streak purposes.
  bool hasActivityOn(DateTime date) => idsCompletedOn(date).isNotEmpty;

  /// The user's current daily streak: the number of consecutive days,
  /// ending today, with at least one completed exercise.
  ///
  /// If nothing has been completed yet today, today doesn't break the
  /// streak by itself — the count instead starts from yesterday, so a
  /// streak only resets once a full day passes with no activity at
  /// all (rather than the instant the clock ticks past midnight).
  int currentStreak({DateTime? asOf}) {
    var cursor = _dateOnly(asOf ?? DateTime.now());
    if (!hasActivityOn(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (hasActivityOn(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// The earliest calendar day with at least one recorded completion,
  /// or `null` if nothing has ever been completed. Used by
  /// [StreakService] to know how far back to scan when computing the
  /// combined overall-wellness streak.
  DateTime? get earliestActivityDay {
    final activeDays = _completionsByDate.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => _parseKey(entry.key));
    if (activeDays.isEmpty) return null;
    return activeDays.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// The longest run of consecutive days with at least one completed
  /// exercise found anywhere in the recorded history (including the
  /// current streak, if that happens to be the longest).
  int longestStreak() {
    if (_completionsByDate.isEmpty) return 0;

    final activeDays = _completionsByDate.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => _parseKey(entry.key))
        .toList()
      ..sort();

    var longest = 0;
    var current = 0;
    DateTime? previousDay;
    for (final day in activeDays) {
      if (previousDay != null && day.difference(previousDay).inDays == 1) {
        current++;
      } else {
        current = 1;
      }
      if (current > longest) longest = current;
      previousDay = day;
    }
    return longest;
  }
}
