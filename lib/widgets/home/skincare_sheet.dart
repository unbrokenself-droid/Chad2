import 'package:flutter/material.dart';

import '../../services/skincare_scope.dart';
import '../../services/skincare_service.dart';
import '../../utils/app_haptics.dart';
import '../shared/primary_button.dart';

/// Opens the skincare routine tracking bottom sheet.
///
/// Convenience wrapper around [showModalBottomSheet] so callers (the
/// Home screen's "Skincare Check-in" reminder card) don't need to
/// know the sheet's shape/styling details.
Future<void> showSkincareSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const SkincareSheet(),
  );
}

/// Bottom sheet for checking off today's morning/night skincare steps
/// and customizing which steps each routine includes.
///
/// Reads and writes through [SkincareScope], so the checklist here
/// and the Home screen's reminder card stay in sync automatically.
class SkincareSheet extends StatefulWidget {
  const SkincareSheet({super.key});

  @override
  State<SkincareSheet> createState() => _SkincareSheetState();
}

class _SkincareSheetState extends State<SkincareSheet> {
  SkincareRoutine _selectedRoutine = SkincareRoutine.morning;
  bool _customizing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final skincare = SkincareScope.of(context);

    final steps = _customizing
        ? skincare.stepsFor(_selectedRoutine)
        : skincare.enabledStepsFor(_selectedRoutine);
    final completed = skincare.completedCountFor(_selectedRoutine);
    final total = skincare.totalCountFor(_selectedRoutine);
    final routineDone = skincare.isRoutineComplete(_selectedRoutine);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Skincare Routine',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _RoutineToggle(
                selected: _selectedRoutine,
                onChanged: (routine) {
                  setState(() => _selectedRoutine = routine);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _customizing
                        ? 'Choose steps for ${_selectedRoutine == SkincareRoutine.morning ? 'Morning' : 'Night'}'
                        : routineDone
                        ? '✅ All done for now'
                        : '$completed of $total steps done',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: routineDone && !_customizing
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: routineDone && !_customizing
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _customizing = !_customizing);
                    },
                    child: Text(_customizing ? 'Done' : 'Customize'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final step in steps)
                        _customizing
                            ? _StepEnableRow(
                                step: step,
                                routine: _selectedRoutine,
                                enabled: skincare.isStepEnabled(
                                  step,
                                  _selectedRoutine,
                                ),
                                onChanged: (enabled) => skincare
                                    .setStepEnabled(
                                      step,
                                      _selectedRoutine,
                                      enabled,
                                    ),
                              )
                            : _StepCheckRow(
                                step: step,
                                routine: _selectedRoutine,
                                checked: skincare.isStepCompleted(
                                  step,
                                  _selectedRoutine,
                                ),
                                onChanged: (_) => skincare.toggleStep(
                                  step,
                                  _selectedRoutine,
                                ),
                              ),
                      if (steps.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No steps enabled for this routine yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented Morning/Night switch at the top of the sheet.
class _RoutineToggle extends StatelessWidget {
  const _RoutineToggle({required this.selected, required this.onChanged});

  final SkincareRoutine selected;
  final ValueChanged<SkincareRoutine> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _RoutineToggleOption(
              label: 'Morning',
              icon: Icons.wb_sunny_outlined,
              selected: selected == SkincareRoutine.morning,
              onTap: () => onChanged(SkincareRoutine.morning),
            ),
          ),
          Expanded(
            child: _RoutineToggleOption(
              label: 'Night',
              icon: Icons.nightlight_outlined,
              selected: selected == SkincareRoutine.night,
              onTap: () => onChanged(SkincareRoutine.night),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineToggleOption extends StatelessWidget {
  const _RoutineToggleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: selected ? colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: () {
          if (!selected) AppHaptics.selection();
          onTap();
        },
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single checkable checklist row, e.g. "Cleanser" with a checkbox.
class _StepCheckRow extends StatelessWidget {
  const _StepCheckRow({
    required this.step,
    required this.routine,
    required this.checked,
    required this.onChanged,
  });

  final SkincareStep step;
  final SkincareRoutine routine;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.light();
          onChanged(!checked);
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: checked
                      ? colorScheme.primary.withValues(alpha: 0.12)
                      : colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  step.icon,
                  color: checked
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  step.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    color: checked
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                  ),
                ),
              ),
              Checkbox(
                value: checked,
                onChanged: (value) {
                  AppHaptics.light();
                  onChanged(value ?? false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single "enable this step for this routine" row, shown in
/// customize mode. Disabled steps are dimmed but stay visible so
/// they can be re-enabled.
class _StepEnableRow extends StatelessWidget {
  const _StepEnableRow({
    required this.step,
    required this.routine,
    required this.enabled,
    required this.onChanged,
  });

  final SkincareStep step;
  final SkincareRoutine routine;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SwitchListTile(
        value: enabled,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        secondary: Icon(
          step.icon,
          color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        title: Text(
          step.label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
