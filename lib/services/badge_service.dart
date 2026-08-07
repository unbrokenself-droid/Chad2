import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/badge_definition.dart';
import 'app_notifications.dart';
import 'exercise_completion_service.dart';
import 'hydration_service.dart';
import 'reminder_settings_service.dart';
import 'skincare_service.dart';
import 'streak_service.dart';

/// A single badge's live state: its static [definition], current
/// progress toward [BadgeDefinition.goal], and whether it has been
/// unlocked (plus when, if so).
class BadgeProgress {
  const BadgeProgress({
    required this.definition,
    required this.current,
    required this.unlocked,
    this.unlockedAt,
  });

  final BadgeDefinition definition;

  /// Current progress toward [BadgeDefinition.goal], clamped so it
  /// never displays past the goal even if the underlying stat (e.g.
  /// total exercises) keeps climbing after unlock.
  final int current;

  /// Whether this badge has been earned.
  final bool unlocked;

  /// When this badge was unlocked, or `null` if it hasn't been.
  final DateTime? unlockedAt;

  /// Progress toward the goal, 0.0–1.0.
  double get progress {
    if (definition.goal <= 0) return 0.0;
    return (current / definition.goal).clamp(0.0, 1.0).toDouble();
  }
}

/// Derives achievement-badge progress and unlock state from the
/// app's existing tracking services, and persists which badges have
/// been unlocked (and when) so they stay earned across restarts.
///
/// Progress itself is always recomputed live from
/// [ExerciseCompletionService], [HydrationService], [SkincareService],
/// [StreakService], and [ReminderSettingsService] — the same
/// read-through approach [StreakService] uses — so a badge's progress
/// bar never drifts out of sync with the underlying stats. Only the
/// *unlocked* flag (and its timestamp) is written to disk, since
/// unlocking is a one-way, permanent event that must survive even if
/// the underlying stat that triggered it later changes (e.g. a
/// hydration streak resetting shouldn't un-earn "Hydration Hero").
///
/// Call [checkForNewUnlocks] after any user action that could move a
/// badge's progress (this happens automatically via listeners on the
/// source services) to persist newly-earned badges and populate
/// [newlyUnlocked] for the UI to animate and then acknowledge via
/// [acknowledgeNewlyUnlocked].
///
/// Unlock state is stored under [_unlockedStorageKey] as a single
/// JSON-encoded map from each [BadgeId]'s name to its ISO 8601 unlock
/// timestamp. That key previously held a hand-rolled
/// `'badgeId:isoTimestamp;...'` string instead of JSON; [load]
/// migrates any such data it finds the first time it runs on an
/// existing install — see that method's doc comment — so this is a
/// one-time, automatic upgrade rather than something callers need to
/// think about.
class BadgeService extends ChangeNotifier {
  BadgeService({
    required ExerciseCompletionService exercise,
    required HydrationService hydration,
    required SkincareService skincare,
    required StreakService streak,
    required ReminderSettingsService reminders,
    SharedPreferencesAsync? preferences,
  }) : _exercise = exercise,
       _hydration = hydration,
       _skincare = skincare,
       _streak = streak,
       _reminders = reminders,
       _preferences = preferences ?? SharedPreferencesAsync() {
    _exercise.addListener(_onSourceChanged);
    _hydration.addListener(_onSourceChanged);
    _skincare.addListener(_onSourceChanged);
    _reminders.addListener(_onSourceChanged);
  }

  static const String _unlockedStorageKey = 'unlocked_badges_v2';

  /// Pre-JSON-migration key: a hand-rolled
  /// `'badgeId:isoTimestamp;...'` string — [_unlockedStorageKey]'s
  /// `v1` predecessor, despite that name predating this JSON
  /// migration by a fair bit (it was never about format versioning
  /// until now). Only ever read once, by [load], when
  /// [_unlockedStorageKey] is still empty — never written to again
  /// after this migration shipped. Left in place (not deleted) once
  /// migrated, purely as a harmless, inert fallback; nothing reads it
  /// after that first successful migration.
  static const String _legacyUnlockedStorageKey = 'unlocked_badges_v1';

  final ExerciseCompletionService _exercise;
  final HydrationService _hydration;
  final SkincareService _skincare;
  final StreakService _streak;
  final ReminderSettingsService _reminders;
  final SharedPreferencesAsync _preferences;

  /// `badgeId.name -> ISO 8601 unlock timestamp`.
  Map<String, DateTime> _unlockedAt = <String, DateTime>{};
  bool _loaded = false;

  /// Badges unlocked since the last [acknowledgeNewlyUnlocked] call,
  /// in the order they were unlocked. The UI reads this after each
  /// source-service change (or right after [load]/[checkForNewUnlocks])
  /// to know which celebration animations to show.
  final List<BadgeId> _newlyUnlocked = <BadgeId>[];

  /// Whether [load] has completed at least once.
  bool get isLoaded => _loaded;

  /// Loads persisted unlock state from disk, then immediately checks
  /// whether any badge's live progress already qualifies as unlocked
  /// (covering the case where enough progress was made in a previous
  /// session that ended before this service existed). Safe to call
  /// more than once.
  ///
  /// Reads [_unlockedStorageKey] first. If that's empty — either a
  /// fresh install, or an existing install that hasn't migrated yet —
  /// it falls back to reading and decoding
  /// [_legacyUnlockedStorageKey]'s pre-JSON format. Any legacy data
  /// found is written straight back out as JSON under
  /// [_unlockedStorageKey], so this fallback only ever does real work
  /// once per install: every load after that finds
  /// [_unlockedStorageKey] already populated and never touches the
  /// legacy key again.
  Future<void> load() async {
    final stored = await _preferences.getString(_unlockedStorageKey);
    if (stored == null || stored.isEmpty) {
      final legacyRaw = await _preferences.getString(
        _legacyUnlockedStorageKey,
      );
      _unlockedAt = _decodeLegacy(legacyRaw);
      if (_unlockedAt.isNotEmpty) {
        await _preferences.setString(_unlockedStorageKey, _encode());
      }
    } else {
      _unlockedAt = _decode(stored);
    }
    _loaded = true;
    // Don't surface a burst of "newly unlocked" celebrations for
    // badges a returning user already quietly qualifies for on first
    // load — only badges crossed during this live session should
    // animate. Persist any such badges directly rather than routing
    // through _newlyUnlocked.
    await _syncUnlocks(announceNew: false);
    notifyListeners();
  }

  /// Decodes [_unlockedStorageKey]'s current JSON format: a map from
  /// each [BadgeId]'s name to its ISO 8601 unlock timestamp.
  static Map<String, DateTime> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <String, DateTime>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final map = <String, DateTime>{};
      for (final entry in decoded.entries) {
        final parsed = DateTime.tryParse(entry.value as String);
        if (parsed != null) map[entry.key] = parsed;
      }
      return map;
    } catch (_) {
      // Corrupt or unexpected stored data shouldn't crash the app;
      // treat it as no badges unlocked yet rather than propagating.
      return <String, DateTime>{};
    }
  }

  /// Decodes [_legacyUnlockedStorageKey]'s pre-migration
  /// `'badgeId:isoTimestamp;...'` format — note the value itself may
  /// contain colons (an ISO 8601 timestamp does), so only the first
  /// colon in each entry separates the id from the timestamp; the
  /// rest are rejoined back into it. Only ever called once per
  /// install, from [load], when [_unlockedStorageKey] is still empty.
  static Map<String, DateTime> _decodeLegacy(String? raw) {
    if (raw == null || raw.isEmpty) return <String, DateTime>{};
    try {
      final map = <String, DateTime>{};
      for (final entry in raw.split(';').where((e) => e.isNotEmpty)) {
        final parts = entry.split(':');
        if (parts.length < 2) continue;
        final id = parts[0];
        final iso = parts.sublist(1).join(':');
        final parsed = DateTime.tryParse(iso);
        if (parsed != null) map[id] = parsed;
      }
      return map;
    } catch (_) {
      return <String, DateTime>{};
    }
  }

  String _encode() {
    final serializable = _unlockedAt.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    );
    return jsonEncode(serializable);
  }

  void _onSourceChanged() {
    unawaited(checkForNewUnlocks());
  }

  /// Current progress for every badge in [BadgeDefinition.all], in
  /// catalog order.
  List<BadgeProgress> allProgress() {
    return [
      for (final definition in BadgeDefinition.all) _progressFor(definition),
    ];
  }

  /// Live progress/unlock snapshot for a single [definition], reading
  /// current stats from the source services and unlock state from
  /// the persisted map.
  BadgeProgress _progressFor(BadgeDefinition definition) {
    final current = _currentValueFor(definition.id).clamp(0, definition.goal);
    final unlockedAt = _unlockedAt[definition.id.name];
    return BadgeProgress(
      definition: definition,
      current: current,
      unlocked: unlockedAt != null,
      unlockedAt: unlockedAt,
    );
  }

  /// The live stat each badge tracks, read straight from its source
  /// service. This is the one place that maps a [BadgeId] onto the
  /// underlying tracking data, so every badge's progress bar and
  /// unlock check stay in lockstep by construction.
  int _currentValueFor(BadgeId id) {
    switch (id) {
      case BadgeId.firstWorkout:
        return _exercise.totalCompletedCount > 0 ? 1 : 0;
      case BadgeId.sevenDayStreak:
        return _streak.longestStreak(StreakKind.overall);
      case BadgeId.hydrationHero:
        return _streak.longestStreak(StreakKind.hydration);
      case BadgeId.consistentSkincare:
        return _streak.longestStreak(StreakKind.skincare);
      case BadgeId.postureChampion:
        return _reminders.totalFiredCount(ReminderKind.posture);
      case BadgeId.hundredExercises:
        return _exercise.totalCompletedCount;
    }
  }

  /// Badges unlocked since the last [acknowledgeNewlyUnlocked] call,
  /// most-recently-unlocked last. The UI should show a celebration
  /// for each of these, then call [acknowledgeNewlyUnlocked] once
  /// they've been presented so the same unlock doesn't animate twice.
  List<BadgeId> get newlyUnlocked => List.unmodifiable(_newlyUnlocked);

  /// Clears [newlyUnlocked] after the UI has finished showing
  /// celebrations for them. Does not affect persisted unlock state —
  /// only which badges are still pending a first-time celebration.
  void acknowledgeNewlyUnlocked() {
    if (_newlyUnlocked.isEmpty) return;
    _newlyUnlocked.clear();
    notifyListeners();
  }

  /// Recomputes every badge's progress and persists any that newly
  /// cross their goal. Called automatically whenever a source service
  /// changes, but also safe (and cheap, when nothing changed) to call
  /// directly after an action known to move progress.
  Future<void> checkForNewUnlocks() => _syncUnlocks(announceNew: true);

  Future<void> _syncUnlocks({required bool announceNew}) async {
    var changed = false;
    for (final definition in BadgeDefinition.all) {
      final key = definition.id.name;
      if (_unlockedAt.containsKey(key)) continue;
      final current = _currentValueFor(definition.id);
      if (current < definition.goal) continue;

      _unlockedAt[key] = DateTime.now();
      changed = true;
      if (announceNew) _newlyUnlocked.add(definition.id);
    }

    if (!changed) return;
    notifyListeners();
    await _preferences.setString(_unlockedStorageKey, _encode());
  }

  /// How many badges have been unlocked so far, out of the total
  /// catalog size. Handy for a compact "4 of 6 unlocked" summary.
  (int unlocked, int total) unlockedCount() {
    final unlocked = _unlockedAt.length;
    return (unlocked, BadgeDefinition.all.length);
  }

  @override
  void dispose() {
    _exercise.removeListener(_onSourceChanged);
    _hydration.removeListener(_onSourceChanged);
    _skincare.removeListener(_onSourceChanged);
    _reminders.removeListener(_onSourceChanged);
    super.dispose();
  }
}
