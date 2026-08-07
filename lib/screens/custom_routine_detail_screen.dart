import 'package:flutter/material.dart';

import '../models/custom_routine.dart';
import '../models/exercise.dart';
import '../services/custom_routines_scope.dart';
import '../services/exercise_repository.dart';
import '../widgets/custom_routines/routine_exercise_picker_sheet.dart';
import '../widgets/custom_routines/routine_exercise_tile.dart';
import '../widgets/custom_routines/routine_name_dialog.dart';
import '../widgets/shared/primary_button.dart';

/// Detail/edit screen for a single [CustomRoutine].
///
/// Lets the user rename the routine, add exercises from the full
/// catalog (via [RoutineExercisePickerSheet]), remove exercises, and
/// reorder them by dragging (via [ReorderableListView]). Every change
/// goes straight through [CustomRoutinesService], which persists it
/// locally, so nothing here needs an explicit "Save" step — edits
/// stick immediately, the same way removing an exercise from today's
/// plan does on [RoutineScreen].
///
/// The routine is looked up live from [CustomRoutinesScope] by id on
/// every build rather than held in local state, so if it's deleted
/// out from under this screen (unlikely, since deletion only happens
/// from the list screen, but defended against anyway) this pops
/// itself rather than showing stale or null data.
class CustomRoutineDetailScreen extends StatefulWidget {
  const CustomRoutineDetailScreen({super.key, required this.routineId});

  final String routineId;

  @override
  State<CustomRoutineDetailScreen> createState() =>
      _CustomRoutineDetailScreenState();
}

class _CustomRoutineDetailScreenState
    extends State<CustomRoutineDetailScreen> {
  static const ExerciseRepository _repository = ExerciseRepository();

  late Future<List<Exercise>> _catalogFuture;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _repository.loadExercises();
  }

  Future<void> _rename(CustomRoutine routine) async {
    final service = CustomRoutinesScope.of(context);
    final newName = await RoutineNameDialog.show(
      context,
      title: 'Rename Routine',
      confirmLabel: 'Save',
      initialValue: routine.name,
    );
    if (newName == null || !mounted) return;
    await service.renameRoutine(routine.id, newName);
  }

  Future<void> _addExercise(
    CustomRoutine routine,
    List<Exercise> catalog,
  ) async {
    final service = CustomRoutinesScope.of(context);
    final selected = await RoutineExercisePickerSheet.show(
      context,
      catalog: catalog,
      alreadyInRoutine: routine.exerciseIds.toSet(),
    );
    if (selected == null || !mounted) return;
    await service.addExercise(routine.id, selected.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Added ${selected.title}')));
  }

  Future<void> _removeExerciseAt(CustomRoutine routine, int index) async {
    final service = CustomRoutinesScope.of(context);
    await service.removeExerciseAt(routine.id, index);
  }

  Future<void> _reorder(
    CustomRoutine routine,
    int oldIndex,
    int newIndex,
  ) async {
    final service = CustomRoutinesScope.of(context);
    await service.reorderExercise(routine.id, oldIndex, newIndex);
  }

  @override
  Widget build(BuildContext context) {
    final routinesService = CustomRoutinesScope.of(context);
    final routine = routinesService.routineById(widget.routineId);

    if (routine == null) {
      // The routine was deleted (e.g. from the list screen) while
      // this was open; there's nothing left to show here.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(routine.name),
        actions: [
          IconButton(
            onPressed: () => _rename(routine),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename routine',
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Exercise>>(
          future: _catalogFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(
                onRetry: () => setState(() {
                  _catalogFuture = _repository.loadExercises();
                }),
              );
            }

            final catalog = snapshot.data ?? const [];
            final catalogById = {for (final e in catalog) e.id: e};
            final exercises = [
              for (final id in routine.exerciseIds)
                if (catalogById.containsKey(id)) catalogById[id]!,
            ];

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                final horizontalPadding = isWide ? 32.0 : 20.0;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      children: [
                        Expanded(
                          child: exercises.isEmpty
                              ? _EmptyRoutineMessage(
                                  onAddExercise: () =>
                                      _addExercise(routine, catalog),
                                )
                              : ReorderableListView.builder(
                                  padding: EdgeInsets.fromLTRB(
                                    horizontalPadding,
                                    16,
                                    horizontalPadding,
                                    16,
                                  ),
                                  itemCount: exercises.length,
                                  // Deliberately still on `onReorder`.
                                  // The replacement, `onReorderItem`,
                                  // pre-adjusts newIndex for the removed
                                  // item — which CustomRoutinesService
                                  // .reorderExercise already does itself,
                                  // so migrating means changing both or
                                  // the adjustment double-applies and
                                  // reordering silently breaks. Worth
                                  // doing, but only once `onReorderItem`
                                  // has landed on the stable channel CI
                                  // builds against: it was added after
                                  // v3.41.0-0.0.pre (a pre-release), and
                                  // adopting it early would turn this
                                  // info-level deprecation into a build
                                  // failure there.
                                  // ignore: deprecated_member_use
                                  onReorder: (oldIndex, newIndex) =>
                                      _reorder(routine, oldIndex, newIndex),
                                  itemBuilder: (context, index) {
                                    final exercise = exercises[index];
                                    return RoutineExerciseTile(
                                      key: ValueKey(
                                        'reorder-${routine.id}-$index',
                                      ),
                                      exercise: exercise,
                                      position: index + 1,
                                      onRemove: () =>
                                          _removeExerciseAt(routine, index),
                                    );
                                  },
                                ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            0,
                            horizontalPadding,
                            16,
                          ),
                          child: PrimaryButton(
                            label: 'Add Exercise',
                            icon: Icons.add,
                            onPressed: () => _addExercise(routine, catalog),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Shown in the exercise list area when the routine has no exercises
/// yet, with a shortcut straight into the picker so an empty routine
/// never feels like a dead end.
class _EmptyRoutineMessage extends StatelessWidget {
  const _EmptyRoutineMessage({required this.onAddExercise});

  final VoidCallback onAddExercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.playlist_add,
              size: 56,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No exercises yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add exercises to build out this routine.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: PrimaryButton(
                label: 'Add Exercise',
                icon: Icons.add,
                onPressed: onAddExercise,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown if the exercise catalog fails to load, with a retry action.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(
              "Couldn't load exercises",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: PrimaryButton(label: 'Try Again', onPressed: onRetry),
            ),
          ],
        ),
      ),
    );
  }
}
