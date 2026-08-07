import 'package:flutter/material.dart';

import '../../models/exercise_demonstration.dart';

/// Plays a looping [ExerciseDemonstration]: a rounded shape (and, for
/// two-part motions, a second one) translating, rotating, and scaling
/// through the demonstration's keyframes, with a caption underneath
/// that changes at each keyframe.
///
/// Self-contained — owns its own [AnimationController] via
/// [SingleTickerProviderStateMixin] rather than requiring one from a
/// parent, specifically so wiring this into `GuidedSessionScreen`
/// doesn't require touching that screen's existing ticker setup
/// (`_pulseController`) at all. [paused] stops the controller outright
/// rather than freezing the displayed pose, matching how a real pause
/// button should behave — resuming continues the motion from where it
/// left off, not from a reset position.
class ExerciseDemonstrationView extends StatefulWidget {
  const ExerciseDemonstrationView({
    super.key,
    required this.demonstration,
    required this.color,
    this.paused = false,
  });

  final ExerciseDemonstration demonstration;

  /// Color for both shapes and the stage's tint. Callers pass
  /// something derived from the exercise's category/theme rather
  /// than this widget picking its own, so it reads as part of the
  /// same screen rather than a disconnected component.
  final Color color;

  final bool paused;

  /// The fixed size both shapes' motion is authored against — see
  /// `exercise_demonstrations.dart`'s file doc comment. Exposed as a
  /// constant (not just an internal magic number) specifically so
  /// anyone authoring new keyframe data has a concrete bound to check
  /// offsets against.
  static const double stageSize = 140;

  @override
  State<ExerciseDemonstrationView> createState() =>
      _ExerciseDemonstrationViewState();
}

class _ExerciseDemonstrationViewState extends State<ExerciseDemonstrationView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.demonstration.loopDuration,
    );
    _applyRunningState();
  }

  @override
  void didUpdateWidget(covariant ExerciseDemonstrationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.demonstration != oldWidget.demonstration) {
      // Different exercise's demonstration (shouldn't happen mid-session
      // in practice, since GuidedSessionScreen is pushed per-exercise,
      // but handled correctly rather than assumed away) — restart
      // clean rather than continuing to loop against a duration that
      // no longer matches the new keyframe data.
      _controller.duration = widget.demonstration.loopDuration;
      _controller.reset();
    }
    if (widget.paused != oldWidget.paused) {
      _applyRunningState();
    }
  }

  void _applyRunningState() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (widget.paused || reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery (reduce motion) can change while this is already
    // mounted; re-evaluate rather than only checking once in initState.
    _applyRunningState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return RepaintBoundary(
      child: Container(
        width: ExerciseDemonstrationView.stageSize,
        height: ExerciseDemonstrationView.stageSize + 32,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final pose = reduceMotion
                          ? widget.demonstration.poseAt(0.0)
                          : widget.demonstration.poseAt(_controller.value);
                      return _DemonstrationStage(
                        pose: pose,
                        color: widget.color,
                        hasSecondaryShape:
                            widget.demonstration.hasSecondaryShape,
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 16,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final pose = reduceMotion
                      ? widget.demonstration.poseAt(0.0)
                      : widget.demonstration.poseAt(_controller.value);
                  // Deliberately not a live region: this caption
                  // changes roughly every second as the loop plays,
                  // and a screen reader announcing every change would
                  // mean constant interruption for the whole exercise.
                  // The slower-changing instruction text below the
                  // ring (~every 15s for a typical 60s/4-step
                  // exercise) is where that's actually warranted —
                  // see _RunningView.
                  return Text(
                    pose.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: widget.color,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The moving shape(s) for a single interpolated [DemonstrationPose] —
/// split out from [ExerciseDemonstrationView] purely for readability;
/// it has no state or animation logic of its own.
class _DemonstrationStage extends StatelessWidget {
  const _DemonstrationStage({
    required this.pose,
    required this.color,
    required this.hasSecondaryShape,
  });

  final DemonstrationPose pose;
  final Color color;
  final bool hasSecondaryShape;

  static const double _shapeSize = 46;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ExerciseDemonstrationView.stageSize,
      height: ExerciseDemonstrationView.stageSize - 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasSecondaryShape)
            Transform.translate(
              offset: Offset(pose.secondaryDx ?? 0, pose.secondaryDy ?? 0),
              child: _Shape(color: color, size: _shapeSize, filled: false),
            ),
          Transform.translate(
            offset: Offset(pose.dx, pose.dy),
            child: Transform.rotate(
              angle: pose.rotation,
              child: Transform.scale(
                scale: pose.scale,
                child: _Shape(color: color, size: _shapeSize, filled: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single rounded shape — the primary shape (filled) or a secondary
/// one (outlined only, so two overlapping shapes stay visually
/// distinguishable rather than merging into one blob when they're
/// close together, which patterns like the shoulder-blade squeeze
/// deliberately bring close together).
class _Shape extends StatelessWidget {
  const _Shape({
    required this.color,
    required this.size,
    required this.filled,
  });

  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: filled ? null : Border.all(color: color, width: 2.5),
      ),
    );
  }
}
