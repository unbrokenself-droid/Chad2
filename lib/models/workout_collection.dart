import '../models/exercise.dart';

/// The three difficulty tiers [ExercisesScreen]'s collections rail is
/// organized into — separate from [ExerciseDifficulty], which is a
/// property of an individual exercise, not a collection. A
/// collection's [WorkoutCollectionDefinition.targetDifficulty] is
/// what actually drives which exercises get picked (see
/// [resolveWorkoutCollection]); [tier] only decides which filter chip
/// and badge color it shows under.
enum WorkoutCollectionTier {
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced');

  const WorkoutCollectionTier(this.label);
  final String label;
}

/// The horizontal filter chips above the collections rail —
/// "Featured" and the three tiers filter on
/// [WorkoutCollectionDefinition.featured]/`.tier` directly; the three
/// duration bands filter on a resolved collection's *actual* total
/// duration (see [WorkoutCollection.totalDuration]), which depends on
/// which real exercises the collection resolved to, not anything
/// declared up front.
enum WorkoutCollectionFilter {
  featured('Featured'),
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced'),
  quick('Quick (5–10 min)'),
  medium('Medium (10–20 min)'),
  long('Long (20+ min)');

  const WorkoutCollectionFilter(this.label);
  final String label;
}

/// The static, hand-written half of a built-in workout collection —
/// everything about it that doesn't depend on the exercise catalog.
/// [resolveWorkoutCollection] is what turns this into an actual
/// ordered list of [Exercise]s, which becomes a [WorkoutCollection].
///
/// Deliberately holds *rules* (which categories, roughly how many,
/// preferring which difficulty), not a hardcoded list of exercise
/// ids — "automatically built using existing exercises," from the
/// request this was built for, taken literally: every collection is
/// computed fresh from whatever's actually in the catalog each time,
/// the same way [DailyRoutineService] computes a routine rather than
/// shipping one, so a future catalog change (a new exercise added, an
/// old one removed) is reflected automatically instead of leaving a
/// collection referencing something that no longer exists.
class WorkoutCollectionDefinition {
  const WorkoutCollectionDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.categories,
    required this.targetDifficulty,
    required this.exerciseCount,
    required this.tier,
    this.featured = false,
  });

  final String id;
  final String title;
  final String description;

  /// Which categories this collection draws from, in the order they
  /// should appear in the resolved exercise list — [exerciseCount] is
  /// spread across these as evenly as possible (see
  /// [resolveWorkoutCollection]), not duplicated across all of them.
  final List<ExerciseCategory> categories;

  /// The [ExerciseDifficulty] this collection prefers when picking
  /// within each category — falls back to the closest available
  /// difficulty in a category that doesn't have enough exercises at
  /// this exact level, the same graceful-fallback approach
  /// [DailyRoutineService] uses for the daily routine.
  final ExerciseDifficulty targetDifficulty;

  /// How many exercises this collection aims to include in total.
  /// May resolve to fewer if the catalog doesn't have enough
  /// candidates across [categories] — see [resolveWorkoutCollection].
  final int exerciseCount;

  final WorkoutCollectionTier tier;

  /// Whether this shows under the "Featured" filter chip.
  final bool featured;
}

/// A [WorkoutCollectionDefinition] resolved against the actual loaded
/// exercise catalog — what [WorkoutCollectionCard] and
/// [WorkoutCollectionDetailsScreen] actually display, and what
/// "Start Workout" hands to [WorkoutSessionScreen].
///
/// Starting a collection pushes the exact same [WorkoutSessionScreen]
/// "Start Routine" does — that's what gives collections progressive
/// overload, completion history, favorites, and statistics for free,
/// without any of that being reimplemented here: those all already
/// key off [Exercise.id] and today's date through
/// [ExerciseCompletionService]/[StreakService]/[WellnessScoreService],
/// completely independent of whether an exercise's session came from
/// today's daily routine or from a collection like this one.
class WorkoutCollection {
  const WorkoutCollection({required this.definition, required this.exercises});

  final WorkoutCollectionDefinition definition;

  /// The real exercises this collection resolved to, in session
  /// order. Can be shorter than [WorkoutCollectionDefinition.exerciseCount]
  /// if the catalog didn't have enough matching candidates.
  final List<Exercise> exercises;

  String get id => definition.id;
  String get title => definition.title;
  String get description => definition.description;
  WorkoutCollectionTier get tier => definition.tier;
  bool get featured => definition.featured;

  Duration get totalDuration =>
      exercises.fold(Duration.zero, (sum, exercise) => sum + exercise.duration);

  /// This collection's background image, if one exists — see
  /// [collectionBackgroundImages]. `null` for the few collections
  /// that don't have one yet; every display of it
  /// ([WorkoutCollectionCard], [WorkoutCollectionDetailsScreen]) falls
  /// back to the original gradient-and-icon treatment in that case,
  /// not a broken-image glyph.
  String? get backgroundImage => collectionBackgroundImages[id];
}

/// Background image for a collection, keyed by
/// [WorkoutCollectionDefinition.id] — read through
/// [WorkoutCollection.backgroundImage], not this map directly.
///
/// A separate lookup rather than a field on
/// [WorkoutCollectionDefinition] itself: not every collection has an
/// image yet (three don't — [full-recovery-routine],
/// [upper-body-mobility-flow], [advanced-stretching] fall back to the
/// existing gradient-and-icon card design), and keeping that an
/// explicit, easy-to-see gap here reads more honestly than nineteen
/// `imageAsset: null` entries scattered through the definitions
/// above.
const Map<String, String> collectionBackgroundImages = {
  'full-face-massage': 'assets/images/collections/full_face_massage.jpg',
  'jaw-relaxation-routine':
      'assets/images/collections/jaw_relaxationroutine.jpg',
  'neck-mobility-routine':
      'assets/images/collections/neck_mobility_routine.jpg',
  'daily-posture-reset': 'assets/images/collections/daily_posture_reset.jpg',
  'breathing-flow': 'assets/images/collections/breathing_flow.jpg',
  'stretch-and-recover': 'assets/images/collections/stretch_and_recover.jpg',
  'morning-refresh': 'assets/images/collections/morning_refresh.jpg',
  'screen-time-recovery':
      'assets/images/collections/screen_time_recovery.jpg',
  'face-sculpting-routine':
      'assets/images/collections/face_sculptingroutine.jpg',
  'advanced-posture-correction':
      'assets/images/collections/advanced_posture_correction.jpg',
  'deep-neck-mobility': 'assets/images/collections/deep_neck_mobility.jpg',
  'facial-tension-reset':
      'assets/images/collections/facial_tension_reset.jpg',
  'stress-relief-flow': 'assets/images/collections/stress_relief_flow.jpg',
  'evening-recovery': 'assets/images/collections/evening_recovery.jpg',
  'complete-face-wellness-session':
      'assets/images/collections/complete_face_wellness.jpg',
  'daily-wellness-pro': 'assets/images/collections/daily_wellnes_pro.jpg',
};

/// Resolves [definition] against [catalog]: for each category in
/// [WorkoutCollectionDefinition.categories], picks a share of
/// [WorkoutCollectionDefinition.exerciseCount] (spread as evenly as
/// possible, any remainder going to the earliest categories),
/// preferring exercises at [WorkoutCollectionDefinition.targetDifficulty]
/// and falling back to the closest available difficulty within that
/// category if it doesn't have enough at the exact target.
///
/// Deterministic — the same [catalog] always resolves a given
/// [definition] to the same exercises in the same order — unlike
/// [DailyRoutineService]'s daily routine, a collection is a fixed,
/// named program that should look the same every time you open it,
/// not something that intentionally rotates day to day.
List<Exercise> resolveWorkoutCollection(
  List<Exercise> catalog,
  WorkoutCollectionDefinition definition,
) {
  final categoryCount = definition.categories.length;
  if (categoryCount == 0 || definition.exerciseCount <= 0) return const [];

  final baseShare = definition.exerciseCount ~/ categoryCount;
  final remainder = definition.exerciseCount % categoryCount;

  const levels = ExerciseDifficulty.values;
  final targetIndex = levels.indexOf(definition.targetDifficulty);

  final picks = <Exercise>[];
  final usedIds = <String>{};

  for (var i = 0; i < categoryCount; i++) {
    // The first `remainder` categories absorb the one extra exercise
    // each that doesn't divide evenly — e.g. 5 exercises across 2
    // categories is 3 + 2, not 2 + 2 (dropping one) or erroring.
    final share = baseShare + (i < remainder ? 1 : 0);
    if (share <= 0) continue;

    final category = definition.categories[i];
    final inCategory =
        catalog
            .where((e) => e.category == category && !usedIds.contains(e.id))
            .toList()
          ..sort((a, b) {
            final distanceA = (levels.indexOf(a.difficulty) - targetIndex).abs();
            final distanceB = (levels.indexOf(b.difficulty) - targetIndex).abs();
            if (distanceA != distanceB) return distanceA.compareTo(distanceB);
            // Stable tie-break so this resolves the same way every
            // time rather than depending on catalog iteration order.
            return a.id.compareTo(b.id);
          });

    for (final exercise in inCategory.take(share)) {
      picks.add(exercise);
      usedIds.add(exercise.id);
    }
  }

  return picks;
}

/// Every built-in workout collection this app ships with. Resolve
/// each against a loaded catalog via [resolveWorkoutCollection] (see
/// [ExercisesScreen], which does this once per catalog load) to get
/// the actual [WorkoutCollection]s to display.
const List<WorkoutCollectionDefinition> builtInWorkoutCollections = [
  // ---- Beginner ----
  WorkoutCollectionDefinition(
    id: 'full-face-massage',
    title: 'Full Face Massage',
    description: 'A complete facial massage sequence to release tension '
        'and boost circulation.',
    categories: [ExerciseCategory.facialMassage],
    targetDifficulty: ExerciseDifficulty.beginner,
    exerciseCount: 5,
    tier: WorkoutCollectionTier.beginner,
    featured: true,
  ),
  WorkoutCollectionDefinition(
    id: 'jaw-relaxation-routine',
    title: 'Jaw Relaxation Routine',
    description: 'Gentle jaw exercises to ease clenching and tightness.',
    categories: [ExerciseCategory.jawRelaxation],
    targetDifficulty: ExerciseDifficulty.beginner,
    exerciseCount: 4,
    tier: WorkoutCollectionTier.beginner,
  ),
  WorkoutCollectionDefinition(
    id: 'neck-mobility-routine',
    title: 'Neck Mobility Routine',
    description: 'Free up a stiff neck with slow, controlled movement '
        'through every direction.',
    categories: [ExerciseCategory.neckMobility],
    targetDifficulty: ExerciseDifficulty.beginner,
    exerciseCount: 4,
    tier: WorkoutCollectionTier.beginner,
  ),
  WorkoutCollectionDefinition(
    id: 'daily-posture-reset',
    title: 'Daily Posture Reset',
    description: 'Counteract hours of sitting with exercises that open '
        'the chest and reset your shoulders.',
    categories: [ExerciseCategory.shoulderPosture],
    targetDifficulty: ExerciseDifficulty.beginner,
    exerciseCount: 4,
    tier: WorkoutCollectionTier.beginner,
    featured: true,
  ),
  WorkoutCollectionDefinition(
    id: 'breathing-flow',
    title: 'Breathing Flow',
    description: 'A short sequence of calming breathing techniques.',
    categories: [ExerciseCategory.breathing],
    targetDifficulty: ExerciseDifficulty.beginner,
    exerciseCount: 3,
    tier: WorkoutCollectionTier.beginner,
  ),
  WorkoutCollectionDefinition(
    id: 'stretch-and-recover',
    title: 'Stretch & Recover',
    description: 'Gentle upper-body stretches to loosen tight muscles.',
    categories: [ExerciseCategory.stretching],
    targetDifficulty: ExerciseDifficulty.beginner,
    exerciseCount: 4,
    tier: WorkoutCollectionTier.beginner,
  ),
  WorkoutCollectionDefinition(
    id: 'morning-refresh',
    title: 'Morning Refresh',
    description: 'Wake up your face, neck, and breath with a light '
        'morning sequence.',
    categories: [
      ExerciseCategory.breathing,
      ExerciseCategory.facialMassage,
      ExerciseCategory.neckMobility,
    ],
    targetDifficulty: ExerciseDifficulty.beginner,
    exerciseCount: 5,
    tier: WorkoutCollectionTier.beginner,
    featured: true,
  ),
  WorkoutCollectionDefinition(
    id: 'screen-time-recovery',
    title: 'Screen Time Recovery',
    description: 'Release the neck, shoulder, and jaw tension that '
        'builds up during long stretches at a screen.',
    categories: [
      ExerciseCategory.neckMobility,
      ExerciseCategory.shoulderPosture,
      ExerciseCategory.jawRelaxation,
    ],
    targetDifficulty: ExerciseDifficulty.beginner,
    exerciseCount: 5,
    tier: WorkoutCollectionTier.beginner,
  ),

  // ---- Intermediate ----
  WorkoutCollectionDefinition(
    id: 'face-sculpting-routine',
    title: 'Face Sculpting Routine',
    description: 'Targeted massage techniques to define and tone facial '
        'muscles.',
    categories: [ExerciseCategory.facialMassage],
    targetDifficulty: ExerciseDifficulty.intermediate,
    exerciseCount: 4,
    tier: WorkoutCollectionTier.intermediate,
    featured: true,
  ),
  WorkoutCollectionDefinition(
    id: 'advanced-posture-correction',
    title: 'Advanced Posture Correction',
    description: 'A more demanding posture sequence for building lasting '
        'shoulder and upper-back strength.',
    categories: [ExerciseCategory.shoulderPosture],
    targetDifficulty: ExerciseDifficulty.intermediate,
    exerciseCount: 4,
    tier: WorkoutCollectionTier.intermediate,
  ),
  WorkoutCollectionDefinition(
    id: 'deep-neck-mobility',
    title: 'Deep Neck Mobility',
    description: 'Isometric holds and controlled movement for deeper '
        'neck mobility work.',
    categories: [ExerciseCategory.neckMobility],
    targetDifficulty: ExerciseDifficulty.intermediate,
    exerciseCount: 4,
    tier: WorkoutCollectionTier.intermediate,
  ),
  WorkoutCollectionDefinition(
    id: 'facial-tension-reset',
    title: 'Facial Tension Reset',
    description: 'Combines face and jaw work to release tension that '
        'builds up across the whole face.',
    categories: [ExerciseCategory.facialMassage, ExerciseCategory.jawRelaxation],
    targetDifficulty: ExerciseDifficulty.intermediate,
    exerciseCount: 5,
    tier: WorkoutCollectionTier.intermediate,
  ),
  WorkoutCollectionDefinition(
    id: 'stress-relief-flow',
    title: 'Stress Relief Flow',
    description: 'Breathing techniques paired with facial release for a '
        'calmer state.',
    categories: [ExerciseCategory.breathing, ExerciseCategory.facialMassage],
    targetDifficulty: ExerciseDifficulty.intermediate,
    exerciseCount: 5,
    tier: WorkoutCollectionTier.intermediate,
  ),
  WorkoutCollectionDefinition(
    id: 'evening-recovery',
    title: 'Evening Recovery',
    description: 'Wind down with stretching and breathing before bed.',
    categories: [ExerciseCategory.stretching, ExerciseCategory.breathing],
    targetDifficulty: ExerciseDifficulty.intermediate,
    exerciseCount: 5,
    tier: WorkoutCollectionTier.intermediate,
  ),

  // ---- Advanced ----
  WorkoutCollectionDefinition(
    id: 'complete-face-wellness-session',
    title: 'Complete Face Wellness Session',
    description: 'A full, in-depth session covering every part of the '
        'face and jaw.',
    categories: [ExerciseCategory.facialMassage, ExerciseCategory.jawRelaxation],
    targetDifficulty: ExerciseDifficulty.advanced,
    exerciseCount: 7,
    tier: WorkoutCollectionTier.advanced,
    featured: true,
  ),
  WorkoutCollectionDefinition(
    id: 'full-recovery-routine',
    title: 'Full Recovery Routine',
    description: 'An extended stretching and breathing session for deep '
        'recovery.',
    categories: [ExerciseCategory.stretching, ExerciseCategory.breathing],
    targetDifficulty: ExerciseDifficulty.advanced,
    exerciseCount: 6,
    tier: WorkoutCollectionTier.advanced,
  ),
  WorkoutCollectionDefinition(
    id: 'upper-body-mobility-flow',
    title: 'Upper Body Mobility Flow',
    description: 'An advanced flow through the neck and shoulders for '
        'full upper-body mobility.',
    categories: [ExerciseCategory.neckMobility, ExerciseCategory.shoulderPosture],
    targetDifficulty: ExerciseDifficulty.advanced,
    exerciseCount: 7,
    tier: WorkoutCollectionTier.advanced,
  ),
  WorkoutCollectionDefinition(
    id: 'advanced-stretching',
    title: 'Advanced Stretching',
    description: 'A deeper stretching sequence for building long-term '
        'flexibility.',
    categories: [ExerciseCategory.stretching],
    targetDifficulty: ExerciseDifficulty.advanced,
    exerciseCount: 4,
    tier: WorkoutCollectionTier.advanced,
  ),
  WorkoutCollectionDefinition(
    id: 'daily-wellness-pro',
    title: 'Daily Wellness Pro',
    description: 'The complete session — every category, for a full '
        'daily wellness practice.',
    categories: [
      ExerciseCategory.jawRelaxation,
      ExerciseCategory.neckMobility,
      ExerciseCategory.shoulderPosture,
      ExerciseCategory.facialMassage,
      ExerciseCategory.breathing,
      ExerciseCategory.stretching,
    ],
    targetDifficulty: ExerciseDifficulty.advanced,
    exerciseCount: 10,
    tier: WorkoutCollectionTier.advanced,
    featured: true,
  ),
];
