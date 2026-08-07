import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../exercises/exercise_card.dart' show ExerciseCategoryLabel;

/// A modal bottom sheet listing every exercise in [category] other
/// than [currentExerciseId], so the user can pick one to swap in for
/// today's routine.
///
/// Returns the selected [Exercise] via [Navigator.pop], or `null` if
/// the sheet is dismissed without a selection.
class RoutineReplacementSheet extends StatelessWidget {
  const RoutineReplacementSheet({
    super.key,
    required this.category,
    required this.currentExerciseId,
    required this.candidates,
  });

  final ExerciseCategory category;
  final String currentExerciseId;

  /// Every other exercise in [category] the user could swap in
  /// (already excludes [currentExerciseId] and anything else already
  /// in today's routine — see [RoutineScreen]).
  final List<Exercise> candidates;

  /// Shows the sheet and returns the exercise the user picked, if any.
  static Future<Exercise?> show(
    BuildContext context, {
    required ExerciseCategory category,
    required String currentExerciseId,
    required List<Exercise> candidates,
  }) {
    return showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (context) => RoutineReplacementSheet(
        category: category,
        currentExerciseId: currentExerciseId,
        candidates: candidates,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Replace exercise',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pick another ${category.label.toLowerCase()} '
                              'exercise for today',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: candidates.isEmpty
                      ? _EmptyCandidatesMessage(category: category)
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                          itemCount: candidates.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final exercise = candidates[index];
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              leading: CircleAvatar(
                                backgroundColor:
                                    colorScheme.primary.withValues(alpha: 0.12),
                                foregroundColor: colorScheme.primary,
                                child: Icon(exercise.icon, size: 20),
                              ),
                              title: Text(
                                exercise.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                exercise.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () =>
                                  Navigator.of(context).pop(exercise),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Shown instead of the list when there are no other exercises left
/// in this category to swap in (e.g. the catalog only has one).
class _EmptyCandidatesMessage extends StatelessWidget {
  const _EmptyCandidatesMessage({required this.category});

  final ExerciseCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: 32,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No other ${category.label.toLowerCase()} exercises available '
            'to swap in right now.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
