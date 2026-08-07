import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../models/workout_collection.dart';
import '../services/completion_scope.dart';
import '../services/premium_scope.dart';
import '../services/workout_unlock_scope.dart';
import '../widgets/ads/adaptive_banner_ad.dart';
import '../widgets/exercises/exercise_card.dart';
import '../widgets/exercises/workout_unlock_sheet.dart';
import '../widgets/shared/fade_through_page_route.dart';
import '../widgets/shared/primary_button.dart';
import 'exercise_details_screen.dart';
import 'workout_session_screen.dart';

/// One-line benefit copy per [ExerciseCategory], shown on
/// [WorkoutCollectionDetailsScreen] for whichever categories a given
/// collection actually draws from — generated from the collection's
/// own [WorkoutCollectionDefinition.categories] rather than
/// hand-written per collection, so it can't drift out of sync with
/// what a collection actually contains.
const Map<ExerciseCategory, String> _categoryBenefits = {
  ExerciseCategory.jawRelaxation: 'Relieves jaw tension and clenching',
  ExerciseCategory.neckMobility: 'Increases neck range of motion',
  ExerciseCategory.shoulderPosture: 'Corrects posture and opens the chest',
  ExerciseCategory.facialMassage: 'Improves circulation and reduces puffiness',
  ExerciseCategory.breathing: 'Reduces stress and promotes relaxation',
  ExerciseCategory.stretching: 'Improves flexibility and reduces stiffness',
};

/// Full details for one [WorkoutCollection] — hero, description,
/// benefits, difficulty/duration, the resolved exercise list, and a
/// "Start Workout" button.
///
/// "Start Workout" pushes the exact same [WorkoutSessionScreen] that
/// [RoutineScreen]'s "Start Routine" does, just given this
/// collection's exercises instead of today's daily routine — see
/// [WorkoutCollection]'s own doc comment for why that's what gives
/// collections progressive overload, completion tracking, favorites,
/// and statistics automatically, with nothing collection-specific to
/// build for any of it.
///
/// A locked collection (see [WorkoutCollectionCard]'s doc comment for
/// exactly when that is) can still be opened and browsed here — the
/// exercise list, benefits, and stats are all visible either way — but
/// its "Start Workout" button opens [WorkoutUnlockSheet] instead of
/// actually starting anything, the same as tapping a locked card
/// directly would. There's no way to reach a real session for a
/// locked collection except through unlocking it first.
class WorkoutCollectionDetailsScreen extends StatelessWidget {
  const WorkoutCollectionDetailsScreen({super.key, required this.collection});

  final WorkoutCollection collection;

  static const Map<WorkoutCollectionTier, Color> _tierColors = {
    WorkoutCollectionTier.beginner: Color(0xFF2E7D32),
    WorkoutCollectionTier.intermediate: Color(0xFF2962FF),
    WorkoutCollectionTier.advanced: Color(0xFFC2185B),
  };

  void _startWorkout(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            WorkoutSessionScreen(exercises: collection.exercises),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final completion = CompletionScope.of(context);
    final tierColor = _tierColors[collection.tier]!;
    final minutes = (collection.totalDuration.inSeconds / 60).ceil();
    final backgroundImage = collection.backgroundImage;

    final premium = PremiumScope.of(context);
    final unlockService = WorkoutUnlockScope.of(context);
    // Every collection is locked behind Premium/a rewarded-ad unlock
    // now, not just featured ones — matches WorkoutCollectionCard;
    // see that class's doc comment for the reasoning.
    final isLocked = !premium.isPremium && !unlockService.isUnlocked(collection.id);

    final categories = {
      for (final exercise in collection.exercises) exercise.category,
    };
    final benefits = [
      for (final category in ExerciseCategory.values)
        if (categories.contains(category)) _categoryBenefits[category]!,
    ];

    return Scaffold(
      bottomNavigationBar: const AdaptiveBannerAd(),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (backgroundImage != null)
                    Image.asset(
                      backgroundImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _HeroGradient(color: tierColor),
                    )
                  else
                    _HeroGradient(color: tierColor),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  collection.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  collection.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _StatPill(
                      icon: Icons.signal_cellular_alt_rounded,
                      label: collection.tier.label,
                      color: tierColor,
                    ),
                    const SizedBox(width: 10),
                    _StatPill(
                      icon: Icons.schedule_rounded,
                      label: '$minutes min',
                      color: tierColor,
                    ),
                    const SizedBox(width: 10),
                    _StatPill(
                      icon: Icons.format_list_numbered_rounded,
                      label: '${collection.exercises.length} exercises',
                      color: tierColor,
                    ),
                  ],
                ),
                if (isLocked) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This is a Premium workout. Watch an ad or '
                            'upgrade to unlock it.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (benefits.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text(
                    'Benefits',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final benefit in benefits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: tierColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              benefit,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Exercises',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < collection.exercises.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 14),
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: tierColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ExerciseCard(
                            exercise: collection.exercises[i].copyWith(
                              completed: completion.isCompletedToday(
                                collection.exercises[i].id,
                              ),
                            ),
                            onTap: () => Navigator.of(context).push(
                              FadeThroughPageRoute(
                                builder: (context) => ExerciseDetailsScreen(
                                  exercise: collection.exercises[i],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: isLocked ? 'Unlock to Start' : 'Start Workout',
                  icon: isLocked
                      ? Icons.lock_rounded
                      : Icons.play_arrow_rounded,
                  onPressed: collection.exercises.isEmpty
                      ? null
                      : isLocked
                      ? () => showWorkoutUnlockSheet(
                          context,
                          collection: collection,
                        )
                      : () => _startWorkout(context),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroGradient extends StatelessWidget {
  const _HeroGradient({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.55)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.self_improvement_rounded,
          size: 88,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
