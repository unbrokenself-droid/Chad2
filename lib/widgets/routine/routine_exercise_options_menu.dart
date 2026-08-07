import 'package:flutter/material.dart';

import '../shared/min_tap_target.dart';

/// The action a user picked from [RoutineExerciseOptionsMenu].
enum RoutineExerciseAction {
  /// Swap this exercise for another one in the same category.
  replace,

  /// Drop this exercise from today's routine entirely.
  remove,
}

/// The small "more options" icon button shown on each exercise card in
/// [RoutineScreen], offering to replace or remove that exercise from
/// today's routine.
///
/// Kept as its own widget (rather than inlined in the screen) so the
/// menu's styling — sized to sit comfortably next to the favorite
/// heart button — stays in one place.
class RoutineExerciseOptionsMenu extends StatelessWidget {
  const RoutineExerciseOptionsMenu({
    super.key,
    required this.onSelected,
  });

  final ValueChanged<RoutineExerciseAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // splashRadius: 18 gives a 36px tap diameter on its own — below
    // the accessible minimum, which is exactly the gap MinTapTarget
    // exists to close. PopupMenuButton has no minimumSize-style
    // property of its own to set directly (unlike PrimaryButton or
    // the filter chips), so wrapping it is the right approach here,
    // not a fallback.
    return MinTapTarget(
      child: PopupMenuButton<RoutineExerciseAction>(
        onSelected: onSelected,
        tooltip: 'Exercise options',
        icon: Icon(
          Icons.more_vert,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
        splashRadius: 18,
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: RoutineExerciseAction.replace,
            child: Row(
              children: [
                Icon(Icons.swap_horiz),
                SizedBox(width: 12),
                Text('Replace exercise'),
              ],
            ),
          ),
          PopupMenuItem(
            value: RoutineExerciseAction.remove,
            child: Row(
              children: [
                Icon(Icons.remove_circle_outline),
                SizedBox(width: 12),
                Text('Remove from today'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
