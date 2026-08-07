import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../exercises/exercise_card.dart' show formatExerciseDuration;

/// A single exercise row within a custom routine's editable list.
///
/// Simpler than the full [ExerciseCard] used in the catalog — this is
/// a compact [ListTile]-based row meant for [ReorderableListView],
/// with a drag handle, position number, and a remove button, rather
/// than the card's rich badges. Reordering is the primary interaction
/// here, so the row stays low-profile and quick to scan.
class RoutineExerciseTile extends StatelessWidget {
  const RoutineExerciseTile({
    super.key,
    required this.exercise,
    required this.position,
    required this.onRemove,
  });

  final Exercise exercise;

  /// This exercise's 1-based position in the routine, shown as a
  /// small index so the order is legible even before dragging.
  final int position;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: ValueKey('routine-exercise-tile-${exercise.id}-$position'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 8, right: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$position',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 20,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
              foregroundColor: colorScheme.primary,
              child: Icon(exercise.icon, size: 20),
            ),
          ],
        ),
        title: Text(
          exercise.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(formatExerciseDuration(exercise.duration)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Remove from routine',
              color: colorScheme.error,
            ),
            Icon(Icons.drag_handle, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
