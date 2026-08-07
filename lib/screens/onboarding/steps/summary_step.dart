import 'package:flutter/material.dart';

import '../../../services/onboarding_service.dart';
import '../../../services/personalization_service.dart';
import 'reminders_step.dart';

/// Final onboarding step: a quick summary of everything chosen, shown
/// just before the "Get started" button commits it.
class SummaryStep extends StatelessWidget {
  const SummaryStep({super.key, required this.profile});

  final OnboardingProfile profile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final name = profile.name?.trim();
    final greetingName = (name != null && name.isNotEmpty) ? name : null;

    const personalization = PersonalizationService();
    final previewGreeting = personalization.greeting(
      hour: DateTime.now().hour,
      name: profile.name,
      goals: profile.goals,
    );

    final reminderTitles = kReminderOptions
        .where((option) => profile.remindersOptedIn.contains(option.key))
        .map((option) => option.title)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 20),
          Text(
            greetingName != null
                ? "You're all set, $greetingName"
                : "You're all set",
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Here's what we've got.",
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          _SummaryRow(
            icon: Icons.flag_outlined,
            label: 'Goals',
            value: profile.goals.isEmpty
                ? 'None selected'
                : profile.goals.map((g) => g.label).join(', '),
          ),
          _SummaryRow(
            icon: Icons.trending_up,
            label: 'Experience',
            value: profile.experienceLevel?.label ?? 'Not set',
          ),
          _SummaryRow(
            icon: Icons.notifications_outlined,
            label: 'Reminders',
            value: reminderTitles.isEmpty
                ? 'None enabled'
                : reminderTitles.join(', '),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "On your home screen you'll see",
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  previewGreeting,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
