import 'dart:async';

import 'package:flutter/material.dart';

import '../data/exercise_demonstrations.dart';
import '../models/exercise.dart';
import '../services/analytics_service.dart';
import '../services/background_music_scope.dart';
import '../services/background_music_service.dart';
import '../services/completion_scope.dart';
import '../services/exercise_narrator.dart';
import '../services/exercise_narrator_scope.dart';
import '../services/narration_settings_scope.dart';
import '../services/telemetry_scope.dart';
import '../utils/app_haptics.dart';
import '../widgets/exercises/exercise_card.dart' show formatExerciseDuration;
import '../widgets/exercises/exercise_demonstration_view.dart';
import '../widgets/exercises/exercise_video_preview.dart';
import '../widgets/shared/primary_button.dart';

/// The stage of a guided session, in order.
enum _SessionStage {
  /// Showing the exercise's instructions before starting the timer.
  instructions,

  /// A brief "get ready" countdown (3, 2, 1) before the main timer
  /// starts running.
  countdown,

  /// The main exercise timer is active (may be paused).
  running,

  /// The exercise was completed (timer ran out) or skipped.
  finished,
}

/// Full-screen guided walkthrough for performing a single [Exercise]:
/// instructions, a "get ready" countdown, a running timer with
/// pause/resume/skip, and a finish screen. Marks the exercise
/// complete for today via [CompletionScope] once finished.
///
/// The running timer shows [ExerciseVideoPreview] (paused in step with
/// the timer via [_RunningView.paused]) for exercises that have one —
/// the large majority of the catalog — with the current instruction
/// advancing underneath it as the timer progresses, exactly like
/// [ExerciseNarrationControls] and [WorkoutSessionScreen]'s own
/// exercise view read from the same [Exercise.videoAsset] and
/// [Exercise.instructions]. Exercises without a video fall back to
/// [ExerciseDemonstrationView]'s abstract animated shape where one's
/// defined in `exerciseDemonstrations` (five, as a proof of concept —
/// see that file's doc comment), and to the original static icon
/// otherwise.
///
/// Spoken instructions and background music both start the moment the
/// running timer does, and pause/resume/stop in lockstep with it —
/// the same [ExerciseNarrator] and [BackgroundMusicService] instances
/// [WorkoutSessionManager] coordinates for a full routine session,
/// just driven directly by this screen's own stage transitions
/// instead of through that manager, since a single exercise has no
/// queue or rest periods for a manager to coordinate. Narration is
/// skipped entirely (never loaded or played at all) when the "Voice
/// Guide" toggle is off — read once when the running stage begins,
/// the same "captured at start, not live" choice
/// [WorkoutSessionManager] makes for the same setting, and for the
/// same reason: so toggling it mid-exercise doesn't do anything
/// surprising to a narration that's already partway through a
/// sentence.
///
/// Pushed from [ExerciseDetailsScreen] when the user taps "Start".
class GuidedSessionScreen extends StatefulWidget {
  const GuidedSessionScreen({super.key, required this.exercise});

  final Exercise exercise;

  @override
  State<GuidedSessionScreen> createState() => _GuidedSessionScreenState();
}

class _GuidedSessionScreenState extends State<GuidedSessionScreen>
    with SingleTickerProviderStateMixin {
  static const _countdownSeconds = 3;

  _SessionStage _stage = _SessionStage.instructions;
  bool _paused = false;
  bool _wasSkipped = false;

  int _countdownRemaining = _countdownSeconds;
  late Duration _remaining;

  Timer? _ticker;

  late final AnimationController _pulseController;

  // Resolved once, in didChangeDependencies — see that method and
  // this class's own doc comment for why narrationEnabled is cached
  // rather than read fresh every time it's needed.
  ExerciseNarrator? _narrator;
  BackgroundMusicService? _music;
  bool _narrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _remaining = widget.exercise.duration;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resolved once (the null check on _narrator guards repeat runs —
    // didChangeDependencies fires again for any dependency change,
    // not just the first): an InheritedWidget lookup like these
    // isn't safe from initState, since the widget isn't fully
    // inserted into the tree yet at that point.
    if (_narrator == null) {
      _narrator = ExerciseNarratorScope.of(context);
      _music = BackgroundMusicScope.of(context);
      _narrationEnabled = NarrationSettingsScope.of(context).narrationEnabled;
    }
    // Only start the repeating pulse when motion isn't reduced; a
    // static ring is just as informative without the distraction.
    if (!MediaQuery.of(context).disableAnimations &&
        !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseController.dispose();
    unawaited(_narrator?.stop());
    unawaited(_music?.stop());
    super.dispose();
  }

  // ---- Stage transitions -------------------------------------------------

  void _beginCountdown() {
    AppHaptics.medium();
    setState(() {
      _stage = _SessionStage.countdown;
      _countdownRemaining = _countdownSeconds;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdownRemaining--;
      });
      if (_countdownRemaining <= 0) {
        timer.cancel();
        _beginRunning();
      } else {
        AppHaptics.light();
      }
    });
  }

  void _beginRunning() {
    AppHaptics.heavy();
    setState(() {
      _stage = _SessionStage.running;
      _paused = false;
    });
    _startTicker();
    unawaited(_music?.play());
    if (_narrationEnabled) {
      unawaited(_playNarration());
    }
    // Logged here rather than on the instructions screen: this is the
    // point the user actually committed to doing the exercise, so
    // start/finish rates compare like with like.
    TelemetryScope.of(context).logEvent(
      AnalyticsEvent.routineSessionStarted(
        exerciseCategory: widget.exercise.category.name,
        difficulty: widget.exercise.difficulty.name,
      ),
    );
  }

  Future<void> _playNarration() async {
    final narrator = _narrator;
    if (narrator == null) return;
    await narrator.loadExercise(widget.exercise);
    // The session can be paused, skipped, or finished entirely while
    // loadExercise (an awaited platform-channel call) is still in
    // flight — re-checked here, right before actually calling play(),
    // rather than trusted as still current from when this function
    // was first called. The same race, and the same fix, as
    // WorkoutSessionManager's own _loadAndPlayNarration — see that
    // method's doc comment for the fuller explanation of why playing
    // now would be wrong in either case: paused means silence was the
    // point, and a stage that's moved past running means there's
    // nothing current left to narrate.
    if (!mounted || _paused || _stage != _SessionStage.running) return;
    await narrator.play();
  }

  /// Pauses spoken instructions and background music together —
  /// called both from [_togglePause] and, around the "End session?"
  /// dialog, from [_confirmExit].
  void _pauseAudio() {
    unawaited(_narrator?.pause());
    unawaited(_music?.pause());
  }

  /// Resumes exactly where [_pauseAudio] left off.
  void _resumeAudio() {
    unawaited(_narrator?.resume());
    unawaited(_music?.resume());
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_paused) return;
      final next = _remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        timer.cancel();
        setState(() => _remaining = Duration.zero);
        _finish(skipped: false);
      } else {
        setState(() => _remaining = next);
      }
    });
  }

  void _togglePause() {
    AppHaptics.selection();
    final willBePaused = !_paused;
    setState(() => _paused = willBePaused);
    if (willBePaused) {
      _pauseAudio();
    } else {
      _resumeAudio();
    }
  }

  void _skip() {
    AppHaptics.medium();
    _ticker?.cancel();
    _finish(skipped: true);
  }

  void _finish({required bool skipped}) {
    _ticker?.cancel();
    AppHaptics.heavy();
    unawaited(_narrator?.stop());
    unawaited(_music?.stop());
    setState(() {
      _stage = _SessionStage.finished;
      _wasSkipped = skipped;
    });
    if (!skipped) {
      // Only a fully-run session counts as completing the exercise;
      // a skip ends the session without crediting it.
      CompletionScope.of(context).markCompleted(widget.exercise.id);
    }
    TelemetryScope.of(context).logEvent(
      AnalyticsEvent.routineSessionFinished(
        exerciseCategory: widget.exercise.category.name,
        completed: !skipped,
        // How far they actually got, which is the useful part of a
        // skip — bailing at 5 seconds and bailing at 55 mean very
        // different things about the exercise's duration.
        elapsedSeconds:
            widget.exercise.duration.inSeconds - _remaining.inSeconds,
      ),
    );
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stage == _SessionStage.instructions ||
          _stage == _SessionStage.finished,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.exercise.title),
          leading: _stage == _SessionStage.running ||
                  _stage == _SessionStage.countdown
              ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'End session',
                  onPressed: () => _confirmExit(context),
                )
              : null,
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_stage),
              child: switch (_stage) {
                _SessionStage.instructions => _InstructionsView(
                    key: const ValueKey('instructions'),
                    exercise: widget.exercise,
                    onStart: _beginCountdown,
                  ),
                _SessionStage.countdown => _CountdownView(
                    key: const ValueKey('countdown'),
                    remaining: _countdownRemaining,
                  ),
                _SessionStage.running => _RunningView(
                    key: const ValueKey('running'),
                    exercise: widget.exercise,
                    remaining: _remaining,
                    paused: _paused,
                    pulseController: _pulseController,
                    onTogglePause: _togglePause,
                    onSkip: _skip,
                  ),
                _SessionStage.finished => _FinishedView(
                    key: const ValueKey('finished'),
                    exercise: widget.exercise,
                    skipped: _wasSkipped,
                    onDone: () => Navigator.of(context).pop(),
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final wasPaused = _paused;
    setState(() => _paused = true);
    // Only pause here if the session wasn't already paused — mirrored
    // below when deciding whether to resume, so this dialog can't
    // leave audio playing under it, but also can't be the thing that
    // resumes audio the user had *already* paused before opening it.
    if (!wasPaused) _pauseAudio();
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End session?'),
        content: const Text(
          'Your progress on this exercise won\'t be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    // context.mounted, not the State's `mounted`: this method takes
    // its own BuildContext parameter, which shadows State.context, so
    // the State-level check doesn't actually guarantee *this* context
    // is still valid.
    if (!context.mounted) return;
    if (shouldExit ?? false) {
      // Not stopping audio here: popping triggers dispose(), which
      // already stops both unconditionally.
      Navigator.of(context).pop();
    } else {
      setState(() => _paused = wasPaused);
      if (!wasPaused) _resumeAudio();
    }
  }
}

// ---- Instructions stage -----------------------------------------------

class _InstructionsView extends StatelessWidget {
  const _InstructionsView({
    super.key,
    required this.exercise,
    required this.onStart,
  });

  final Exercise exercise;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      exercise.icon,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 15,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatExerciseDuration(exercise.duration),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Instructions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < exercise.instructions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            exercise.instructions[i],
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (exercise.precautions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8860B).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFB8860B).withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Color(0xFFB8860B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exercise.precautions.join(' '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SafeArea(
            top: false,
            child: PrimaryButton(
              label: 'Start',
              icon: Icons.play_arrow_rounded,
              onPressed: onStart,
            ),
          ),
        ),
      ],
    );
  }
}

// ---- Countdown stage ----------------------------------------------------

class _CountdownView extends StatelessWidget {
  const _CountdownView({super.key, required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final label = remaining > 0 ? '$remaining' : 'Go!';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Get ready',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          TweenAnimationBuilder<double>(
            key: ValueKey(remaining),
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 140,
              height: 140,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.12),
                border: Border.all(color: colorScheme.primary, width: 3),
              ),
              child: Semantics(
                liveRegion: true,
                label: remaining > 0 ? 'Starting in $remaining' : 'Go',
                child: Text(
                  label,
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Running stage --------------------------------------------------------

class _RunningView extends StatelessWidget {
  const _RunningView({
    super.key,
    required this.exercise,
    required this.remaining,
    required this.paused,
    required this.pulseController,
    required this.onTogglePause,
    required this.onSkip,
  });

  final Exercise exercise;
  final Duration remaining;
  final bool paused;
  final AnimationController pulseController;
  final VoidCallback onTogglePause;
  final VoidCallback onSkip;

  String _formatClock(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = exercise.duration.inSeconds == 0
        ? 1
        : exercise.duration.inSeconds;
    final progress = 1 - (remaining.inSeconds / total);

    // Still keyed off the old demonstration lookup for the shape
    // animation itself (see below), but the instruction text no
    // longer is: every exercise has instructions, so cycling through
    // them as the timer progresses shouldn't be limited to the 5
    // exercises exercise_demonstrations.dart happens to cover.
    final demonstration = exerciseDemonstrations[exercise.id];
    final instructions = exercise.instructions;
    final currentStep = instructions.isEmpty
        ? null
        : instructions[(progress.clamp(0.0, 1.0) * instructions.length)
              .floor()
              .clamp(0, instructions.length - 1)];
    final videoAsset = exercise.videoAsset;

    return Column(
      children: [
        Expanded(
          // A SingleChildScrollView here — rather than only Center, as
          // before — is what keeps this from overflowing a short
          // screen: most exercises now render meaningfully more
          // content (the video, the ring, instruction text) than the
          // original layout accounted for, and the handful without a
          // video but with an abstract demonstration shape instead
          // need the same safety net for the same reason.
          child: SingleChildScrollView(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (videoAsset != null) ...[
                    ExerciseVideoPreview(
                      assetPath: videoAsset,
                      paused: paused,
                    ),
                    const SizedBox(height: 20),
                  ],
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: pulseController,
                      builder: (context, child) {
                        final reduceMotion =
                            MediaQuery.of(context).disableAnimations;
                        final scale = (paused || reduceMotion)
                            ? 1.0
                            : 1.0 + (pulseController.value * 0.04);
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 220,
                              height: 220,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 0,
                                  end: progress.clamp(0, 1),
                                ),
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) {
                                  return CircularProgressIndicator(
                                    value: value,
                                    strokeWidth: 10,
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation(
                                      colorScheme.primary,
                                    ),
                                  );
                                },
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  exercise.icon,
                                  size: 32,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(height: 8),
                                Semantics(
                                  label:
                                      '${remaining.inMinutes} minutes ${remaining.inSeconds % 60} seconds remaining',
                                  excludeSemantics: true,
                                  child: Text(
                                    _formatClock(remaining),
                                    style: theme.textTheme.displaySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (videoAsset == null && demonstration != null) ...[
                    ExerciseDemonstrationView(
                      demonstration: demonstration,
                      color: colorScheme.primary,
                      paused: paused,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          paused ? 'Paused' : (currentStep ?? exercise.title),
                          key: ValueKey(
                            paused ? 'paused' : (currentStep ?? exercise.title),
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: paused
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSkip,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Skip'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: paused ? 'Resume' : 'Pause',
                    icon: paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    onPressed: onTogglePause,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---- Finished stage -------------------------------------------------------

class _FinishedView extends StatelessWidget {
  const _FinishedView({
    super.key,
    required this.exercise,
    required this.skipped,
    required this.onDone,
  });

  final Exercise exercise;
  final bool skipped;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1.0),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: (skipped ? colorScheme.outline : Colors.green)
                          .withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      skipped ? Icons.skip_next_rounded : Icons.check_rounded,
                      size: 52,
                      color: skipped ? colorScheme.outline : Colors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  skipped ? 'Session skipped' : 'Nice work!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  skipped
                      ? '"${exercise.title}" wasn\'t marked complete.'
                      : '"${exercise.title}" is marked complete for today.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SafeArea(
            top: false,
            child: PrimaryButton(
              label: 'Done',
              icon: Icons.arrow_forward_rounded,
              onPressed: onDone,
            ),
          ),
        ),
      ],
    );
  }
}
