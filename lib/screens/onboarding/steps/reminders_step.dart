import 'package:flutter/material.dart';

import '../../../widgets/onboarding/onboarding_option_card.dart';

/// One reminder toggle option shown during onboarding. Kept as a
/// simple label/description pair here (rather than importing
/// `ReminderKind` directly) so this step has no dependency on the
/// notifications service — the onboarding flow calls
/// `ReminderSettingsService.enable` for each chosen kind afterward.
class ReminderOption {
  const ReminderOption({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  /// Matches `ReminderKind.name` so the choice can be mapped back to
  /// a real `ReminderKind` when applying it.
  final String key;
  final String title;
  final String description;
  final IconData icon;
}

const List<ReminderOption> kReminderOptions = [
  ReminderOption(
    key: 'dailyRoutine',
    title: 'Daily routine',
    description: 'A nudge to do your facial exercises',
    icon: Icons.self_improvement,
  ),
  ReminderOption(
    key: 'hydration',
    title: 'Hydration',
    description: 'Reminders to drink water',
    icon: Icons.water_drop_outlined,
  ),
  ReminderOption(
    key: 'skincare',
    title: 'Skincare',
    description: 'A nightly skincare reminder',
    icon: Icons.spa_outlined,
  ),
  ReminderOption(
    key: 'posture',
    title: 'Posture check',
    description: 'Periodic posture and jaw-relaxation nudges',
    icon: Icons.accessibility_new,
  ),
];

/// Fourth onboarding step: choose which reminders to turn on. Fully
/// optional — the user can continue with none selected and enable
/// reminders later from Settings.
class RemindersStep extends StatelessWidget {
  const RemindersStep({
    super.key,
    required this.selectedKeys,
    required this.onToggle,
  });

  final Set<String> selectedKeys;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Stay on track',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "Choose reminders to turn on. You can fine-tune times later "
            "in Settings.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 24),
          ...kReminderOptions.map((option) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OnboardingOptionCard(
                title: option.title,
                subtitle: option.description,
                leadingIcon: option.icon,
                selected: selectedKeys.contains(option.key),
                onTap: () => onToggle(option.key),
              ),
            );
          }),
        ],
      ),
    );
  }
}
