import 'package:flutter/material.dart';

import '../../services/daily_routine_service.dart';
import '../../utils/app_haptics.dart';
import '../shared/primary_button.dart';

/// Opens the routine difficulty picker and returns the level the user
/// confirmed with "Done", or `null` if they dismissed the sheet or
/// tapped "Cancel" instead.
///
/// Convenience wrapper around [showModalBottomSheet], matching how
/// [showUnitsSheet] and [showNarrationSettingsSheet] are exposed, so
/// [RoutineScreen] doesn't need to know this sheet's shape/styling
/// details — it just awaits the result and, if non-null, hands it to
/// [DailyRoutineService.setDifficulty].
Future<RoutineDifficulty?> showRoutineDifficultySheet(
  BuildContext context, {
  required RoutineDifficulty currentDifficulty,
}) {
  return showModalBottomSheet<RoutineDifficulty>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        RoutineDifficultySheet(currentDifficulty: currentDifficulty),
  );
}

/// Lets the user pick today's (and every future day's, until changed
/// again) [RoutineDifficulty] — Beginner, Intermediate, or Advanced.
///
/// Purely a picker: selecting an option just highlights it, and
/// nothing is applied until "Done" is tapped, so a stray tap can't
/// silently change today's plan. Applying the choice (via
/// [DailyRoutineService.setDifficulty]) is [RoutineScreen]'s job, once
/// this sheet's [Navigator.pop] result comes back — this widget
/// itself doesn't touch [DailyRoutineService] at all.
class RoutineDifficultySheet extends StatefulWidget {
  const RoutineDifficultySheet({super.key, required this.currentDifficulty});

  /// Pre-selected when the sheet opens, so it's clear which level is
  /// already active rather than starting from a blank choice.
  final RoutineDifficulty currentDifficulty;

  @override
  State<RoutineDifficultySheet> createState() =>
      _RoutineDifficultySheetState();
}

class _RoutineDifficultySheetState extends State<RoutineDifficultySheet> {
  late RoutineDifficulty _selected = widget.currentDifficulty;

  static const Map<RoutineDifficulty, IconData> _icons = {
    RoutineDifficulty.beginner: Icons.spa_outlined,
    RoutineDifficulty.intermediate: Icons.trending_up_rounded,
    RoutineDifficulty.advanced: Icons.local_fire_department_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.tune_rounded, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Routine Difficulty',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Every category stays included — this changes '
                          'how much of each.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              for (final level in RoutineDifficulty.values) ...[
                _DifficultyOption(
                  label: level.label,
                  subtitle:
                      '${level.exercisesPerCategory} exercises per category',
                  icon: _icons[level]!,
                  selected: _selected == level,
                  onTap: () {
                    AppHaptics.selection();
                    setState(() => _selected = level);
                  },
                ),
                if (level != RoutineDifficulty.values.last)
                  const SizedBox(height: 10),
              ],
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Done',
                onPressed: () => Navigator.of(context).pop(_selected),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyOption extends StatelessWidget {
  const _DifficultyOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.12)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
