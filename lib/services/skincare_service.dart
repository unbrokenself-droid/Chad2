import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which of the two daily skincare checklists a step belongs to.
enum SkincareRoutine { morning, night }

/// A single skincare checklist step, e.g. "Cleanser" or "Sunscreen".
///
/// Steps are a fixed catalog (see [SkincareService.allSteps]) rather
/// than user-created, but each one can be individually enabled or
/// disabled per routine via [SkincareService.setStepEnabled] — that's
/// the "customize enabled steps" behavior.
class SkincareStep {
  const SkincareStep({
    required this.id,
    required this.label,
    required this.icon,
    required this.routines,
    this.isOptionalByDefault = false,
  });

  /// Stable identifier used as the storage key. Never shown in the UI
  /// and never changed once shipped, so existing users' saved
  /// enabled/completed state keeps matching up after app updates.
  final String id;

  /// Display label, e.g. `'Cleanser'`.
  final String label;

  /// Icon shown next to the step in both checklists.
  final IconData icon;

  /// Which routine(s) this step normally appears in. Sunscreen, for
  /// instance, only lists [SkincareRoutine.morning].
  final Set<SkincareRoutine> routines;

  /// Whether this step starts out disabled for a first-ever launch.
  /// Only Serum defaults to off, matching its "(Optional)" labeling.
  final bool isOptionalByDefault;
}

/// Persists and broadcasts the user's morning/night skincare
/// checklists: which steps are enabled, and which have been checked
/// off today.
///
/// Backed by [SharedPreferences]: enabled steps are stored as a
/// native string list of `'stepId:routine'` entries (an opaque
/// compound key, never parsed back apart — only ever compared whole —
/// so [SharedPreferences]'s built-in string-list support already
/// covers it without needing any hand-rolled encoding), while
/// completion is stored the same way [ExerciseCompletionService] and
/// [HydrationService] store per-day state — a single JSON-encoded map
/// from `'yyyy-MM-dd'` date strings to the set of `'stepId:routine'`
/// entries checked off that day. Reading completion for any date
/// other than today naturally reports whatever was checked that day
/// (or nothing), which is what gives the checklists their "resets
/// every day" behavior for free: today's key simply starts out absent
/// each morning rather than needing an explicit reset step.
///
/// Completion previously used a hand-rolled
/// `'date=step,step|date=step,step|...'` string under
/// [_legacyCompletionStorageKey] instead of JSON. [load] migrates any
/// such data it finds into [_completionStorageKey] the first time it
/// runs on an existing install — see that method's doc comment — so
/// this is a one-time, automatic upgrade rather than something
/// callers need to think about.
///
/// A [ChangeNotifier] rather than a single-widget [State] field so
/// every place showing skincare progress — the Home reminder card and
/// the checklist sheet — stays in sync the instant a step is checked
/// or a routine is customized from either one.
class SkincareService extends ChangeNotifier {
  SkincareService({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _enabledStorageKey = 'skincare_enabled_steps';
  static const String _completionStorageKey =
      'skincare_completions_by_date_v2';

  /// Pre-JSON-migration key: a hand-rolled
  /// `'date=step,step|date=step,step|...'` string. Only ever read
  /// once, by [load], when [_completionStorageKey] is still empty —
  /// never written to again after this migration shipped. Left in
  /// place (not deleted) once migrated, purely as a harmless, inert
  /// fallback; nothing reads it after that first successful
  /// migration.
  static const String _legacyCompletionStorageKey =
      'skincare_completions_by_date';

  /// The fixed catalog of skincare steps offered across both
  /// routines. Order here is also checklist display order.
  static const List<SkincareStep> allSteps = [
    SkincareStep(
      id: 'cleanser',
      label: 'Cleanser',
      icon: Icons.bubble_chart_outlined,
      routines: {SkincareRoutine.morning, SkincareRoutine.night},
    ),
    SkincareStep(
      id: 'moisturizer',
      label: 'Moisturizer',
      icon: Icons.water_drop_outlined,
      routines: {SkincareRoutine.morning, SkincareRoutine.night},
    ),
    SkincareStep(
      id: 'sunscreen',
      label: 'Sunscreen',
      icon: Icons.wb_sunny_outlined,
      routines: {SkincareRoutine.morning},
    ),
    SkincareStep(
      id: 'serum',
      label: 'Serum (Optional)',
      icon: Icons.opacity,
      routines: {SkincareRoutine.morning, SkincareRoutine.night},
      isOptionalByDefault: true,
    ),
  ];

  final SharedPreferencesAsync _preferences;

  /// Which `'stepId:routine'` combinations are currently enabled.
  /// Every step/routine pair from [allSteps] starts enabled except
  /// Serum, which starts disabled per [SkincareStep.isOptionalByDefault].
  Set<String> _enabledStepRoutines = _defaultEnabled();
  Map<String, Set<String>> _completionsByDate = <String, Set<String>>{};
  bool _loaded = false;
  bool _hasStoredEnabledPrefs = false;

  static Set<String> _defaultEnabled() {
    return {
      for (final step in allSteps)
        for (final routine in step.routines)
          if (!step.isOptionalByDefault) _keyForStep(step.id, routine),
    };
  }

  /// Whether [load] has completed at least once. Callers that need to
  /// read skincare state before the app's first frame (rare) can
  /// await [load] directly instead of checking this.
  bool get isLoaded => _loaded;

  /// Loads persisted enabled-steps and completion history from disk.
  /// Safe to call more than once; subsequent calls just re-sync from
  /// storage. Callers should await this once near app startup —
  /// until it resolves, every query below reports the defaults
  /// (required steps enabled, nothing completed) rather than
  /// throwing.
  ///
  /// Completion specifically: reads [_completionStorageKey] first. If
  /// that's empty — either a fresh install, or an existing install
  /// that hasn't migrated yet — it falls back to reading and decoding
  /// [_legacyCompletionStorageKey]'s pre-JSON format. Any legacy data
  /// found is written straight back out as JSON under
  /// [_completionStorageKey], so this fallback only ever does real
  /// work once per install: every load after that finds
  /// [_completionStorageKey] already populated and never touches the
  /// legacy key again.
  Future<void> load() async {
    final storedEnabled = await _preferences.getStringList(
      _enabledStorageKey,
    );
    if (storedEnabled != null) {
      _enabledStepRoutines = storedEnabled.toSet();
      _hasStoredEnabledPrefs = true;
    }

    final storedCompletion = await _preferences.getString(
      _completionStorageKey,
    );
    if (storedCompletion == null || storedCompletion.isEmpty) {
      final legacyRaw = await _preferences.getString(
        _legacyCompletionStorageKey,
      );
      _completionsByDate = _decodeLegacyCompletion(legacyRaw);
      if (_completionsByDate.isNotEmpty) {
        await _preferences.setString(
          _completionStorageKey,
          _encodeCompletion(),
        );
      }
    } else {
      _completionsByDate = _decodeCompletion(storedCompletion);
    }

    _loaded = true;
    notifyListeners();
  }

  static String _keyForStep(String stepId, SkincareRoutine routine) {
    return '$stepId:${routine.name}';
  }

  /// Formats [date] as the `'yyyy-MM-dd'` key used internally.
  static String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Decodes [_completionStorageKey]'s current JSON format: a map
  /// from `'yyyy-MM-dd'` date strings to the set of `'stepId:routine'`
  /// entries checked off that day.
  static Map<String, Set<String>> _decodeCompletion(String? raw) {
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

  /// Decodes [_legacyCompletionStorageKey]'s pre-migration
  /// `'date=step,step|date=step,step|...'` format. Only ever called
  /// once per install, from [load], when [_completionStorageKey] is
  /// still empty.
  static Map<String, Set<String>> _decodeLegacyCompletion(String? raw) {
    if (raw == null || raw.isEmpty) return <String, Set<String>>{};
    try {
      final map = <String, Set<String>>{};
      for (final dayEntry in raw.split('|').where((e) => e.isNotEmpty)) {
        final separator = dayEntry.indexOf('=');
        if (separator == -1) continue;
        final date = dayEntry.substring(0, separator);
        final stepsRaw = dayEntry.substring(separator + 1);
        final steps = stepsRaw.split(',').where((e) => e.isNotEmpty).toSet();
        if (steps.isNotEmpty) map[date] = steps;
      }
      return map;
    } catch (_) {
      return <String, Set<String>>{};
    }
  }

  String _encodeCompletion() {
    final serializable = _completionsByDate.map(
      (key, steps) => MapEntry(key, steps.toList()),
    );
    return jsonEncode(serializable);
  }

  /// Steps that currently apply to [routine] — i.e. steps listing it
  /// in [SkincareStep.routines] — regardless of whether they're
  /// enabled. Used to lay out the checklist itself, which shows
  /// disabled steps too (just unchecked and dimmed) so users can
  /// re-enable them without leaving the sheet.
  List<SkincareStep> stepsFor(SkincareRoutine routine) {
    return allSteps.where((step) => step.routines.contains(routine)).toList();
  }

  /// Whether [step] is enabled for [routine]. Reports the built-in
  /// default (every step enabled except Serum) until [load] has
  /// completed or the user has customized anything.
  bool isStepEnabled(SkincareStep step, SkincareRoutine routine) {
    if (!_hasStoredEnabledPrefs) {
      return !step.isOptionalByDefault;
    }
    return _enabledStepRoutines.contains(_keyForStep(step.id, routine));
  }

  /// Enables or disables [step] for [routine] and persists the
  /// change. Disabling a step also un-checks it for today, so a step
  /// toggled off mid-routine doesn't keep contributing to today's
  /// completion count.
  Future<void> setStepEnabled(
    SkincareStep step,
    SkincareRoutine routine,
    bool enabled,
  ) async {
    // The first customization "materializes" the full default set so
    // toggling just one step off doesn't silently disable every step
    // that was previously relying on the implicit default.
    if (!_hasStoredEnabledPrefs) {
      _enabledStepRoutines = _defaultEnabled();
      _hasStoredEnabledPrefs = true;
    }
    final key = _keyForStep(step.id, routine);
    if (enabled) {
      _enabledStepRoutines.add(key);
    } else {
      _enabledStepRoutines.remove(key);
      await setStepCompleted(step, routine, false);
    }
    notifyListeners();
    await _preferences.setStringList(
      _enabledStorageKey,
      _enabledStepRoutines.toList(),
    );
  }

  /// Enabled steps for [routine], in catalog order. This is what the
  /// checklist counts against for "N of M done" and full-completion
  /// checks — a disabled step is simply not part of the routine.
  List<SkincareStep> enabledStepsFor(SkincareRoutine routine) {
    return stepsFor(
      routine,
    ).where((step) => isStepEnabled(step, routine)).toList();
  }

  /// Whether [step] was checked off for [routine] on [date] (defaults
  /// to today).
  bool isStepCompleted(
    SkincareStep step,
    SkincareRoutine routine, [
    DateTime? date,
  ]) {
    final dayKey = _dateKey(date ?? DateTime.now());
    final steps = _completionsByDate[dayKey];
    return steps?.contains(_keyForStep(step.id, routine)) ?? false;
  }

  /// Checks or unchecks [step] for [routine] on [date] (defaults to
  /// today) and persists the change.
  Future<void> setStepCompleted(
    SkincareStep step,
    SkincareRoutine routine, [
    bool completed = true,
    DateTime? date,
  ]) async {
    final dayKey = _dateKey(date ?? DateTime.now());
    final key = _keyForStep(step.id, routine);
    final steps = _completionsByDate.putIfAbsent(dayKey, () => <String>{});
    if (completed) {
      steps.add(key);
    } else {
      steps.remove(key);
      if (steps.isEmpty) _completionsByDate.remove(dayKey);
    }
    // Update in-memory state and notify listeners immediately so the
    // checklist reflects the tap right away; persistence happens
    // right after but doesn't block the UI update.
    notifyListeners();
    await _preferences.setString(_completionStorageKey, _encodeCompletion());
  }

  /// Flips the checked state of [step] for [routine] on [date]
  /// (defaults to today) and persists the change. Returns the new
  /// state (`true` if now checked).
  Future<bool> toggleStep(
    SkincareStep step,
    SkincareRoutine routine, [
    DateTime? date,
  ]) async {
    final nowCompleted = !isStepCompleted(step, routine, date);
    await setStepCompleted(step, routine, nowCompleted, date);
    return nowCompleted;
  }

  /// How many enabled steps in [routine] are checked off on [date]
  /// (defaults to today).
  int completedCountFor(SkincareRoutine routine, [DateTime? date]) {
    final enabled = enabledStepsFor(routine);
    return enabled
        .where((step) => isStepCompleted(step, routine, date))
        .length;
  }

  /// Total enabled steps in [routine], for "N of M" displays.
  int totalCountFor(SkincareRoutine routine) => enabledStepsFor(routine).length;

  /// Whether every enabled step in [routine] is checked off on [date]
  /// (defaults to today). A routine with zero enabled steps is not
  /// considered complete.
  bool isRoutineComplete(SkincareRoutine routine, [DateTime? date]) {
    final total = totalCountFor(routine);
    if (total == 0) return false;
    return completedCountFor(routine, date) == total;
  }

  /// Whether both the morning and night routines were fully completed
  /// on [date] (defaults to today). Used for skincare-streak
  /// calculations, where a day only counts once the whole day's
  /// skincare — not just one of the two routines — is done.
  bool isDayComplete([DateTime? date]) {
    return isRoutineComplete(SkincareRoutine.morning, date) &&
        isRoutineComplete(SkincareRoutine.night, date);
  }

  /// Today's morning routine if it isn't finished yet; otherwise
  /// today's night routine if *it* isn't finished; otherwise morning
  /// again (both already done — showing a fully-checked morning
  /// routine reads better than picking one arbitrarily).
  ///
  /// The single rule behind "which routine should a quick check-in
  /// surface right now" — used by both [SkincareCheckInCard] (the
  /// in-app Home widget) and [HomeWidgetSyncService] (the Android
  /// home-screen widget), so the two can never disagree about which
  /// routine is currently "the" one to show.
  SkincareRoutine get routineNeedingAttention {
    if (!isRoutineComplete(SkincareRoutine.morning)) {
      return SkincareRoutine.morning;
    }
    if (!isRoutineComplete(SkincareRoutine.night)) {
      return SkincareRoutine.night;
    }
    return SkincareRoutine.morning;
  }

  static DateTime _parseDateKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// The earliest calendar day with at least one checked-off step in
  /// either routine, or `null` if nothing has ever been checked off.
  /// Used by [StreakService] to know how far back to scan when
  /// computing the combined overall-wellness streak.
  DateTime? get earliestCompletedDay {
    final activeDays = _completionsByDate.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => _parseDateKey(entry.key));
    if (activeDays.isEmpty) return null;
    return activeDays.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Combined progress (0.0–1.0) across both routines today, used for
  /// the Home reminder card's badge — the sum of both checklists'
  /// completed steps over the sum of both their enabled totals.
  double get todayProgress {
    final totalSteps =
        totalCountFor(SkincareRoutine.morning) +
        totalCountFor(SkincareRoutine.night);
    if (totalSteps == 0) return 0.0;
    final completedSteps =
        completedCountFor(SkincareRoutine.morning) +
        completedCountFor(SkincareRoutine.night);
    return (completedSteps / totalSteps).clamp(0.0, 1.0).toDouble();
  }
}
