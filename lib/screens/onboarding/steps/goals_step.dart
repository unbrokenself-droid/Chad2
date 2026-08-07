import 'package:flutter/material.dart';

import '../../../services/onboarding_service.dart';
import '../../../widgets/onboarding/onboarding_option_card.dart';

/// Second onboarding step: multi-select of primary wellness goals.
/// The user can select any number, including none.
class GoalsStep extends StatelessWidget {
  const GoalsStep({
    super.key,
    required this.selectedGoals,
    required this.onToggle,
  });

  final Set<OnboardingGoal> selectedGoals;
  final ValueChanged<OnboardingGoal> onToggle;

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
            'What are you working on?',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick as many as you like. You can change these later.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 24),
          ...OnboardingGoal.values.map((goal) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OnboardingOptionCard(
                title: goal.label,
                leadingEmoji: goal.emoji,
                selected: selectedGoals.contains(goal),
                onTap: () => onToggle(goal),
              ),
            );
          }),
        ],
      ),
    );
  }
}
