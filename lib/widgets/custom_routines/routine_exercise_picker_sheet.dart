import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../exercises/exercise_card.dart' show ExerciseBodyPartLabel;

/// A modal bottom sheet listing the full exercise catalog with a
/// search field, so the user can pick one to add to a custom routine.
///
/// Unlike [RoutineReplacementSheet] (which only offers same-category
/// swaps for today's auto-generated routine), this offers every
/// exercise in the catalog — a custom routine is free-form and can mix
/// categories. Exercises already in the routine are marked with a
/// check rather than hidden, since [CustomRoutinesService.addExercise]
/// allows duplicates (e.g. for a second round of the same move).
///
/// Returns the selected [Exercise] via [Navigator.pop], or `null` if
/// the sheet is dismissed without a selection.
class RoutineExercisePickerSheet extends StatefulWidget {
  const RoutineExercisePickerSheet({
    super.key,
    required this.catalog,
    required this.alreadyInRoutine,
  });

  /// The full exercise catalog to pick from.
  final List<Exercise> catalog;

  /// Ids currently in the routine, used only to show a check mark
  /// next to already-added exercises — doesn't filter them out.
  final Set<String> alreadyInRoutine;

  /// Shows the sheet and returns the exercise the user picked, if any.
  static Future<Exercise?> show(
    BuildContext context, {
    required List<Exercise> catalog,
    required Set<String> alreadyInRoutine,
  }) {
    return showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (context) => RoutineExercisePickerSheet(
        catalog: catalog,
        alreadyInRoutine: alreadyInRoutine,
      ),
    );
  }

  @override
  State<RoutineExercisePickerSheet> createState() =>
      _RoutineExercisePickerSheetState();
}

class _RoutineExercisePickerSheetState
    extends State<RoutineExercisePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == _query) return;
    setState(() => _query = normalized);
  }

  List<Exercise> get _filtered {
    if (_query.isEmpty) return widget.catalog;
    return widget.catalog.where((exercise) {
      return exercise.title.toLowerCase().contains(_query) ||
          exercise.bodyPart.label.toLowerCase().contains(_query) ||
          exercise.description.toLowerCase().contains(_query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final results = _filtered;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
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
                        child: Text(
                          'Add exercise',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _handleChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search exercises',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: results.isEmpty
                      ? _NoResultsMessage(query: _query)
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                          itemCount: results.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final exercise = results[index];
                            final alreadyAdded =
                                widget.alreadyInRoutine.contains(exercise.id);
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
                              trailing: alreadyAdded
                                  ? Icon(
                                      Icons.check_circle,
                                      color: colorScheme.primary,
                                    )
                                  : const Icon(Icons.add_circle_outline),
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

/// Shown instead of the list when a search query matches nothing.
class _NoResultsMessage extends StatelessWidget {
  const _NoResultsMessage({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 32, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'No exercises match "$query".',
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
