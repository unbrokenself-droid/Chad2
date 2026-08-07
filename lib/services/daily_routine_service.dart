import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise.dart';
import 'onboarding_service.dart';
import 'personalization_service.dart';

/// How many exercises [DailyRoutineService] selects from *each*
/// [ExerciseCategory] — the only thing that changes between
/// difficulty levels. Every level always covers every category in
/// [ExerciseCategory.values]; a harder routine has more exercises
/// within each one, never more or fewer categories. See
/// [DailyRoutineService]'s class doc comment for the full reasoning.
enum RoutineDifficulty {
  beginner('Beginner', 2),
  intermediate('Intermediate', 3),
  advanced('Advanced', 4);

  const RoutineDifficulty(this.label, this.exercisesPerCategory);

  /// Shown on [RoutineDifficultySheet]'s option rows.
  final String label;

  /// How many exercises [DailyRoutineService] picks from each
  /// category at this level.
  final int exercisesPerCategory;

  /// The [ExerciseDifficulty] this level prefers when picking
  /// exercises within a category — matched by declaration order
  /// (both enums go beginner → intermediate → advanced), so a change
  /// to one only needs a matching change to the other, not a new
  /// mapping table.
  ExerciseDifficulty get exerciseDifficulty =>
      ExerciseDifficulty.values[index];
}

/// Generates and persists a single **ordered, flat** routine per
/// calendar day, covering every [ExerciseCategory] at a
/// user-adjustable [RoutineDifficulty].
///
/// **One list, not one-per-category.** Earlier versions of this
/// service picked exactly one exercise per category and
/// [RoutineScreen] displayed the result grouped into a section per
/// category — which read as several small checklists rather than one
/// workout. Both are gone: [todayExerciseIds] is a single ordered
/// list start-to-finish, [RoutineScreen] renders it as one continuous
/// list, and [WorkoutSessionScreen] runs it as one continuous guided
/// session. [Exercise.category] still exists and still drives
/// *selection* below — it's just no longer used to group anything in
/// the UI.
///
/// **Difficulty changes volume, not which categories show up.** Every
/// generated routine, at every [RoutineDifficulty], always includes
/// every category in [ExerciseCategory.values] — what changes is
/// [RoutineDifficulty.exercisesPerCategory] (2/3/4) and which
/// [ExerciseDifficulty] is preferred within each category. This
/// replaces the old `adjustDifficulty`, which changed how *many*
/// exercises were in the routine by adding/removing individual ones
/// without any guarantee every category stayed represented — asking
/// for "much easier" repeatedly could and eventually would drop a
/// category to zero. [setDifficulty] can't do that: shrinking from
/// advanced to beginner still leaves 2 exercises in every category,
/// never 0.
///
/// **Rotation.** [_recentExerciseIds] remembers the exercise ids from
/// the *previous* routine generated (regardless of exactly how long
/// ago, so it survives across a rest day or a skipped day) and
/// [_generate] prefers not repeating them within a category that has
/// another option — so two consecutive routines don't pick the exact
/// same jaw exercise twice in a row purely by chance, without needing
/// to track a longer history than "what was here immediately before
/// this."
///
/// The routine is deterministic for a given day, difficulty, and
/// catalog — seeded from the date (and, for [setDifficulty], the
/// chosen level too) rather than [Random]'s default entropy source —
/// so regenerating it (e.g. after an app restart, before persistence
/// loads) reliably reproduces the same picks rather than reshuffling.
/// It only changes when the calendar day changes, the difficulty
/// changes, or the underlying catalog does.
///
/// Persisted via [SharedPreferences]: the routine itself as a
/// JSON-encoded record of the date and exercise ids (same as before),
/// the chosen [RoutineDifficulty] as a separate sticky preference (it
/// carries forward day to day until explicitly changed, not reset
/// each morning), and [_recentExerciseIds] as a third small record for
/// the rotation check above. A [ChangeNotifier] so every screen
/// showing today's routine (the Routine tab, Home's dashboard card)
/// stays in sync the moment it's (re)generated.
class DailyRoutineService extends ChangeNotifier {
  DailyRoutineService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _storageKey = 'daily_routine';
  static const String _difficultyStorageKey = 'daily_routine_difficulty';
  static const String _recentStorageKey = 'daily_routine_recent_ids';
  static const String _sessionSummaryStorageKey =
      'daily_routine_session_summary';

  final SharedPreferencesAsync _preferences;

  /// The `'yyyy-MM-dd'` key of the day [_exerciseIds] was generated
  /// for, or `null` before anything has loaded/generated yet.
  String? _dateKey;

  /// Today's routine, in the exact order it should be displayed and
  /// run. Empty until a routine has been generated (e.g. the catalog
  /// hadn't loaded yet).
  List<String> _exerciseIds = const [];

  RoutineDifficulty _difficulty = RoutineDifficulty.beginner;

  /// Whether [_difficulty] has ever actually been loaded from or
  /// written to storage. While this is `false`, [ensureTodayRoutine]
  /// still owes it a one-time default derived from the user's
  /// onboarding [ExperienceLevel] — see that method.
  bool _difficultyResolved = false;

  /// Exercise ids from the previous routine generated before the
  /// current one — see this class's doc comment's "Rotation" section.
  Set<String> _recentExerciseIds = const {};

  bool _loaded = false;

  /// A snapshot of today's session, if it's been completed — see
  /// [recordSessionCompleted]. `null` before completion, and reset
  /// back to `null` whenever today's routine itself is regenerated
  /// (a difficulty change starts a fresh, not-yet-completed routine,
  /// so any earlier summary no longer describes what's actually on
  /// screen).
  RoutineSessionSummary? _sessionSummary;

  /// Whether this service has finished its initial load attempt.
  /// Screens can use this to distinguish "nothing generated yet
  /// because we're still starting up" from "genuinely empty".
  bool get isLoaded => _loaded;

  /// Today's routine's exercise ids, in display/session order. Empty
  /// if nothing has been generated yet for today.
  List<String> get todayExerciseIds => List.unmodifiable(_exerciseIds);

  /// The difficulty today's routine was generated at (and the one a
  /// future routine will use, until [setDifficulty] changes it).
  RoutineDifficulty get difficulty => _difficulty;

  /// A snapshot of today's session if it's been completed — see
  /// [recordSessionCompleted]. `null` if today's routine hasn't been
  /// finished yet (or hasn't been generated at all).
  RoutineSessionSummary? get todaySessionSummary => _sessionSummary;

  static String _keyFor(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Loads any routine, difficulty, and rotation history persisted
  /// for today from disk. If the stored routine is for a different
  /// day (or nothing is stored yet), the in-memory routine stays
  /// empty — call [ensureTodayRoutine] with the current catalog to
  /// generate and persist one.
  ///
  /// Safe to call more than once; subsequent calls just re-sync from
  /// storage.
  Future<void> load() async {
    final todayKey = _keyFor(DateTime.now());
    final stored = await _preferences.getString(_storageKey);
    final decoded = _decode(stored);

    final storedDifficultyName = await _preferences.getString(
      _difficultyStorageKey,
    );
    if (storedDifficultyName != null) {
      _difficulty = RoutineDifficulty.values.firstWhere(
        (level) => level.name == storedDifficultyName,
        orElse: () => RoutineDifficulty.beginner,
      );
      _difficultyResolved = true;
    }

    final storedRecent = await _preferences.getString(_recentStorageKey);
    _recentExerciseIds = _decodeRecent(storedRecent);

    final storedSummary = await _preferences.getString(
      _sessionSummaryStorageKey,
    );
    final decodedSummary = RoutineSessionSummary._decode(storedSummary);
    // Only keep it if it's actually for today — a summary from a
    // previous day is stale the moment the calendar rolls over, same
    // as the routine itself.
    _sessionSummary =
        decodedSummary != null && _keyFor(decodedSummary.completedAt) == todayKey
        ? decodedSummary
        : null;

    if (decoded != null && decoded.dateKey == todayKey) {
      _dateKey = decoded.dateKey;
      _exerciseIds = decoded.exerciseIds;
    } else {
      // Either nothing was stored, it was corrupt, or it's a stale
      // routine from a previous day — either way today doesn't have
      // one yet.
      _dateKey = null;
      _exerciseIds = const [];
    }
    _loaded = true;
    notifyListeners();
  }

  static ({String dateKey, List<String> exerciseIds})? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final dateKey = decoded['date'] as String;
      final ids = List<String>.from(decoded['exerciseIds'] as List);
      return (dateKey: dateKey, exerciseIds: ids);
    } catch (_) {
      // Corrupt or unexpected stored data shouldn't crash the app;
      // treat it as if nothing were stored.
      return null;
    }
  }

  static Set<String> _decodeRecent(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw) as List;
      return Set<String>.from(decoded);
    } catch (_) {
      return const {};
    }
  }

  Future<void> _persist() async {
    final dateKey = _dateKey;
    if (dateKey == null) return;
    final encoded = jsonEncode({'date': dateKey, 'exerciseIds': _exerciseIds});
    await _preferences.setString(_storageKey, encoded);
  }

  Future<void> _persistRecent() async {
    await _preferences.setString(
      _recentStorageKey,
      jsonEncode(_recentExerciseIds.toList()),
    );
  }

  /// Whether today already has a generated routine in memory.
  bool get hasTodayRoutine =>
      _dateKey == _keyFor(DateTime.now()) && _exerciseIds.isNotEmpty;

  /// Records that today's routine session finished — called once, by
  /// [WorkoutSessionScreen], the moment its [WorkoutSessionManager]
  /// reaches [WorkoutSessionPhase.complete]. [RoutineScreen] reads
  /// [todaySessionSummary] afterward to show its completion dashboard
  /// instead of the exercise list, even if the app was closed and
  /// reopened since the session actually finished.
  Future<void> recordSessionCompleted({
    required Duration duration,
    required int exerciseCount,
    required int wellnessScore,
  }) async {
    _sessionSummary = RoutineSessionSummary(
      completedAt: DateTime.now(),
      duration: duration,
      exerciseCount: exerciseCount,
      wellnessScore: wellnessScore,
    );
    notifyListeners();
    await _preferences.setString(
      _sessionSummaryStorageKey,
      _sessionSummary!._encode(),
    );
  }

  /// Returns today's routine as full [Exercise] objects, in session
  /// order, generating and persisting a new one first if today
  /// doesn't have one yet or the stored one no longer matches the
  /// catalog (e.g. an exercise was removed).
  ///
  /// [goals] shifts which categories are prioritized *first* in the
  /// resulting order (see [PersonalizationService.categoriesFor]) —
  /// every category is still included regardless of [goals], since
  /// that prioritization only affects order, not inclusion.
  /// [experienceLevel] is only consulted the very first time this
  /// service ever resolves a difficulty (i.e. a fresh install, before
  /// [setDifficulty] has ever been called) — after that, whatever
  /// difficulty was last set (via [setDifficulty] or that one-time
  /// default) persists on its own, independent of the onboarding
  /// answer that originally seeded it.
  ///
  /// Call this once the catalog has loaded — from a screen's
  /// `initState`/first build is fine, since generation is cheap and
  /// this is a no-op once today's routine already exists and is
  /// still valid.
  Future<List<Exercise>> ensureTodayRoutine({
    required List<Exercise> catalog,
    required Set<OnboardingGoal> goals,
    ExperienceLevel? experienceLevel,
    PersonalizationService personalization = const PersonalizationService(),
  }) async {
    if (!_difficultyResolved) {
      _difficulty = _difficultyFromExperienceLevel(experienceLevel);
      _difficultyResolved = true;
      await _preferences.setString(_difficultyStorageKey, _difficulty.name);
    }

    final todayKey = _keyFor(DateTime.now());
    final catalogById = {for (final e in catalog) e.id: e};

    final alreadyValid =
        _dateKey == todayKey &&
        _exerciseIds.isNotEmpty &&
        _exerciseIds.every(catalogById.containsKey);

    if (!alreadyValid) {
      await _regenerate(
        catalog: catalog,
        goals: goals,
        seed: todayKey,
        dateKey: todayKey,
        personalization: personalization,
      );
    }

    return _resolve(catalogById);
  }

  /// Sets today's (and every future day's, until changed again)
  /// [RoutineDifficulty] and immediately regenerates today's routine
  /// to match it — every category still represented, just with
  /// [RoutineDifficulty.exercisesPerCategory] exercises in each
  /// instead of whatever the previous level had.
  Future<List<Exercise>> setDifficulty({
    required RoutineDifficulty difficulty,
    required List<Exercise> catalog,
    required Set<OnboardingGoal> goals,
    PersonalizationService personalization = const PersonalizationService(),
  }) async {
    _difficulty = difficulty;
    _difficultyResolved = true;
    await _preferences.setString(_difficultyStorageKey, difficulty.name);

    final todayKey = _keyFor(DateTime.now());
    await _regenerate(
      catalog: catalog,
      goals: goals,
      // Distinct from ensureTodayRoutine's seed so switching
      // difficulty and switching back doesn't just deterministically
      // reproduce the exact same routine both times.
      seed: '$todayKey-${difficulty.name}',
      dateKey: todayKey,
      personalization: personalization,
    );

    final catalogById = {for (final e in catalog) e.id: e};
    return _resolve(catalogById);
  }

  Future<void> _regenerate({
    required List<Exercise> catalog,
    required Set<OnboardingGoal> goals,
    required String seed,
    required String dateKey,
    required PersonalizationService personalization,
  }) async {
    final previousIds = _exerciseIds;
    _exerciseIds = _generate(
      catalog: catalog,
      goals: goals,
      difficulty: _difficulty,
      recentIds: _recentExerciseIds,
      seed: seed,
      personalization: personalization,
    );
    _dateKey = dateKey;
    // A new routine has nothing completed yet, so any earlier
    // completion summary — from whatever routine was here before —
    // no longer describes what's on screen. Cleared via an empty
    // string rather than a `.remove()` call: RoutineSessionSummary._decode
    // (like every other _decode in this file) already treats an
    // empty string the same as nothing having been stored, so this
    // reuses setString, a method already used everywhere else here,
    // instead of introducing a different one for just this one case.
    _sessionSummary = null;
    unawaited(_preferences.setString(_sessionSummaryStorageKey, ''));
    if (previousIds.isNotEmpty) {
      _recentExerciseIds = previousIds.toSet();
      unawaited(_persistRecent());
    }
    notifyListeners();
    await _persist();
  }

  List<Exercise> _resolve(Map<String, Exercise> catalogById) {
    return [
      for (final id in _exerciseIds)
        if (catalogById.containsKey(id)) catalogById[id]!,
    ];
  }

  static RoutineDifficulty _difficultyFromExperienceLevel(
    ExperienceLevel? level,
  ) {
    return switch (level) {
      ExperienceLevel.beginner || null => RoutineDifficulty.beginner,
      ExperienceLevel.intermediate => RoutineDifficulty.intermediate,
      ExperienceLevel.advanced => RoutineDifficulty.advanced,
    };
  }

  /// Removes [exerciseId] from today's routine and persists the
  /// change. No-op if it isn't currently part of today's routine.
  /// Returns the index it was removed from (or `null` if it wasn't
  /// present), so a caller offering "Undo" can restore it at the same
  /// spot via [restoreExercise].
  ///
  /// This only edits the in-memory/persisted list of ids for today;
  /// it doesn't touch the underlying catalog or any other day.
  Future<int?> removeExercise(String exerciseId) async {
    final index = _exerciseIds.indexOf(exerciseId);
    if (index == -1) return null;
    final updated = List<String>.of(_exerciseIds)..removeAt(index);
    _exerciseIds = List.unmodifiable(updated);
    notifyListeners();
    await _persist();
    return index;
  }

  /// Re-inserts [exerciseId] at [index] in today's routine and
  /// persists the change. Intended for "Undo" after [removeExercise];
  /// [index] is clamped to the current length so it stays valid even
  /// if the routine changed shape in the meantime. No-op if
  /// [exerciseId] is already part of today's routine.
  Future<void> restoreExercise(String exerciseId, int index) async {
    if (_exerciseIds.contains(exerciseId)) return;
    final updated = List<String>.of(_exerciseIds);
    updated.insert(index.clamp(0, updated.length), exerciseId);
    _exerciseIds = List.unmodifiable(updated);
    notifyListeners();
    await _persist();
  }

  /// Swaps [oldExerciseId] out of today's routine for
  /// [newExerciseId], keeping its position, and persists the change.
  ///
  /// No-op if [oldExerciseId] isn't currently part of today's
  /// routine. Callers (see [RoutineScreen]) are expected to only ever
  /// pass a [newExerciseId] from the same category as
  /// [oldExerciseId], so the routine keeps covering every category —
  /// this method doesn't itself check category, since it has no
  /// catalog to check against.
  Future<void> replaceExercise({
    required String oldExerciseId,
    required String newExerciseId,
  }) async {
    final index = _exerciseIds.indexOf(oldExerciseId);
    if (index == -1) return;
    final updated = List<String>.of(_exerciseIds);
    updated[index] = newExerciseId;
    _exerciseIds = List.unmodifiable(updated);
    notifyListeners();
    await _persist();
  }

  /// Builds one full day's routine:
  /// [RoutineDifficulty.exercisesPerCategory] exercises from *every*
  /// category in [ExerciseCategory.values], prioritized-category-first
  /// (see [PersonalizationService.categoriesFor]) but with every other
  /// category appended afterward regardless, so none are ever
  /// dropped. Deterministic for a given [seed] so the same
  /// day/difficulty/profile/catalog always yields the same picks.
  static List<String> _generate({
    required List<Exercise> catalog,
    required Set<OnboardingGoal> goals,
    required RoutineDifficulty difficulty,
    required Set<String> recentIds,
    required String seed,
    required PersonalizationService personalization,
  }) {
    final random = Random(seed.hashCode);
    final prioritized = personalization.categoriesFor(goals);
    final allCategories = [
      ...prioritized,
      for (final category in ExerciseCategory.values)
        if (!prioritized.contains(category)) category,
    ];

    final ids = <String>[];
    final usedIds = <String>{};
    for (final category in allCategories) {
      final picks = _pickForCategory(
        catalog: catalog,
        category: category,
        count: difficulty.exercisesPerCategory,
        preferredDifficulty: difficulty.exerciseDifficulty,
        recentIds: recentIds,
        usedIds: usedIds,
        random: random,
      );
      for (final exercise in picks) {
        ids.add(exercise.id);
        usedIds.add(exercise.id);
      }
    }
    return ids;
  }

  /// Picks up to [count] exercises from [category], preferring (in
  /// order): not already used elsewhere in this same routine
  /// ([usedIds]), not part of the immediately preceding routine
  /// ([recentIds], when the category has enough other options to
  /// avoid them entirely), and matching [preferredDifficulty]. Falls
  /// back gracefully at every step — a category with fewer than
  /// [count] exercises in the whole catalog just contributes what it
  /// has rather than erroring or padding with duplicates.
  static List<Exercise> _pickForCategory({
    required List<Exercise> catalog,
    required ExerciseCategory category,
    required int count,
    required ExerciseDifficulty preferredDifficulty,
    required Set<String> recentIds,
    required Set<String> usedIds,
    required Random random,
  }) {
    final inCategory =
        catalog
            .where((e) => e.category == category && !usedIds.contains(e.id))
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    if (inCategory.isEmpty) return const [];

    // Prefer exercises that weren't in the immediately preceding
    // routine, but only when doing so still leaves enough to fill
    // `count` — otherwise a small category would end up contributing
    // fewer exercises than a difficulty level actually calls for,
    // just to avoid an unavoidable repeat.
    final fresh = inCategory.where((e) => !recentIds.contains(e.id)).toList();
    final pool = fresh.length >= count ? fresh : inCategory;

    final atPreferredDifficulty =
        pool.where((e) => e.difficulty == preferredDifficulty).toList()
          ..shuffle(random);
    final everythingElse =
        pool.where((e) => e.difficulty != preferredDifficulty).toList()
          ..shuffle(random);

    return [
      ...atPreferredDifficulty,
      ...everythingElse,
    ].take(count).toList();
  }
}

/// A snapshot of how today's routine session went, captured once when
/// it finishes — see [DailyRoutineService.recordSessionCompleted] and
/// [DailyRoutineService.todaySessionSummary].
///
/// Deliberately small: just enough for
/// [RoutineScreen]'s completion dashboard to show real numbers even
/// if the app was closed and reopened since the session actually
/// finished, not a general workout-history record — [wellnessScore]
/// in particular is the score *at the moment of completion*, not a
/// stored history of every score the app has ever computed.
class RoutineSessionSummary {
  const RoutineSessionSummary({
    required this.completedAt,
    required this.duration,
    required this.exerciseCount,
    required this.wellnessScore,
  });

  final DateTime completedAt;
  final Duration duration;
  final int exerciseCount;
  final int wellnessScore;

  String _encode() {
    return jsonEncode({
      'completedAt': completedAt.toIso8601String(),
      'durationSeconds': duration.inSeconds,
      'exerciseCount': exerciseCount,
      'wellnessScore': wellnessScore,
    });
  }

  static RoutineSessionSummary? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return RoutineSessionSummary(
        completedAt: DateTime.parse(decoded['completedAt'] as String),
        duration: Duration(seconds: decoded['durationSeconds'] as int),
        exerciseCount: decoded['exerciseCount'] as int,
        wellnessScore: decoded['wellnessScore'] as int,
      );
    } catch (_) {
      // Corrupt or unexpected stored data shouldn't crash the app;
      // treat it as if nothing were stored, same as every other
      // _decode in this file.
      return null;
    }
  }
}
