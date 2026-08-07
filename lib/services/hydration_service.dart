import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which unit hydration amounts are displayed in. Storage is always
/// milliliters internally — this only affects formatting and which
/// quick-add amounts are offered, never how data is persisted, so
/// switching units mid-use never touches or reinterprets existing
/// history.
enum HydrationUnit {
  metric,
  imperial;

  /// User-facing label shown in the Units settings row/picker.
  String get label {
    switch (this) {
      case HydrationUnit.metric:
        return 'Metric (ml)';
      case HydrationUnit.imperial:
        return 'Imperial (fl oz)';
    }
  }

  /// Short label for the Settings row's trailing text, e.g. 'Metric'.
  String get shortLabel {
    switch (this) {
      case HydrationUnit.metric:
        return 'Metric';
      case HydrationUnit.imperial:
        return 'Imperial';
    }
  }
}

/// Persists and broadcasts the user's daily water intake and goal.
///
/// Backed by [SharedPreferences]: the goal (in milliliters) is stored
/// under a single key, while intake is stored the same way
/// [ExerciseCompletionService] stores completions — as a single
/// JSON-encoded map from `'yyyy-MM-dd'` date strings to the number of
/// milliliters logged that day. Reading intake for any date other
/// than today naturally reports whatever was logged that day (or
/// zero), which is what gives hydration tracking its "resets every
/// day" behavior for free: today's key simply starts out absent each
/// morning rather than needing an explicit reset step.
///
/// Intake previously used a hand-rolled `'date:ml;date:ml;...'`
/// string under [_legacyIntakeStorageKey] instead of JSON. [load]
/// migrates any such data it finds into [_intakeStorageKey] the first
/// time it runs on an existing install — see that method's doc
/// comment — so this is a one-time, automatic upgrade rather than
/// something callers need to think about.
///
/// A [ChangeNotifier] rather than a single-widget [State] field so
/// every place showing hydration — the Home reminder card and the
/// hydration detail sheet — stays in sync the instant water is
/// logged from either one.
class HydrationService extends ChangeNotifier {
  HydrationService({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _goalStorageKey = 'hydration_daily_goal_ml';
  static const String _intakeStorageKey = 'hydration_intake_by_date_v2';
  static const String _unitStorageKey = 'hydration_unit';

  /// Pre-JSON-migration key: a hand-rolled `'date:ml;date:ml;...'`
  /// string. Only ever read once, by [load], when [_intakeStorageKey]
  /// is still empty — never written to again after this migration
  /// shipped. Left in place (not deleted) once migrated, purely as a
  /// harmless, inert fallback; nothing reads it after that first
  /// successful migration.
  static const String _legacyIntakeStorageKey = 'hydration_intake_by_date';

  /// Default daily goal for a first-ever launch, before the user has
  /// set their own: 2000ml (8 glasses of 250ml), matching the
  /// "4 of 8" placeholder this feature replaces on Home.
  static const int defaultGoalMl = 2000;

  /// US fluid ounces per milliliter — the standard conversion factor
  /// (1 fl oz = 29.5735295625 ml), used by every ml↔fl oz conversion
  /// below.
  static const double _mlPerFlOz = 29.5735295625;

  /// Converts [ml] to US fluid ounces.
  static double mlToFlOz(int ml) => ml / _mlPerFlOz;

  /// Converts [flOz] to milliliters, rounded to the nearest whole
  /// ml — this service's actual storage unit, regardless of display
  /// unit.
  static int flOzToMl(double flOz) => (flOz * _mlPerFlOz).round();

  /// Formats [ml] for display in [unit] — e.g. `'250 ml'` or
  /// `'8 fl oz'`. A static, explicit-unit version of [formatMl], for
  /// callers (like a computed statistics snapshot) that captured a
  /// unit preference at some earlier point rather than reading it
  /// live from a [HydrationService] instance.
  static String formatAmount(int ml, HydrationUnit unit) {
    switch (unit) {
      case HydrationUnit.metric:
        return '$ml ml';
      case HydrationUnit.imperial:
        return '${mlToFlOz(ml).round()} fl oz';
    }
  }

  /// [ml] formatted for display in [unit] as liters/gallons, e.g.
  /// `'1.8 L'` or `'0.5 gal'` — the coarser-grained sibling of
  /// [formatAmount], for weekly/period totals where a raw ml or fl oz
  /// count would be an unreadably large number.
  static String formatAmountCoarse(int ml, HydrationUnit unit) {
    switch (unit) {
      case HydrationUnit.metric:
        return '${(ml / 1000).toStringAsFixed(1)} L';
      case HydrationUnit.imperial:
        // 1 US gallon = 128 fl oz.
        return '${(mlToFlOz(ml) / 128).toStringAsFixed(1)} gal';
    }
  }

  final SharedPreferencesAsync _preferences;

  int _goalMl = defaultGoalMl;
  Map<String, int> _intakeByDate = <String, int>{};
  HydrationUnit _unit = HydrationUnit.metric;
  bool _loaded = false;

  /// Whether [load] has completed at least once. Callers that need to
  /// read hydration state before the app's first frame (rare) can
  /// await [load] directly instead of checking this.
  bool get isLoaded => _loaded;

  /// The user's daily water goal, in milliliters.
  int get goalMl => _goalMl;

  /// The unit hydration amounts are currently displayed in. Storage
  /// is always milliliters regardless — see [HydrationUnit]'s doc
  /// comment.
  HydrationUnit get unit => _unit;

  /// Quick-add amounts, in milliliters — this service's native
  /// storage unit — for the currently selected [unit]. Metric uses
  /// round milliliter amounts (100/250/500); imperial uses round
  /// fluid-ounce amounts (4/8/16 fl oz, a standard US measuring-cup
  /// progression) converted to their nearest millimeter equivalent,
  /// so a US-based user sees "8 fl oz" — a number they'd actually
  /// reach for — rather than an odd-looking direct conversion of the
  /// metric amounts like "237 ml".
  List<int> get quickAddAmountsMl {
    switch (_unit) {
      case HydrationUnit.metric:
        return const [100, 250, 500];
      case HydrationUnit.imperial:
        return [flOzToMl(4), flOzToMl(8), flOzToMl(16)];
    }
  }

  /// [ml] formatted for display using this service's current [unit].
  /// Shorthand for `HydrationService.formatAmount(ml, unit)`.
  String formatMl(int ml) => formatAmount(ml, _unit);

  /// [ml] formatted as liters/gallons using this service's current
  /// [unit]. Shorthand for `HydrationService.formatAmountCoarse(ml, unit)`.
  String formatMlCoarse(int ml) => formatAmountCoarse(ml, _unit);

  /// [goalMl] converted into whatever number the user would actually
  /// type for it in [unit] — e.g. `2000` ml stays `2000` in metric,
  /// or becomes `~68` in imperial (fl oz, rounded to the nearest
  /// whole number, matching how [setGoalFromUnitInput] rounds back).
  /// Used to pre-fill the goal-editing field so it starts from a
  /// number that makes sense in whichever unit is currently active,
  /// not always a raw ml count.
  double goalInCurrentUnit() {
    switch (_unit) {
      case HydrationUnit.metric:
        return _goalMl.toDouble();
      case HydrationUnit.imperial:
        return mlToFlOz(_goalMl);
    }
  }

  /// Sets the goal from [value] — a number the user typed in
  /// whichever unit is currently active (see [goalInCurrentUnit]) —
  /// converting to milliliters for storage if needed. The inverse of
  /// [goalInCurrentUnit], kept next to it since the two need to agree
  /// about which unit a "raw number" is in.
  Future<void> setGoalFromUnitInput(double value) async {
    final goalMl = switch (_unit) {
      HydrationUnit.metric => value.round(),
      HydrationUnit.imperial => flOzToMl(value),
    };
    await setGoal(goalMl);
  }

  /// Updates the display unit and persists the change. Never touches
  /// stored intake/goal data — both remain in milliliters regardless;
  /// this only changes how they're formatted and which quick-add
  /// amounts are offered.
  Future<void> setUnit(HydrationUnit value) async {
    if (value == _unit) return;
    _unit = value;
    notifyListeners();
    await _preferences.setString(_unitStorageKey, value.name);
  }

  /// Loads the persisted goal and intake history from disk. Safe to
  /// call more than once; subsequent calls just re-sync from storage.
  /// Callers should await this once near app startup — until it
  /// resolves, [todayIntakeMl] reports `0` and [goalMl] reports
  /// [defaultGoalMl] rather than throwing.
  ///
  /// Intake specifically: reads [_intakeStorageKey] first. If that's
  /// empty — either a fresh install, or an existing install that
  /// hasn't migrated yet — it falls back to reading and decoding
  /// [_legacyIntakeStorageKey]'s pre-JSON format. Any legacy data
  /// found is written straight back out as JSON under
  /// [_intakeStorageKey], so this fallback only ever does real work
  /// once per install: every load after that finds [_intakeStorageKey]
  /// already populated and never touches the legacy key again.
  Future<void> load() async {
    final storedGoal = await _preferences.getInt(_goalStorageKey);
    final storedIntake = await _preferences.getString(_intakeStorageKey);
    final storedUnit = await _preferences.getString(_unitStorageKey);
    _goalMl = storedGoal ?? defaultGoalMl;
    _unit = _decodeUnit(storedUnit);

    if (storedIntake == null || storedIntake.isEmpty) {
      final legacyRaw = await _preferences.getString(_legacyIntakeStorageKey);
      _intakeByDate = _decodeLegacy(legacyRaw);
      if (_intakeByDate.isNotEmpty) {
        await _preferences.setString(_intakeStorageKey, _encode());
      }
    } else {
      _intakeByDate = _decode(storedIntake);
    }

    _loaded = true;
    notifyListeners();
  }

  static HydrationUnit _decodeUnit(String? raw) {
    if (raw == null) return HydrationUnit.metric;
    try {
      return HydrationUnit.values.byName(raw);
    } on ArgumentError {
      return HydrationUnit.metric;
    }
  }

  /// Decodes [_intakeStorageKey]'s current JSON format: a map from
  /// `'yyyy-MM-dd'` date strings to milliliters logged that day.
  static Map<String, int> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value as int));
    } catch (_) {
      // Corrupt or unexpected stored data shouldn't crash the app;
      // treat it as an empty history rather than propagating.
      return <String, int>{};
    }
  }

  /// Decodes [_legacyIntakeStorageKey]'s pre-migration
  /// `'date:ml;date:ml;...'` format. Only ever called once per
  /// install, from [load], when [_intakeStorageKey] is still empty.
  static Map<String, int> _decodeLegacy(String? raw) {
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = raw.split(';').where((entry) => entry.isNotEmpty);
      final map = <String, int>{};
      for (final entry in decoded) {
        final parts = entry.split(':');
        if (parts.length != 2) continue;
        final amount = int.tryParse(parts[1]);
        if (amount != null) map[parts[0]] = amount;
      }
      return map;
    } catch (_) {
      return <String, int>{};
    }
  }

  String _encode() => jsonEncode(_intakeByDate);

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

  /// Milliliters of water logged on [date] (defaults to today). Reads
  /// from the in-memory cache — reports `0` until [load] has
  /// completed once, and naturally reports `0` for any day nothing
  /// was logged, which is what makes intake reset each day without
  /// any explicit cleanup step.
  int intakeOn([DateTime? date]) {
    final key = _keyFor(date ?? DateTime.now());
    return _intakeByDate[key] ?? 0;
  }

  /// Milliliters of water logged today. Shorthand for
  /// `intakeOn(DateTime.now())`.
  int get todayIntakeMl => intakeOn();

  /// Today's progress toward [goalMl], clamped to the 0.0–1.0 range
  /// so a ring or progress bar never overflows once the goal is met
  /// or exceeded.
  double get todayProgress {
    if (_goalMl <= 0) return 0.0;
    return (todayIntakeMl / _goalMl).clamp(0.0, 1.0).toDouble();
  }

  /// Whether today's goal has been reached or exceeded.
  bool get goalReachedToday => todayIntakeMl >= _goalMl;

  /// Whether the daily goal was reached or exceeded on [date]
  /// (defaults to today). Used for hydration-streak calculations,
  /// where a day only counts if the full goal was hit — logging a
  /// single glass shouldn't be enough to keep the streak alive.
  bool goalReachedOn([DateTime? date]) => intakeOn(date) >= _goalMl;

  /// The earliest calendar day with any logged intake, or `null` if
  /// nothing has ever been logged. Used by [StreakService] to know
  /// how far back to scan when computing the combined
  /// overall-wellness streak.
  DateTime? get earliestLoggedDay {
    final days = _intakeByDate.keys.map(_parseKey);
    if (days.isEmpty) return null;
    return days.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Adds [amountMl] to [date]'s logged intake (defaults to today)
  /// and persists the change. Negative totals are not allowed; the
  /// result is clamped to zero.
  Future<void> addIntake(int amountMl, [DateTime? date]) async {
    final key = _keyFor(date ?? DateTime.now());
    final updated = (_intakeByDate[key] ?? 0) + amountMl;
    if (updated <= 0) {
      _intakeByDate.remove(key);
    } else {
      _intakeByDate[key] = updated;
    }
    // Update in-memory state and notify listeners immediately so the
    // ring/progress fills right away; persistence happens right after
    // but doesn't block the UI update.
    notifyListeners();
    await _preferences.setString(_intakeStorageKey, _encode());
  }

  /// Resets [date]'s logged intake back to zero (defaults to today).
  /// Exposed mainly for an "undo"/"start over" control; day-to-day
  /// resets already happen automatically since each date's intake is
  /// looked up independently.
  Future<void> resetIntake([DateTime? date]) async {
    final key = _keyFor(date ?? DateTime.now());
    if (!_intakeByDate.containsKey(key)) return;
    _intakeByDate.remove(key);
    notifyListeners();
    await _preferences.setString(_intakeStorageKey, _encode());
  }

  /// Updates the daily water goal and persists it. Values below
  /// 250ml are clamped up to it — a goal that small would make even a
  /// single quick-add button overshoot it instantly.
  Future<void> setGoal(int goalMl) async {
    _goalMl = goalMl < 250 ? 250 : goalMl;
    notifyListeners();
    await _preferences.setInt(_goalStorageKey, _goalMl);
  }
}
