import 'package:flutter/material.dart';

import '../../services/hydration_scope.dart';
import '../../services/hydration_service.dart';
import '../../utils/app_haptics.dart';
import '../shared/primary_button.dart';
import 'hydration_ring.dart';

/// Opens the hydration tracking bottom sheet.
///
/// Convenience wrapper around [showModalBottomSheet] so callers (the
/// Home screen's "Stay Hydrated" reminder card) don't need to know
/// the sheet's shape/styling details.
Future<void> showHydrationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const HydrationSheet(),
  );
}

/// Bottom sheet for logging and reviewing today's water intake.
///
/// Reads and writes through [HydrationScope], so the ring here and
/// the Home screen's reminder card stay in sync automatically. Offers
/// one-tap quick-add buttons for common amounts, plus a way to edit
/// the daily goal inline.
class HydrationSheet extends StatefulWidget {
  const HydrationSheet({super.key});

  @override
  State<HydrationSheet> createState() => _HydrationSheetState();
}

class _HydrationSheetState extends State<HydrationSheet> {
  bool _editingGoal = false;
  late final TextEditingController _goalController;

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController();
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  void _startEditingGoal(HydrationService hydration) {
    final current = hydration.goalInCurrentUnit();
    // Whole numbers show without a trailing ".0" — nobody wants to
    // edit a field that starts as "2000.0" for a goal they set as a
    // clean 2000.
    _goalController.text = current == current.roundToDouble()
        ? current.round().toString()
        : current.toStringAsFixed(1);
    setState(() => _editingGoal = true);
  }

  Future<void> _saveGoal(HydrationService hydration) async {
    final parsedValue = double.tryParse(_goalController.text);
    if (parsedValue != null) {
      await hydration.setGoalFromUnitInput(parsedValue);
    }
    if (!mounted) return;
    setState(() => _editingGoal = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hydration = HydrationScope.of(context);
    final todayMl = hydration.todayIntakeMl;
    final goalMl = hydration.goalMl;
    final quickAddAmounts = hydration.quickAddAmountsMl;

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
                'Hydration',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              HydrationRing(
                progress: hydration.todayProgress,
                amountLabel: hydration.formatMl(todayMl),
                goalLabel: 'of ${hydration.formatMl(goalMl)}',
              ),
              const SizedBox(height: 8),
              if (hydration.goalReachedToday)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "🎉 Goal reached for today!",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Quick add',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final amount in quickAddAmounts) ...[
                    if (amount != quickAddAmounts.first)
                      const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAddButton(
                        label: '+${hydration.formatMl(amount)}',
                        onTap: () => hydration.addIntake(amount),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              if (_editingGoal)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _goalController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: hydration.unit == HydrationUnit.metric
                              ? 'Daily goal (ml)'
                              : 'Daily goal (fl oz)',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => _saveGoal(hydration),
                      icon: const Icon(Icons.check),
                      color: colorScheme.primary,
                      tooltip: 'Save goal',
                    ),
                    IconButton(
                      onPressed: () => setState(() => _editingGoal = false),
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel',
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _startEditingGoal(hydration),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit daily goal'),
                      ),
                    ),
                    if (todayMl > 0)
                      TextButton(
                        onPressed: () => hydration.resetIntake(),
                        child: const Text('Reset today'),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
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

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          AppHaptics.light();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(Icons.add_circle_outline, color: colorScheme.primary),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
