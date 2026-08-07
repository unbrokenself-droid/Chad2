import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// A single target pose in a looping [ExerciseDemonstration], and how
/// long the transition from the previous keyframe to this one takes.
///
/// Deliberately just four numbers (plus an optional second shape) —
/// rotation, horizontal/vertical offset, and scale — rather than
/// anything resembling real illustration data. [ExerciseDemonstrationView]
/// composes these with [Transform.rotate]/[Transform.translate]/
/// [Transform.scale] around a plain rounded shape; there's no
/// hand-drawn artwork or video here, and this is intentionally
/// upfront about that rather than dressing simple motion up as more
/// than it is. See `lib/data/exercise_demonstrations.dart`'s file
/// doc comment for the fuller reasoning.
@immutable
class DemonstrationKeyframe {
  const DemonstrationKeyframe({
    required this.duration,
    required this.label,
    this.rotation = 0.0,
    this.dx = 0.0,
    this.dy = 0.0,
    this.scale = 1.0,
    this.secondaryDx,
    this.secondaryDy,
  });

  /// How long the transition *into* this keyframe takes, starting
  /// from the previous one (or, for the first keyframe, from the
  /// last keyframe in the loop — the sequence wraps around
  /// continuously, not resetting to a hard cut).
  final Duration duration;

  /// Short caption shown while transitioning into this keyframe, e.g.
  /// `'Tilt right'` or `'Hold'`. Deliberately terse — this is a
  /// real-time caption for what the shape is doing right now, not the
  /// exercise's full instruction text (that's shown separately,
  /// advancing more slowly across the whole exercise — see
  /// `_RunningView`).
  final String label;

  /// Rotation in radians, applied to the primary shape.
  final double rotation;

  /// Horizontal/vertical offset in logical pixels, applied to the
  /// primary shape.
  final double dx;
  final double dy;

  /// Uniform scale multiplier applied to the primary shape.
  final double scale;

  /// Offset for a second shape, in logical pixels — for patterns
  /// where two things move relative to each other (a jaw opening
  /// below a head, two shoulder blades moving together). Null on
  /// both the keyframe and the whole [ExerciseDemonstration] means
  /// there's no second shape to draw at all.
  final double? secondaryDx;
  final double? secondaryDy;
}

/// A pose interpolated partway between two [DemonstrationKeyframe]s —
/// what [ExerciseDemonstrationView] actually paints on a given frame.
@immutable
class DemonstrationPose {
  const DemonstrationPose({
    required this.label,
    required this.rotation,
    required this.dx,
    required this.dy,
    required this.scale,
    this.secondaryDx,
    this.secondaryDy,
  });

  final String label;
  final double rotation;
  final double dx;
  final double dy;
  final double scale;
  final double? secondaryDx;
  final double? secondaryDy;
}

/// A looping, illustrated movement demonstration for one [Exercise],
/// linked by [exerciseId] rather than being a field on [Exercise]
/// itself — see the data file's doc comment for why.
@immutable
class ExerciseDemonstration {
  const ExerciseDemonstration({
    required this.exerciseId,
    required this.keyframes,
  });

  /// Matches an [Exercise.id] in the catalog. Not validated against
  /// the actual catalog at this layer — `exercise_demonstrations.dart`
  /// is a plain data file with no dependency on
  /// `ExerciseRepository`, so a typo here fails silently (the lookup
  /// just finds nothing) rather than as a loud error. Worth a test
  /// once there's more than a handful of these.
  final String exerciseId;

  /// The loop, in order. The last keyframe transitions back to the
  /// first, continuously — there's no "end," only exercise duration
  /// running out.
  ///
  /// Expected to have at least two entries — not enforced by an
  /// assert, deliberately: `List.length` isn't a valid constant
  /// expression, so an assert here would force this constructor to
  /// give up `const` for every one of the five call sites in
  /// `exercise_demonstrations.dart`, the only place this is ever
  /// constructed, for a check whose failure modes are already
  /// self-evident without it — an empty list throws a clear
  /// `StateError` from `.first` in [poseAt], and a single-keyframe
  /// list just produces a static, non-animated pose rather than
  /// anything silently wrong.
  final List<DemonstrationKeyframe> keyframes;

  /// Total duration of one full loop.
  Duration get loopDuration => keyframes.fold(
    Duration.zero,
    (sum, keyframe) => sum + keyframe.duration,
  );

  /// Whether any keyframe defines a second shape — if so, every
  /// keyframe needs to (a keyframe that leaves the second shape
  /// wherever it last was, mid-sequence, would be a bug in the data,
  /// not a valid "no change" — [poseAt] fills in `0.0` for any
  /// keyframe that's missing one only for that reason).
  bool get hasSecondaryShape => keyframes.any((k) => k.secondaryDx != null);

  /// The interpolated pose at [progress] — a fraction of one full
  /// loop, `0.0` to `1.0` (values outside that range wrap via `%`,
  /// so a raw elapsed-time fraction can be passed directly without
  /// the caller needing to normalize it first).
  ///
  /// Finds which two consecutive keyframes [progress] falls between,
  /// then linearly interpolates position/rotation/scale between them
  /// with [curve] applied to the local fraction — matching how
  /// `BreathingOrb` eases between phases, for the same reason: a
  /// linear transition between held poses reads as mechanical, while
  /// easing in and out reads as an actual, gentle movement.
  DemonstrationPose poseAt(double progress, {Curve curve = Curves.easeInOut}) {
    final total = loopDuration;
    if (total == Duration.zero) {
      final only = keyframes.first;
      return DemonstrationPose(
        label: only.label,
        rotation: only.rotation,
        dx: only.dx,
        dy: only.dy,
        scale: only.scale,
        secondaryDx: only.secondaryDx,
        secondaryDy: only.secondaryDy,
      );
    }

    final normalized = progress % 1.0;
    final elapsedMicros = (normalized * total.inMicroseconds).round();

    var cursor = 0;
    for (var i = 0; i < keyframes.length; i++) {
      final keyframe = keyframes[i];
      final segmentEnd = cursor + keyframe.duration.inMicroseconds;
      if (elapsedMicros < segmentEnd || i == keyframes.length - 1) {
        final previous = keyframes[(i - 1 + keyframes.length) % keyframes.length];
        final segmentDuration = keyframe.duration.inMicroseconds;
        final localFraction = segmentDuration == 0
            ? 1.0
            : ((elapsedMicros - cursor) / segmentDuration).clamp(0.0, 1.0);
        final eased = curve.transform(localFraction);

        return DemonstrationPose(
          label: keyframe.label,
          rotation: _lerp(previous.rotation, keyframe.rotation, eased),
          dx: _lerp(previous.dx, keyframe.dx, eased),
          dy: _lerp(previous.dy, keyframe.dy, eased),
          scale: _lerp(previous.scale, keyframe.scale, eased),
          secondaryDx: _lerpNullable(
            previous.secondaryDx,
            keyframe.secondaryDx,
            eased,
          ),
          secondaryDy: _lerpNullable(
            previous.secondaryDy,
            keyframe.secondaryDy,
            eased,
          ),
        );
      }
      cursor = segmentEnd;
    }

    // Unreachable — the loop above always returns on its last
    // iteration if nothing matches earlier — but the analyzer can't
    // prove that, and every function needs a return on every path.
    final fallback = keyframes.first;
    return DemonstrationPose(
      label: fallback.label,
      rotation: fallback.rotation,
      dx: fallback.dx,
      dy: fallback.dy,
      scale: fallback.scale,
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double? _lerpNullable(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    return _lerp(a ?? 0.0, b ?? 0.0, t);
  }
}
