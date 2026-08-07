import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../services/ads_scope.dart';
import '../services/background_music_scope.dart';
import '../services/completion_scope.dart';
import '../services/daily_routine_scope.dart';
import '../services/exercise_narrator_scope.dart';
import '../services/narration_settings_scope.dart';
import '../services/streak_scope.dart';
import '../services/streak_service.dart';
import '../services/wellness_score_scope.dart';
import '../services/workout_session_manager.dart';
import '../widgets/coach/coach_avatar.dart';
import '../widgets/exercises/exercise_card.dart' show formatExerciseDuration;
import '../widgets/exercises/exercise_video_preview.dart';
import '../widgets/routine/music_voice_sheet.dart';
import '../widgets/shared/primary_button.dart';

/// Full-screen, continuous, auto-progressing walkthrough for an
/// entire routine: [exercises] run start to finish via a
/// [WorkoutSessionManager] this screen owns, with no manual "open the
/// next exercise" step anywhere in the flow.
///
/// This is the Routine tab's equivalent of [GuidedSessionScreen] — the
/// same underlying idea (instructions/intro, a running timer,
/// pause/skip, a finish screen), extended to a whole queue of
/// exercises with rest periods between them instead of just one. See
/// [WorkoutSessionManager]'s doc comment for exactly what's reused
/// from (rather than duplicated from) the Exercises tab and
/// [GuidedSessionScreen] itself: exercise data, video, narration, and
/// completion tracking are all the same underlying pieces, just
/// orchestrated across a queue instead of a single exercise.
///
/// Pushed from [RoutineScreen] when the user taps "Start Routine".
class WorkoutSessionScreen extends StatefulWidget {
  const WorkoutSessionScreen({super.key, required this.exercises});

  /// The ordered queue for this session — today's daily routine when
  /// launched from [RoutineScreen]'s main "Today's Plan", but nothing
  /// here assumes that specifically; any non-empty exercise list
  /// works, so a "start" action on a custom routine
  /// ([CustomRoutinesScreen]) can push this exact same screen.
  final List<Exercise> exercises;

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  WorkoutSessionManager? _manager;
  int _wellnessScoreBefore = 0;

  /// Guards [DailyRoutineService.recordSessionCompleted] to exactly
  /// one call — [_onSessionChanged] fires on every manager change
  /// while the session sits in [WorkoutSessionPhase.complete] (e.g.
  /// from an unrelated rebuild), not just the instant it first
  /// arrives there.
  bool _sessionSummaryRecorded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // One-time setup gated on a null check, same reasoning as
    // ExerciseNarrationControls: ExerciseNarratorScope.of (and the
    // other scope reads below) need an InheritedWidget lookup, which
    // isn't safe from initState.
    if (_manager != null) return;
    final manager = WorkoutSessionManager(
      exercises: widget.exercises,
      completion: CompletionScope.of(context),
      narrator: ExerciseNarratorScope.of(context),
      music: BackgroundMusicScope.of(context),
      narrationEnabled: NarrationSettingsScope.of(context).narrationEnabled,
    );
    manager.addListener(_onSessionChanged);
    _manager = manager;
    // Captured once, before the session can have changed it, so the
    // completion screen can show the *session's* contribution to
    // today's score rather than the score at some arbitrary later
    // moment.
    _wellnessScoreBefore = WellnessScoreScope.of(context).todaySnapshot().score;
  }

  void _onSessionChanged() {
    final manager = _manager;
    if (manager != null &&
        !_sessionSummaryRecorded &&
        manager.phase == WorkoutSessionPhase.complete) {
      _sessionSummaryRecorded = true;
      unawaited(
        DailyRoutineScope.of(context).recordSessionCompleted(
          duration: manager.elapsed,
          exerciseCount: manager.completedExerciseIds.length,
          wellnessScore: WellnessScoreScope.of(context).todaySnapshot().score,
        ),
      );
      // "Session Finished -> Interstitial -> Congratulations Screen":
      // the interstitial is a native overlay that shows on top of
      // whatever Flutter is currently rendering, so firing this here
      // (as _CompleteView starts building below) naturally produces
      // that order without needing to sequence anything explicitly —
      // see AdsManager.maybeShowInterstitialAfterSession for why this
      // is also safe to call unconditionally: it's a no-op on its own
      // whenever there's no ad ready, Premium is active, or the
      // cooldown hasn't elapsed. _sessionSummaryRecorded above is
      // reused as this call's own "exactly once per session" guard
      // too, rather than introducing a second flag for the same
      // moment.
      unawaited(AdsScope.of(context).maybeShowInterstitialAfterSession());
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final manager = _manager;
    if (manager != null) {
      manager.removeListener(_onSessionChanged);
      manager.dispose();
    }
    super.dispose();
  }

  Future<void> _confirmExit() async {
    final manager = _manager;
    if (manager == null) return;
    final wasPaused = manager.paused;
    manager.pause();
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End session?'),
        content: Text(
          manager.completedExerciseIds.isEmpty
              ? "Your progress on this session won't be saved."
              : '${manager.completedExerciseIds.length} of '
                    '${manager.exerciseCount} '
                    '${manager.exerciseCount == 1 ? 'exercise' : 'exercises'} '
                    "will stay marked complete; the rest of the session "
                    "won't run.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    // Checking the State's own `mounted` here, not `context.mounted`:
    // unlike GuidedSessionScreen's version of this method, this one
    // takes no BuildContext parameter of its own, so `context` above
    // is just this State's `context` — the two checks would be
    // equivalent in practice, but `mounted` is what the analyzer can
    // actually verify covers every `context` use below.
    if (!mounted) return;
    if (shouldExit ?? false) {
      manager.exitSession();
      Navigator.of(context).pop();
    } else if (!wasPaused) {
      manager.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = _manager;
    if (manager == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final phase = manager.phase;
    final showChrome =
        phase == WorkoutSessionPhase.exercise ||
        phase == WorkoutSessionPhase.rest;

    return PopScope(
      canPop:
          phase == WorkoutSessionPhase.intro ||
          phase == WorkoutSessionPhase.complete,
      child: Scaffold(
        appBar: showChrome
            ? AppBar(
                title: Text(
                  phase == WorkoutSessionPhase.exercise
                      ? '${manager.exerciseIndex + 1} of '
                            '${manager.exerciseCount}'
                      : 'Rest',
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Exit Session',
                  onPressed: _confirmExit,
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.music_note_outlined),
                    tooltip: 'Music & Voice',
                    onPressed: () => showMusicVoiceSheet(context),
                  ),
                ],
              )
            : null,
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
              // Exercise/rest also key off exerciseIndex, not just
              // phase, so moving from "exercise 1" to "exercise 2"
              // (skipping rest via `next()`) still counts as a new
              // subtree and replays the transition/entrance animations
              // — without that, two consecutive exercise phases would
              // share a key and AnimatedSwitcher wouldn't animate
              // between them at all.
              key: ValueKey('$phase-${manager.exerciseIndex}'),
              child: switch (phase) {
                WorkoutSessionPhase.intro => _IntroView(manager: manager),
                WorkoutSessionPhase.exercise => _ExerciseView(
                  manager: manager,
                ),
                WorkoutSessionPhase.rest => _RestView(manager: manager),
                WorkoutSessionPhase.complete => _CompleteView(
                  manager: manager,
                  wellnessScoreBefore: _wellnessScoreBefore,
                  onContinue: () => Navigator.of(context).pop(),
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Shared bits
// ============================================================================

/// Per-exercise segmented dash bar plus elapsed/remaining time, shown
/// on both [_ExerciseView] and [_RestView] so overall session
/// progress stays visible — and in the same discrete,
/// one-dash-per-exercise style, matching how competing apps like
/// Nike Training Club/FitOn present it — no matter which one is on
/// screen.
class _SessionProgressBar extends StatelessWidget {
  const _SessionProgressBar({required this.manager});

  final WorkoutSessionManager manager;

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

    // An exercise only counts as "done" for the dash bar once its own
    // phase has actually finished — mid-exercise, its dash reads the
    // same as one not yet reached; it fills the moment rest (or
    // completion, for the very last one) begins.
    final completedCount = manager.phase == WorkoutSessionPhase.exercise
        ? manager.exerciseIndex
        : manager.exerciseIndex + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SegmentedDashBar(
          segmentCount: manager.exerciseCount,
          filledCount: completedCount,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Elapsed ${_formatClock(manager.elapsed)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${_formatClock(manager.estimatedRemaining)} left',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A row of [segmentCount] equal-width dashes, the first [filledCount]
/// solid and the rest faint — the discrete, per-exercise progress
/// style [_SessionProgressBar] uses instead of a single continuous
/// bar, so progress reads in the same whole-exercise steps a user
/// actually experiences the session in.
class _SegmentedDashBar extends StatelessWidget {
  const _SegmentedDashBar({
    required this.segmentCount,
    required this.filledCount,
  });

  final int segmentCount;
  final int filledCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var i = 0; i < segmentCount; i++) ...[
          if (i != 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              height: 4,
              decoration: BoxDecoration(
                color: i < filledCount
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// Intro
// ============================================================================

class _IntroView extends StatelessWidget {
  const _IntroView({required this.manager});

  final WorkoutSessionManager manager;

  String _formatMinutes(Duration d) {
    final minutes = (d.inSeconds / 60).ceil();
    return minutes <= 1 ? '1 min' : '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            children: [
              Icon(
                Icons.fitness_center,
                size: 40,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Your Routine',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${manager.exerciseCount} '
                '${manager.exerciseCount == 1 ? 'exercise' : 'exercises'} · '
                '${_formatMinutes(manager.plannedDuration)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'This session runs start to finish on its own — each '
                'exercise begins automatically after a short rest, with '
                'no need to open the next one yourself.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < manager.exercises.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _IntroExerciseRow(
                    index: i,
                    exercise: manager.exercises[i],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SafeArea(
            top: false,
            child: PrimaryButton(
              label: 'Start Routine',
              icon: Icons.play_arrow_rounded,
              onPressed: manager.start,
            ),
          ),
        ),
      ],
    );
  }
}

class _IntroExerciseRow extends StatelessWidget {
  const _IntroExerciseRow({required this.index, required this.exercise});

  final int index;
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              exercise.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatExerciseDuration(exercise.duration),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Exercise (running)
// ============================================================================

class _ExerciseView extends StatelessWidget {
  const _ExerciseView({required this.manager});

  final WorkoutSessionManager manager;

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
    final exercise = manager.currentExercise;
    final narrator = ExerciseNarratorScope.of(context);

    final total = exercise.duration.inSeconds == 0
        ? 1
        : exercise.duration.inSeconds;
    final progress = 1 - (manager.remaining.inSeconds / total);

    final segments = [exercise.title, ...exercise.instructions];
    final currentInstruction =
        narrator.currentSegmentIndex < segments.length
        ? segments[narrator.currentSegmentIndex]
        : exercise.title;
    final videoAsset = exercise.videoAsset;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              children: [
                _SessionProgressBar(manager: manager),
                const SizedBox(height: 20),
                if (videoAsset != null)
                  ExerciseVideoPreview(
                    key: ValueKey('video-${exercise.id}'),
                    assetPath: videoAsset,
                    paused: manager.paused,
                  )
                else
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      exercise.icon,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress.clamp(0, 1)),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return CircularProgressIndicator(
                              value: value,
                              strokeWidth: 9,
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation(
                                colorScheme.primary,
                              ),
                            );
                          },
                        ),
                      ),
                      Semantics(
                        label:
                            '${manager.remaining.inMinutes} minutes '
                            '${manager.remaining.inSeconds % 60} seconds '
                            'remaining',
                        excludeSemantics: true,
                        child: Text(
                          _formatClock(manager.remaining),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  exercise.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      manager.paused ? 'Paused' : currentInstruction,
                      key: ValueKey(
                        manager.paused ? 'paused' : currentInstruction,
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: manager.paused
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
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
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: manager.exerciseIndex == 0
                          ? null
                          : manager.previous,
                      icon: const Icon(Icons.skip_previous_rounded),
                      tooltip: 'Previous Exercise',
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: manager.skip,
                      icon: const Icon(Icons.fast_forward_rounded),
                      tooltip: 'Skip',
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: manager.paused ? 'Resume' : 'Pause',
                        icon: manager.paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        onPressed: manager.paused
                            ? manager.resume
                            : manager.pause,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: manager.next,
                      icon: const Icon(Icons.skip_next_rounded),
                      tooltip: 'Next Exercise',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Rest
// ============================================================================

class _RestView extends StatelessWidget {
  const _RestView({required this.manager});

  final WorkoutSessionManager manager;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final upcoming = manager.upcomingExercise;
    // 1-based number of the *upcoming* exercise — one past the
    // 1-based number of the one whose rest this is (exerciseIndex is
    // 0-based and still points at that just-finished exercise).
    final nextNumber = manager.exerciseIndex + 2;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SessionProgressBar(manager: manager),
                const SizedBox(height: 20),
                if (upcoming != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NEXT $nextNumber/${manager.exerciseCount}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              upcoming.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        formatExerciseDuration(upcoming.duration),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _UpcomingExercisePreview(exercise: upcoming),
                  const SizedBox(height: 36),
                ],
                Center(
                  child: Column(
                    children: [
                      Text(
                        'REST',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        label:
                            '${manager.remaining.inSeconds} seconds of '
                            'rest left',
                        child: Text(
                          '${manager.remaining.inSeconds}',
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
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
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => manager.extendRest(
                      const Duration(seconds: 15),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('+15s'),
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
                    label: 'Skip Rest',
                    icon: Icons.skip_next_rounded,
                    onPressed: manager.skip,
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

/// A large, single-glance preview of the exercise coming up next —
/// deliberately sized and positioned like a "here's what you're about
/// to do" hero image (matching the emphasis competing apps like Nike
/// Training Club/FitOn give the upcoming exercise during rest), not a
/// small compact row.
///
/// Shows the still [Exercise.thumbnailAsset], not a playing
/// [ExerciseVideoPreview] — deliberately: rest is meant to read as a
/// pause, and a second video quietly looping in the background would
/// cut against that, on top of the added cost of a live
/// [VideoPlayerController] for something on screen for only a few
/// seconds at a time. The real video takes over the instant the
/// upcoming exercise actually starts (see [_ExerciseView]).
class _UpcomingExercisePreview extends StatelessWidget {
  const _UpcomingExercisePreview({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final thumbnail = exercise.thumbnailAsset;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        // Matches thumbnailAsset's own square crop (see
        // Exercise.thumbnailAsset's doc comment) exactly, rather than
        // a wider ratio that would just crop it further on top of
        // that — every bundled thumbnail was already center-cropped
        // to 1:1 when it was generated.
        aspectRatio: 1,
        child: thumbnail != null
            ? Image.asset(
                thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _fallback(colorScheme),
              )
            : _fallback(colorScheme),
      ),
    );
  }

  Widget _fallback(ColorScheme colorScheme) {
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(exercise.icon, size: 56, color: colorScheme.primary),
      ),
    );
  }
}

// ============================================================================
// Complete
// ============================================================================

class _CompleteView extends StatefulWidget {
  const _CompleteView({
    required this.manager,
    required this.wellnessScoreBefore,
    required this.onContinue,
  });

  final WorkoutSessionManager manager;
  final int wellnessScoreBefore;
  final VoidCallback onContinue;

  @override
  State<_CompleteView> createState() => _CompleteViewState();
}

class _CompleteViewState extends State<_CompleteView> {
  String _formatMinutes(Duration d) {
    final minutes = (d.inSeconds / 60).ceil();
    return minutes <= 1 ? '1 min' : '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final manager = widget.manager;
    final wellnessAfter = WellnessScoreScope.of(context).todaySnapshot().score;
    final wellnessGained = (wellnessAfter - widget.wellnessScoreBefore).clamp(
      0,
      100,
    );
    final workoutStreak = StreakScope.of(
      context,
    ).infoFor(StreakKind.workout);
    // A rough, generic estimate for gentle mobility/stretching work —
    // not derived from any real activity tracking, since this app
    // doesn't have any (heart rate, accelerometer, etc.) to draw on.
    // Deliberately labeled "Estimated" wherever it's shown rather than
    // presented as a measurement.
    final estimatedCalories = (manager.elapsed.inMinutes * 4).clamp(
      1,
      999,
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1.0),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: const CoachAvatar(
                    size: 110,
                    imageAsset: 'assets/images/coach/workout_complete.png',
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Session Complete!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You finished every exercise in this routine.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _StatTile(
                      icon: Icons.timer_outlined,
                      value: _formatMinutes(manager.elapsed),
                      label: 'Duration',
                    ),
                    _StatTile(
                      icon: Icons.check_circle_outline,
                      value: '${manager.completedExerciseIds.length}',
                      label: 'Exercises',
                    ),
                    _StatTile(
                      icon: Icons.local_fire_department_outlined,
                      value: '~$estimatedCalories',
                      label: 'Est. Calories',
                    ),
                    _StatTile(
                      icon: Icons.favorite_outline,
                      value: '+$wellnessGained',
                      label: 'Wellness Score',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          workoutStreak.currentStreak <= 1
                              ? 'Workout streak started — day 1'
                              : '${workoutStreak.currentStreak}-day workout '
                                    'streak',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
              onPressed: widget.onContinue,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: colorScheme.primary, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
