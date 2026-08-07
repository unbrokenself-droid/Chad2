import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../services/completion_scope.dart';
import '../services/favorites_scope.dart';
import '../widgets/exercises/exercise_badge_content.dart';
import '../widgets/exercises/exercise_card.dart';
import '../widgets/exercises/exercise_narration_controls.dart';
import '../widgets/exercises/exercise_video_preview.dart';
import '../widgets/shared/fade_through_page_route.dart';
import '../widgets/shared/favorite_heart_button.dart';
import '../widgets/shared/primary_button.dart';
import 'workout_session_screen.dart';

/// Full detail view for a single [Exercise].
///
/// Shows the exercise's title, description, step-by-step instructions,
/// duration, difficulty, and any safety precautions — plus, for
/// exercises that have one ([Exercise.videoAsset] non-null), a looping
/// preview clip via [ExerciseVideoPreview]. [ExerciseNarrationControls]
/// offers play/pause/resume/stop/skip/replay controls for having the
/// title and instructions read aloud instead. "Start" launches
/// [WorkoutSessionScreen] with a single-exercise queue — the same
/// continuous-session screen [RoutineScreen]'s "Start Routine" uses
/// for a whole routine, here just running the one exercise, complete
/// with its video, spoken instructions, and background music. The
/// separate "Mark as Complete" toggle remains for quickly logging the
/// exercise without running that session at all.
class ExerciseDetailsScreen extends StatelessWidget {
  const ExerciseDetailsScreen({super.key, required this.exercise});

  final Exercise exercise;

  Future<void> _markCompleted(BuildContext context) async {
    final completion = CompletionScope.of(context);
    await completion.markCompleted(exercise.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${exercise.title}" marked complete for today'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => completion.markIncomplete(exercise.id),
          ),
        ),
      );
  }

  Future<void> _markIncomplete(BuildContext context) async {
    final completion = CompletionScope.of(context);
    await completion.markIncomplete(exercise.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${exercise.title}" marked incomplete'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => completion.markCompleted(exercise.id),
          ),
        ),
      );
  }

  /// Launches [WorkoutSessionScreen] with a single-exercise queue —
  /// the same continuous-session screen [RoutineScreen]'s "Start
  /// Routine" uses, just with one exercise in it instead of several.
  ///
  /// This used to push `GuidedSessionScreen` instead: a separate,
  /// simpler implementation of "run a timed exercise" that predates
  /// [WorkoutSessionManager] and never gained video, spoken
  /// instructions, or background music once those were added there —
  /// building a *third* parallel implementation of the same idea to
  /// give this path those too would have directly contradicted
  /// [WorkoutSessionManager]'s own "don't duplicate logic already
  /// used by the Exercise library" design goal. `GuidedSessionScreen`
  /// itself is unreachable from anywhere in the app now, but left in
  /// place rather than deleted — see this file's git history/PR notes
  /// if it's ever needed again.
  void _startSession(BuildContext context) {
    Navigator.of(context).push(
      FadeThroughPageRoute(
        builder: (context) => WorkoutSessionScreen(exercises: [exercise]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final difficultyColor = exercise.difficulty.color;
    final videoAsset = exercise.videoAsset;

    final favorites = FavoritesScope.of(context);
    final completion = CompletionScope.of(context);
    final completedToday = completion.isCompletedToday(exercise.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FavoriteHeartButton(
              isFavorite: favorites.isFavorite(exercise.id),
              onToggle: () => favorites.toggle(exercise.id),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            final horizontalPadding = isWide ? 32.0 : 20.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          20,
                          horizontalPadding,
                          16,
                        ),
                        children: [
                          _HeaderBlock(
                            exercise: exercise,
                            difficultyColor: difficultyColor,
                          ),
                          if (videoAsset != null) ...[
                            const SizedBox(height: 20),
                            ExerciseVideoPreview(assetPath: videoAsset),
                          ],
                          const SizedBox(height: 24),
                          Text(
                            exercise.description,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _SectionTitle(
                            icon: Icons.format_list_numbered,
                            label: 'Instructions',
                          ),
                          const SizedBox(height: 12),
                          ExerciseNarrationControls(exercise: exercise),
                          const SizedBox(height: 16),
                          _InstructionsList(
                            instructions: exercise.instructions,
                          ),
                          if (exercise.precautions.isNotEmpty) ...[
                            const SizedBox(height: 28),
                            _SectionTitle(
                              icon: Icons.shield_outlined,
                              label: 'Safety precautions',
                            ),
                            const SizedBox(height: 12),
                            _PrecautionsCard(
                              precautions: exercise.precautions,
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    // Anchored action bar rather than an inline button
                    // at the end of the scrolling list, so the actions
                    // are always reachable without scrolling to the
                    // end regardless of how long the instructions get.
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        12,
                        horizontalPadding,
                        16,
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PrimaryButton(
                              label: 'Start',
                              icon: Icons.play_arrow_rounded,
                              onPressed: () => _startSession(context),
                            ),
                            const SizedBox(height: 10),
                            completedToday
                                ? PrimaryButton(
                                    label: 'Completed Today',
                                    icon: Icons.check_circle,
                                    backgroundColor:
                                        colorScheme.primary.withValues(
                                      alpha: 0.14,
                                    ),
                                    foregroundColor: colorScheme.primary,
                                    onPressed: () =>
                                        _markIncomplete(context),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: () => _markCompleted(context),
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                    ),
                                    label: const Text('Mark as Complete'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize:
                                          const Size(double.infinity, 48),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Icon badge, title, and the duration/difficulty/body-part facts
/// shown at the top of the details page.
class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({required this.exercise, required this.difficultyColor});

  final Exercise exercise;
  final Color difficultyColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Hero(
          tag: ExerciseCard.heroTag(exercise.id),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: ExerciseBadgeContent(
              exercise: exercise,
              size: 64,
              iconSize: 32,
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _InfoChip(
                    icon: Icons.schedule,
                    label: formatExerciseDuration(exercise.duration),
                  ),
                  _InfoChip(
                    icon: Icons.accessibility_new,
                    label: exercise.bodyPart.label,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: difficultyColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: difficultyColor.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          exercise.difficulty.icon,
                          size: 13,
                          color: difficultyColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          exercise.difficulty.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: difficultyColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A small neutral chip used for the duration and body-part facts in
/// the header (visually distinct from the colored difficulty chip).
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small section label with a leading icon, used above the
/// Instructions and Safety precautions blocks.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// A numbered list of step-by-step instructions.
class _InstructionsList extends StatelessWidget {
  const _InstructionsList({required this.instructions});

  final List<String> instructions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        for (var i = 0; i < instructions.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == instructions.length - 1 ? 0 : 12,
            ),
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
                      instructions[i],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A warning-styled card listing safety precautions, only shown when
/// an exercise has at least one.
class _PrecautionsCard extends StatelessWidget {
  const _PrecautionsCard({required this.precautions});

  final List<String> precautions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A warm amber tone reads as "caution" more clearly than the app's
    // blue accent would here; kept scoped to this one card rather than
    // widening the palette elsewhere.
    const warningColor = Color(0xFFB8860B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warningColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < precautions.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == precautions.length - 1 ? 0 : 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: warningColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      precautions[i],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
