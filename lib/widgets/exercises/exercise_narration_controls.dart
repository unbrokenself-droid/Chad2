import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../../services/exercise_narrator.dart';
import '../../services/exercise_narrator_scope.dart';
import '../shared/primary_button.dart';

/// Playback controls for reading [exercise]'s title and instructions
/// aloud, through the app's single shared [ExerciseNarrator]
/// ([ExerciseNarratorScope]).
///
/// Owns the narrator's lifecycle for as long as this widget stays
/// mounted: loads [exercise] into the narrator the first time it
/// builds, and stops narration in [dispose]. Between the two, that
/// covers both auto-stop cases the narrator needs: leaving the screen
/// this widget lives on unmounts it, triggering [dispose]; starting a
/// *different* exercise mounts a new instance of this widget for the
/// new exercise, which calls [ExerciseNarrator.loadExercise] — and
/// that method always stops whatever was already playing first (see
/// its doc comment) — before the previous instance's own [dispose]
/// even runs.
class ExerciseNarrationControls extends StatefulWidget {
  const ExerciseNarrationControls({super.key, required this.exercise});

  final Exercise exercise;

  @override
  State<ExerciseNarrationControls> createState() =>
      _ExerciseNarrationControlsState();
}

class _ExerciseNarrationControlsState
    extends State<ExerciseNarrationControls> {
  ExerciseNarrator? _narrator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Loading here (once) rather than in initState: an InheritedWidget
    // lookup like ExerciseNarratorScope.of isn't safe to make from
    // initState, since the widget isn't fully inserted into the tree
    // yet at that point — didChangeDependencies is the standard place
    // for a one-time, context-dependent setup step like this one (the
    // null guard is what keeps it to exactly once, since
    // didChangeDependencies re-fires for any dependency change, not
    // just the first).
    if (_narrator == null) {
      final narrator = ExerciseNarratorScope.of(context);
      _narrator = narrator;
      unawaited(narrator.loadExercise(widget.exercise));
    }
  }

  @override
  void dispose() {
    // Not awaited: dispose() can't be async, but ExerciseNarrator.stop()
    // already updates its own state and calls notifyListeners() before
    // its single flutter_tts call (see TtsExerciseNarrator's class doc
    // comment) — so narration reliably stops the instant this fires,
    // regardless of whether the underlying platform call has resolved
    // by the time this widget finishes tearing down.
    unawaited(_narrator?.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final narrator = ExerciseNarratorScope.of(context);
    final status = narrator.status;

    final canSkipForward =
        status != NarrationStatus.stopped &&
        narrator.currentSegmentIndex < narrator.segmentCount - 1;
    final canReplay = status != NarrationStatus.stopped;

    late final String primaryLabel;
    late final IconData primaryIcon;
    late final VoidCallback primaryAction;
    switch (status) {
      case NarrationStatus.stopped:
        primaryLabel = 'Play';
        primaryIcon = Icons.play_arrow_rounded;
        primaryAction = narrator.play;
      case NarrationStatus.playing:
        primaryLabel = 'Pause';
        primaryIcon = Icons.pause_rounded;
        primaryAction = narrator.pause;
      case NarrationStatus.paused:
        primaryLabel = 'Resume';
        primaryIcon = Icons.play_arrow_rounded;
        primaryAction = narrator.resume;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.record_voice_over_outlined,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Listen to instructions',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (status != NarrationStatus.stopped)
                Text(
                  'Step ${narrator.currentSegmentIndex + 1} of '
                  '${narrator.segmentCount}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: canReplay ? narrator.replay : null,
                icon: const Icon(Icons.replay_rounded),
                tooltip: 'Replay',
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: status == NarrationStatus.stopped
                    ? null
                    : narrator.stop,
                icon: const Icon(Icons.stop_rounded),
                tooltip: 'Stop',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: primaryLabel,
                  icon: primaryIcon,
                  onPressed: primaryAction,
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: canSkipForward ? narrator.skipForward : null,
                icon: const Icon(Icons.skip_next_rounded),
                tooltip: 'Skip Forward',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
