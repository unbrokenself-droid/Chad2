import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/exercise.dart';
import 'background_music_service.dart';
import 'exercise_completion_service.dart';
import 'exercise_narrator.dart';

/// Where a [WorkoutSessionManager]-driven session currently stands.
enum WorkoutSessionPhase {
  /// Showing the session overview, not yet started.
  intro,

  /// An exercise is active (may be paused). See
  /// [WorkoutSessionManager.currentExercise].
  exercise,

  /// A rest period between two exercises is active (may be paused).
  rest,

  /// Every exercise has been gone through; showing the summary.
  complete,
}

/// Drives one continuous, auto-progressing routine session — an
/// ordered queue of exercises separated by rest periods, run start to
/// finish with no manual "open the next exercise" step — for
/// [WorkoutSessionScreen].
///
/// **Owns:** the phase state machine above, which exercise is current,
/// the countdown for whichever phase is active, pause/resume, and
/// (via [_narrator] and [_music]) keeping spoken instructions and
/// background music in lockstep with that same countdown.
/// **Deliberately doesn't own:** exercise data, video playback, or
/// completion bookkeeping — those already exist
/// ([Exercise]/[ExerciseRepository], [ExerciseVideoPreview],
/// [ExerciseCompletionService]) and this reads through them rather
/// than re-implementing any piece — completion via [_completion] (the
/// same service [GuidedSessionScreen] and the Exercises tab already
/// use), spoken instructions via [_narrator] (the same
/// [ExerciseNarrator] [ExerciseNarrationControls] already uses — see
/// its own doc comment for why that's an interface, not a concrete
/// TTS dependency), background music via [_music] (the same
/// [BackgroundMusicService] instance for the app's whole lifetime,
/// not recreated per session the way this manager itself is), and
/// video by [WorkoutExerciseView] simply passing [currentExercise] to
/// the very same [ExerciseVideoPreview] used elsewhere, now with its
/// [ExerciseVideoPreview.paused] parameter wired to [paused].
///
/// [narrationEnabled] is captured once at construction rather than
/// read live from [NarrationSettingsService] — [WorkoutSessionScreen]
/// reads that service itself and passes the value in, the same way it
/// resolves [ExerciseNarrator] and [BackgroundMusicService] from their
/// own scopes before constructing this. That keeps this manager's own
/// dependency list to exactly the two audio *players* it coordinates,
/// not the settings services that configure them — [_music] doesn't
/// take a settings dependency either, for the same reason; both
/// services already read their own persisted preferences internally.
///
/// One instance is created per session (by [WorkoutSessionScreen], not
/// `main.dart`) and discarded when the session ends — unlike the
/// app's other services, there's no persisted state here to reload
/// across restarts; a session that's interrupted (app closed, session
/// exited) just doesn't resume.
class WorkoutSessionManager extends ChangeNotifier {
  WorkoutSessionManager({
    required List<Exercise> exercises,
    required ExerciseCompletionService completion,
    required ExerciseNarrator narrator,
    required BackgroundMusicService music,
    this.narrationEnabled = true,
    this.restDuration = const Duration(seconds: 20),
  }) : assert(exercises.isNotEmpty, 'A session needs at least one exercise'),
       _exercises = List.unmodifiable(exercises),
       _completion = completion,
       _narrator = narrator,
       _music = music;

  final List<Exercise> _exercises;
  final ExerciseCompletionService _completion;
  final ExerciseNarrator _narrator;
  final BackgroundMusicService _music;

  /// Whether [_narrator] should actually speak during this session —
  /// the "Voice Guide" toggle's value at the moment the session
  /// started (see this class's doc comment for why it's captured
  /// once rather than read live). When `false`, [_loadAndPlayNarration]
  /// never calls [ExerciseNarrator.loadExercise]/[ExerciseNarrator.play]
  /// at all, rather than loading narration that would just never be
  /// triggered to speak.
  final bool narrationEnabled;

  /// How long the rest period between two consecutive exercises lasts
  /// by default — [extendRest] can lengthen an in-progress one beyond
  /// this. There's no rest after the final exercise; the session goes
  /// straight to [WorkoutSessionPhase.complete] instead.
  final Duration restDuration;

  WorkoutSessionPhase _phase = WorkoutSessionPhase.intro;
  int _exerciseIndex = 0;
  Duration _remaining = Duration.zero;
  bool _paused = false;
  Timer? _ticker;
  DateTime? _startedAt;
  DateTime? _endedAt;
  final List<String> _completedExerciseIds = [];

  /// Set by [exitSession] or [dispose] — either way, this session is
  /// over. Checked by [_loadAndPlayNarration] after its one `await`,
  /// so a narration load that was still in flight when the user
  /// exited doesn't go on to call [ExerciseNarrator.play] on a
  /// narrator this manager has already told to stop.
  bool _ending = false;

  // ---- Read-only state ----------------------------------------------

  WorkoutSessionPhase get phase => _phase;

  /// The full ordered exercise queue for this session, exactly as
  /// constructed — unaffected by progress through it.
  List<Exercise> get exercises => _exercises;

  int get exerciseCount => _exercises.length;

  /// 0-based index of [currentExercise] within [exercises].
  int get exerciseIndex => _exerciseIndex;

  /// The exercise the [exercise] or [rest] phase is currently on (for
  /// [WorkoutSessionPhase.rest], this is the exercise that just
  /// finished — [upcomingExercise] is the one the rest is leading
  /// into).
  Exercise get currentExercise => _exercises[_exerciseIndex];

  /// The exercise that will start once the current rest period ends,
  /// or once the current exercise finishes — `null` only when
  /// [currentExercise] is the last one in the queue.
  Exercise? get upcomingExercise => _exerciseIndex + 1 < _exercises.length
      ? _exercises[_exerciseIndex + 1]
      : null;

  /// Time left in whichever phase is active. Meaningless (but always
  /// [Duration.zero]) during [WorkoutSessionPhase.intro] and
  /// [WorkoutSessionPhase.complete].
  Duration get remaining => _remaining;

  bool get paused => _paused;

  /// Ids of every exercise actually credited as completed so far this
  /// session — see [skip] vs [next] for which actions do and don't
  /// add to this.
  List<String> get completedExerciseIds =>
      List.unmodifiable(_completedExerciseIds);

  /// Wall-clock time since [start] was called, frozen at whatever it
  /// was the moment the session reached [WorkoutSessionPhase.complete]
  /// rather than continuing to climb after the fact. [Duration.zero]
  /// before [start].
  Duration get elapsed {
    final startedAt = _startedAt;
    if (startedAt == null) return Duration.zero;
    return (_endedAt ?? DateTime.now()).difference(startedAt);
  }

  /// The whole session's planned length: every exercise's own
  /// duration plus one [restDuration] between each consecutive pair.
  /// An estimate fixed at construction time, not a live figure —
  /// [extendRest] and skipping around don't change it, which is what
  /// makes it useful as a stable denominator for [overallProgress] and
  /// [estimatedRemaining] rather than a moving target.
  Duration get plannedDuration {
    final exerciseTotal = _exercises.fold<Duration>(
      Duration.zero,
      (sum, exercise) => sum + exercise.duration,
    );
    final restTotal = _exercises.length < 2
        ? Duration.zero
        : restDuration * (_exercises.length - 1);
    return exerciseTotal + restTotal;
  }

  /// Best-effort time remaining in the session: whatever's left of the
  /// current phase, plus every exercise and rest period still ahead.
  /// Drifts from reality exactly as much as the session itself does
  /// (skips shorten it, [extendRest] lengthens it) — an estimate for
  /// display, not a countdown target of its own.
  Duration get estimatedRemaining {
    if (_phase == WorkoutSessionPhase.complete) return Duration.zero;
    if (_phase == WorkoutSessionPhase.intro) return plannedDuration;

    var total = _remaining;
    for (var i = _exerciseIndex + 1; i < _exercises.length; i++) {
      total += restDuration + _exercises[i].duration;
    }
    return total;
  }

  /// 0.0–1.0 across the *whole* session, crediting partial progress
  /// through the current exercise or rest rather than jumping in
  /// whole-exercise increments.
  double get overallProgress {
    if (_phase == WorkoutSessionPhase.complete) return 1.0;
    if (_phase == WorkoutSessionPhase.intro) return 0.0;

    final totalMs = plannedDuration.inMilliseconds;
    if (totalMs <= 0) return 0.0;

    var doneBefore = Duration.zero;
    for (var i = 0; i < _exerciseIndex; i++) {
      doneBefore += _exercises[i].duration + restDuration;
    }
    if (_phase == WorkoutSessionPhase.rest) {
      doneBefore += currentExercise.duration;
    }
    final currentItemTotal = _phase == WorkoutSessionPhase.exercise
        ? currentExercise.duration
        : restDuration;
    final currentItemDone = currentItemTotal - _remaining;

    final doneMs = (doneBefore + currentItemDone).inMilliseconds;
    return (doneMs / totalMs).clamp(0.0, 1.0).toDouble();
  }

  // ---- Lifecycle ------------------------------------------------------

  /// Begins the session: exercise 1 of [exerciseCount], counting from
  /// now, with background music starting alongside it. No-op if the
  /// session has already been started.
  void start() {
    if (_phase != WorkoutSessionPhase.intro) return;
    _startedAt = DateTime.now();
    _exerciseIndex = 0;
    unawaited(_music.play());
    _enterExercise();
  }

  void _enterExercise() {
    _phase = WorkoutSessionPhase.exercise;
    _remaining = currentExercise.duration;
    _paused = false;
    unawaited(_loadAndPlayNarration());
    _startTicker();
    notifyListeners();
  }

  Future<void> _loadAndPlayNarration() async {
    if (!narrationEnabled) return;
    final phaseWhenStarted = _phase;
    final indexWhenStarted = _exerciseIndex;
    await _narrator.loadExercise(currentExercise);
    // The session can be paused, skipped past, or exited entirely
    // while loadExercise (an awaited platform-channel call) is still
    // in flight — this state was captured/committed-to *before* that
    // await, so it has to be re-checked now, right before actually
    // calling play(), rather than trusted as still current. Playing
    // now would be wrong in any of these cases: paused means silence
    // was the whole point; a changed phase/index means whatever's
    // current has already started its own narration (or has none to
    // start, mid-rest); _ending means nothing should start at all.
    if (_ending || _paused) return;
    if (_phase != phaseWhenStarted || _exerciseIndex != indexWhenStarted) {
      return;
    }
    await _narrator.play();
  }

  void _enterRest() {
    _phase = WorkoutSessionPhase.rest;
    _remaining = restDuration;
    _paused = false;
    // _music is deliberately left alone here: background music plays
    // continuously for the whole session regardless of phase, unlike
    // _narrator, which is specific to whichever exercise is active
    // and has nothing to say during a rest period.
    unawaited(_narrator.stop());
    _startTicker();
    notifyListeners();
  }

  void _enterComplete() {
    _ticker?.cancel();
    _phase = WorkoutSessionPhase.complete;
    _endedAt = DateTime.now();
    unawaited(_narrator.stop());
    unawaited(_music.stop());
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_paused) return;
      final next = _remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        _remaining = Duration.zero;
        _advance(creditCompletion: true);
      } else {
        _remaining = next;
        notifyListeners();
      }
    });
  }

  /// Moves past whichever phase is currently active:
  /// [WorkoutSessionPhase.exercise] leads to a rest period (or
  /// straight to [WorkoutSessionPhase.complete] if that was the last
  /// exercise); [WorkoutSessionPhase.rest] always leads to the next
  /// exercise. Only credits the exercise just finished as completed
  /// when [creditCompletion] is true — the ticker reaching zero and
  /// [next] both pass true; [skip] passes false, matching
  /// [GuidedSessionScreen]'s existing precedent that skipping an
  /// exercise doesn't count as completing it.
  void _advance({required bool creditCompletion}) {
    _ticker?.cancel();
    if (_phase == WorkoutSessionPhase.exercise) {
      if (creditCompletion) _markCurrentExerciseCompleted();
      if (_exerciseIndex >= _exercises.length - 1) {
        _enterComplete();
      } else {
        _enterRest();
      }
    } else {
      _exerciseIndex++;
      _enterExercise();
    }
  }

  void _markCurrentExerciseCompleted() {
    final id = currentExercise.id;
    if (_completedExerciseIds.contains(id)) return;
    _completedExerciseIds.add(id);
    unawaited(_completion.markCompleted(id));
  }

  // ---- Controls ---------------------------------------------------------

  /// Pauses the countdown, video (via [WorkoutExerciseView] reading
  /// [paused]), narration, and background music together. No-op
  /// outside [WorkoutSessionPhase.exercise]/[WorkoutSessionPhase.rest],
  /// or if already paused.
  void pause() {
    if (_phase != WorkoutSessionPhase.exercise &&
        _phase != WorkoutSessionPhase.rest) {
      return;
    }
    if (_paused) return;
    _paused = true;
    if (_phase == WorkoutSessionPhase.exercise) unawaited(_narrator.pause());
    unawaited(_music.pause());
    notifyListeners();
  }

  /// Resumes exactly where [pause] left off. No-op unless currently
  /// paused.
  void resume() {
    if (!_paused) return;
    _paused = false;
    if (_phase == WorkoutSessionPhase.exercise) unawaited(_narrator.resume());
    unawaited(_music.resume());
    notifyListeners();
  }

  /// Ends the current exercise or rest period early, exactly as if its
  /// countdown had reached zero — including *not* crediting the
  /// exercise as completed, if one was active (see [_advance]'s doc
  /// comment for why). Used by both the exercise view's "Skip" and the
  /// rest view's "Skip Rest", which are the same action from this
  /// manager's point of view. No-op outside
  /// [WorkoutSessionPhase.exercise]/[WorkoutSessionPhase.rest].
  void skip() {
    if (_phase != WorkoutSessionPhase.exercise &&
        _phase != WorkoutSessionPhase.rest) {
      return;
    }
    _advance(creditCompletion: false);
  }

  /// Re-enters the previous exercise from its own beginning — a fresh
  /// countdown, not a resume of wherever it was left off, and without
  /// re-crediting completion if it was already credited (see
  /// [_markCurrentExerciseCompleted]'s idempotency). No-op outside
  /// [WorkoutSessionPhase.exercise], or already on the first exercise
  /// (there is no rest period *before* the first exercise to step back
  /// into either).
  void previous() {
    if (_phase != WorkoutSessionPhase.exercise || _exerciseIndex == 0) return;
    _ticker?.cancel();
    _exerciseIndex--;
    _enterExercise();
  }

  /// Moves straight to the next exercise, bypassing the rest period
  /// that would normally sit between them — distinct from [skip],
  /// which still stops at rest. Credits the exercise being left as
  /// completed, since choosing to move on reads as "I'm done with
  /// this one" rather than "skip this one" (see [_advance]'s doc
  /// comment). No-op outside [WorkoutSessionPhase.exercise].
  void next() {
    if (_phase != WorkoutSessionPhase.exercise) return;
    _ticker?.cancel();
    _markCurrentExerciseCompleted();
    if (_exerciseIndex >= _exercises.length - 1) {
      _enterComplete();
      return;
    }
    _exerciseIndex++;
    _enterExercise();
  }

  /// Adds [extra] to an in-progress rest countdown. No-op outside
  /// [WorkoutSessionPhase.rest].
  void extendRest([Duration extra = const Duration(seconds: 15)]) {
    if (_phase != WorkoutSessionPhase.rest) return;
    _remaining += extra;
    notifyListeners();
  }

  /// Stops the countdown, narration, and background music in place,
  /// without changing [phase] — [WorkoutSessionScreen] calls this
  /// once, right before popping itself, for a user-initiated "Exit
  /// Session"; it doesn't navigate anywhere itself.
  void exitSession() {
    _ending = true;
    _ticker?.cancel();
    unawaited(_narrator.stop());
    unawaited(_music.stop());
  }

  @override
  void dispose() {
    _ending = true;
    _ticker?.cancel();
    unawaited(_narrator.stop());
    unawaited(_music.stop());
    super.dispose();
  }
}
