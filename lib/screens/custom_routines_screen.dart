import 'package:flutter/material.dart';

import '../models/custom_routine.dart';
import '../models/premium_feature.dart';
import '../services/custom_routines_scope.dart';
import '../services/premium_scope.dart';
import '../utils/app_haptics.dart';
import '../widgets/custom_routines/routine_name_dialog.dart';
import '../widgets/premium/upgrade_card.dart';
import '../widgets/shared/fade_through_page_route.dart';
import '../widgets/shared/primary_button.dart';
import '../widgets/shared/section_header.dart';
import '../widgets/shared/staggered_entrance.dart';
import 'custom_routine_detail_screen.dart';

/// Lists every custom routine the user has created, with actions to
/// create a new one, rename or delete an existing one, or open one to
/// edit its exercises.
///
/// Reached from [RoutineScreen] (a "My Routines" action in the app
/// bar), rather than being its own bottom-nav tab, since custom
/// routines are a secondary, opt-in feature alongside the
/// auto-generated daily plan that screen already shows.
class CustomRoutinesScreen extends StatelessWidget {
  const CustomRoutinesScreen({super.key});

  Future<void> _createRoutine(BuildContext context) async {
    final service = CustomRoutinesScope.of(context);
    final name = await RoutineNameDialog.show(
      context,
      title: 'New Routine',
      confirmLabel: 'Create',
    );
    if (name == null || !context.mounted) return;
    final routine = await service.createRoutine(name);
    if (!context.mounted) return;
    Navigator.of(context).push(
      FadeThroughPageRoute(
        builder: (context) =>
            CustomRoutineDetailScreen(routineId: routine.id),
      ),
    );
  }

  Future<void> _renameRoutine(
    BuildContext context,
    CustomRoutine routine,
  ) async {
    final service = CustomRoutinesScope.of(context);
    final newName = await RoutineNameDialog.show(
      context,
      title: 'Rename Routine',
      confirmLabel: 'Save',
      initialValue: routine.name,
    );
    if (newName == null || !context.mounted) return;
    await service.renameRoutine(routine.id, newName);
  }

  Future<void> _deleteRoutine(
    BuildContext context,
    CustomRoutine routine,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete routine?'),
        content: Text(
          '"${routine.name}" and its exercise list will be permanently '
          'deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    AppHaptics.heavy();
    final service = CustomRoutinesScope.of(context);
    await service.deleteRoutine(routine.id);
  }

  void _openRoutine(BuildContext context, CustomRoutine routine) {
    Navigator.of(context).push(
      FadeThroughPageRoute(
        builder: (context) =>
            CustomRoutineDetailScreen(routineId: routine.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final premium = PremiumScope.of(context);
    final routinesService = CustomRoutinesScope.of(context);
    final routines = routinesService.routines;
    final isUnlocked = premium.isUnlocked(PremiumFeature.customRoutines);

    return Scaffold(
      appBar: AppBar(title: const Text('My Routines')),
      body: SafeArea(
        child: !isUnlocked
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: UpgradeCard(feature: PremiumFeature.customRoutines),
              )
            : LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            final horizontalPadding = isWide ? 32.0 : 20.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: !routinesService.isLoaded
                    ? const Center(child: CircularProgressIndicator())
                    : routines.isEmpty
                        ? _EmptyState(
                            onCreate: () => _createRoutine(context),
                          )
                        : ListView(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              20,
                              horizontalPadding,
                              100,
                            ),
                            children: [
                              SectionHeader(
                                size: SectionHeaderSize.large,
                                subtitle: 'Custom Routines',
                                title: '${routines.length} saved',
                              ),
                              const SizedBox(height: 20),
                              for (var i = 0; i < routines.length; i++)
                                StaggeredEntrance(
                                  index: i,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12,
                                    ),
                                    child: _RoutineListTile(
                                      routine: routines[i],
                                      onTap: () =>
                                          _openRoutine(context, routines[i]),
                                      onRename: () =>
                                          _renameRoutine(context, routines[i]),
                                      onDelete: () =>
                                          _deleteRoutine(context, routines[i]),
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
      floatingActionButton: !isUnlocked
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _createRoutine(context),
              icon: const Icon(Icons.add),
              label: const Text('New Routine'),
            ),
    );
  }
}

/// A single routine's row in the list: name, exercise count, and a
/// "more options" menu for rename/delete.
class _RoutineListTile extends StatelessWidget {
  const _RoutineListTile({
    required this.routine,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final CustomRoutine routine;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final count = routine.exerciseIds.length;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.playlist_play,
                  color: colorScheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 1 ? '1 exercise' : '$count exercises',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_RoutineMenuAction>(
                tooltip: 'Routine options',
                icon: Icon(
                  Icons.more_vert,
                  color: colorScheme.onSurfaceVariant,
                ),
                onSelected: (action) {
                  switch (action) {
                    case _RoutineMenuAction.rename:
                      onRename();
                    case _RoutineMenuAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _RoutineMenuAction.rename,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 12),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _RoutineMenuAction.delete,
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline),
                        SizedBox(width: 12),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _RoutineMenuAction { rename, delete }

/// Shown when the user has no custom routines yet, with a shortcut
/// straight into creating the first one.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

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
              Icons.playlist_add_check_circle_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No custom routines yet',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Build your own routine from any exercises in the '
              'library, in whatever order you like.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: PrimaryButton(
                label: 'Create Routine',
                icon: Icons.add,
                onPressed: onCreate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
