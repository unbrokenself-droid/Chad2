import '../models/exercise_demonstration.dart';

/// Looping movement demonstrations, keyed by [Exercise.id].
///
/// **What this is, plainly stated.** Five hand-authored, abstract
/// motion diagrams — a rounded shape (or two) translating, rotating,
/// and scaling in a loop — covering five exercises chosen to span
/// distinct kinds of motion: a side-to-side tilt, a two-shape
/// open/close, a scale-based recede/return, two shapes converging and
/// separating, and a circular path. This is not illustrated artwork
/// and not video; it's the same category of thing as
/// `BreathingOrb` (an animated shape, not a picture of a person
/// breathing), applied to exercise motion instead. See
/// `ExerciseDemonstrationView` for how these get drawn — plain
/// `Transform.rotate`/`translate`/`scale` composition, deliberately,
/// since hand-written `CustomPainter` code can't be visually checked
/// without a running Flutter renderer to look at, and getting
/// coordinate math subtly wrong in a way nobody catches is a real
/// risk worth designing around rather than risking.
///
/// **Why a separate file instead of a field on [Exercise].** Adding
/// a `demonstration` field to the 25-entry `assets/exercises.json`
/// catalog would mean either backfilling all 25 with something (fake
/// completeness) or making the field nullable everywhere it's read
/// (a schema change for a five-exercise proof of concept). A
/// standalone lookup, keyed by the *existing* `Exercise.id`, is
/// genuinely additive instead: nothing about `Exercise` changes,
/// every one of the other 20 exercises keeps working exactly as
/// before (see `_RunningView`'s fallback to the plain icon when
/// `exerciseDemonstrations[exercise.id]` is null), and covering more
/// exercises later is purely a matter of adding more entries here.
///
/// **Extending this.** Each `ExerciseDemonstration` is a loop of
/// `DemonstrationKeyframe`s — a target rotation/offset/scale, how
/// long the transition into it takes, and a short caption. Keep new
/// entries simple and legible at a glance (this plays at roughly
/// 140x140 logical pixels) rather than trying to convey more detail
/// than that size can actually show, and keep offsets modest (under
/// ~30px) so nothing clips outside the stage — see
/// `ExerciseDemonstrationView`'s `stageSize` for the exact bounds
/// this needs to stay inside.
final Map<String, ExerciseDemonstration> exerciseDemonstrations = {
  // ---- Ear-to-Shoulder Tilt: side-to-side rotation ----------------------
  'ear-to-shoulder-tilt': const ExerciseDemonstration(
    exerciseId: 'ear-to-shoulder-tilt',
    keyframes: [
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 1000),
        label: 'Sit tall, shoulders relaxed',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 1100),
        rotation: 0.36,
        label: 'Tilt right ear toward shoulder',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 1000),
        rotation: 0.36,
        label: 'Hold the stretch',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 900),
        label: 'Return to center',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 1100),
        rotation: -0.36,
        label: 'Tilt left ear toward shoulder',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 1000),
        rotation: -0.36,
        label: 'Hold the stretch',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 900),
        label: 'Return to center',
      ),
    ],
  ),

  // ---- Jaw Release Drop: two shapes, lower one opens/closes -------------
  'jaw-release-drop': const ExerciseDemonstration(
    exerciseId: 'jaw-release-drop',
    keyframes: [
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 900),
        secondaryDy: 0,
        label: 'Let your jaw hang loose',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 850),
        secondaryDy: 26,
        label: 'Open about halfway',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 750),
        secondaryDy: 26,
        label: 'Stay loose, don\u2019t force it',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 850),
        secondaryDy: 0,
        label: 'Let it drop closed',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 650),
        secondaryDy: 0,
        label: 'Rest, no clenching',
      ),
    ],
  ),

  // ---- Chin Tucks: scale-based recede/return -----------------------------
  'chin-tucks': const ExerciseDemonstration(
    exerciseId: 'chin-tucks',
    keyframes: [
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 900),
        label: 'Look straight ahead',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 800),
        scale: 0.82,
        label: 'Draw chin straight back',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 1300),
        scale: 0.82,
        label: 'Hold for 3 seconds',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 800),
        label: 'Release slowly',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 700),
        label: 'Rest',
      ),
    ],
  ),

  // ---- Shoulder Blade Squeezes: two shapes converge/separate -----------
  'shoulder-blade-squeezes': const ExerciseDemonstration(
    exerciseId: 'shoulder-blade-squeezes',
    keyframes: [
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 900),
        dx: -26,
        secondaryDx: 26,
        label: 'Arms relaxed at your sides',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 750),
        dx: -7,
        secondaryDx: 7,
        label: 'Squeeze shoulder blades together',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 950),
        dx: -7,
        secondaryDx: 7,
        label: 'Hold, shoulders down',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 750),
        dx: -26,
        secondaryDx: 26,
        label: 'Release slowly',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 650),
        dx: -26,
        secondaryDx: 26,
        label: 'Rest',
      ),
    ],
  ),

  // ---- Slow Neck Circles: continuous circular path -----------------------
  'slow-neck-circles': const ExerciseDemonstration(
    exerciseId: 'slow-neck-circles',
    keyframes: [
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 750),
        dy: 20,
        label: 'Chin gently toward chest',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 750),
        dx: 14,
        dy: 14,
        label: 'Roll slowly to the side',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 750),
        dx: 20,
        label: 'Continue the circle',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 750),
        dx: 14,
        dy: -14,
        label: 'Continue the circle',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 750),
        dy: -20,
        label: 'Continue the circle',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 750),
        dx: -14,
        dy: -14,
        label: 'Continue the circle',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 750),
        dx: -20,
        label: 'Continue the circle',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 750),
        dx: -14,
        dy: 14,
        label: 'Continue the circle',
      ),
      DemonstrationKeyframe(
        duration: Duration(milliseconds: 750),
        dy: 20,
        label: 'Back to chin toward chest',
      ),
    ],
  ),
};
