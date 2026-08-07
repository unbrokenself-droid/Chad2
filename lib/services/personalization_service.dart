import '../models/exercise.dart';
import 'onboarding_service.dart';

/// Turns a user's onboarding answers (goals + experience level) into
/// concrete personalization: which [ExerciseCategory]s to prioritize
/// (via [categoriesFor]), a home-screen greeting, and a one-line
/// rationale for today's routine.
///
/// Building the actual routine — including mapping difficulty to an
/// [ExerciseDifficulty] preference — lives in [DailyRoutineService]
/// now, not here: this service only supplies the *ordering* a
/// generated routine's categories should follow, not which exercises
/// get picked or how many. (An earlier version of this service did
/// build full routines directly; see [DailyRoutineService]'s own doc
/// comment for why that moved.)
///
/// This intentionally does not invent new exercises or claim any
/// clinical effect — it only reorders and filters the existing,
/// evidence-informed catalog (gentle stretching, massage, and
/// breathing techniques) toward what the user said they care about.
/// None of this diagnoses or treats any medical condition; jaw/TMJ
/// and neck-disc precautions already present on individual exercises
/// are left untouched and still surfaced to the user.
class PersonalizationService {
  const PersonalizationService();

  /// Maps each onboarding goal to the exercise categories most
  /// relevant to it, ordered by relevance. `skincareConsistency` and
  /// `hydration` don't correspond to an exercise category (they're
  /// tracked elsewhere in the app, via [SkincareService] and
  /// [HydrationService]), so they aren't included here — see
  /// [nonExerciseGoalTips] for how those two are handled instead.
  static const Map<OnboardingGoal, List<ExerciseCategory>>
  _goalToCategories = {
    OnboardingGoal.jawRelaxation: [
      ExerciseCategory.jawRelaxation,
      ExerciseCategory.facialMassage,
      ExerciseCategory.breathing,
    ],
    OnboardingGoal.betterPosture: [
      ExerciseCategory.shoulderPosture,
      ExerciseCategory.stretching,
      ExerciseCategory.neckMobility,
    ],
    OnboardingGoal.neckMobility: [
      ExerciseCategory.neckMobility,
      ExerciseCategory.stretching,
    ],
  };

  /// The two onboarding goals that aren't primarily about exercises —
  /// surfaced as short, evidence-based habit tips instead of routine
  /// categories.
  static const Map<OnboardingGoal, String> nonExerciseGoalTips = {
    OnboardingGoal.skincareConsistency:
        'Try anchoring your skincare steps to something you already do '
        'daily, like brushing your teeth — habit stacking makes '
        'consistency easier than relying on willpower alone.',
    OnboardingGoal.hydration:
        'Keep a water bottle somewhere visible. Thirst is a lagging '
        'signal, so sipping on a regular schedule works better than '
        'waiting until you feel thirsty.',
  };

  /// Returns the exercise categories to prioritize for [goals], most
  /// relevant first, with duplicates removed. Falls back to a
  /// balanced default set if no selected goal maps to a category
  /// (e.g. the user only picked skincare/hydration, or skipped this
  /// step entirely).
  List<ExerciseCategory> categoriesFor(Set<OnboardingGoal> goals) {
    final ordered = <ExerciseCategory>[];
    for (final goal in goals) {
      final categories = _goalToCategories[goal];
      if (categories == null) continue;
      for (final category in categories) {
        if (!ordered.contains(category)) ordered.add(category);
      }
    }
    if (ordered.isEmpty) {
      return const [
        ExerciseCategory.jawRelaxation,
        ExerciseCategory.neckMobility,
        ExerciseCategory.shoulderPosture,
        ExerciseCategory.breathing,
      ];
    }
    // Always round out with breathing if it isn't already prioritized
    // — a short breathing exercise is a reasonable default this catalog
    // supports.
    if (!ordered.contains(ExerciseCategory.breathing)) {
      ordered.add(ExerciseCategory.breathing);
    }
    return ordered;
  }

  /// A short, personalized home-screen greeting. Uses the time of day,
  /// the user's name if given, and their top goal if any were
  /// selected. Falls back gracefully at every level (no name, no
  /// goals) so it never reads as broken or half-filled-in.
  String greeting({
    required int hour,
    String? name,
    required Set<OnboardingGoal> goals,
  }) {
    final timeGreeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    final trimmedName = name?.trim();
    final namePart =
        (trimmedName != null && trimmedName.isNotEmpty) ? ', $trimmedName' : '';

    if (goals.isEmpty) {
      return '$timeGreeting$namePart';
    }

    final topGoal = goals.first;
    final focusPhrase = switch (topGoal) {
      OnboardingGoal.jawRelaxation => "let's ease that jaw tension",
      OnboardingGoal.betterPosture => "let's work on that posture",
      OnboardingGoal.neckMobility => "let's loosen up your neck",
      OnboardingGoal.skincareConsistency => "let's keep your skincare streak going",
      OnboardingGoal.hydration => "let's get your water in today",
    };
    return '$timeGreeting$namePart — $focusPhrase';
  }

  /// A one-line rationale for why today's routine looks the way it
  /// does, shown above the routine card so the personalization is
  /// visible rather than silent. Falls back to a neutral description
  /// if no goals were selected.
  String routineRationale(Set<OnboardingGoal> goals) {
    if (goals.isEmpty) {
      return 'A balanced mix of jaw, neck, posture, and breathing exercises.';
    }
    final labels = goals.map((g) => g.label.toLowerCase()).join(', ');
    return 'Prioritized for your goals: $labels.';
  }
}
