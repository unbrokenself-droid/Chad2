import 'package:flutter/material.dart';

import '../../../services/onboarding_service.dart';
import '../../../widgets/onboarding/onboarding_option_card.dart';

/// Third onboarding step: single-select experience level, used to
/// scale future routine suggestions.
class ExperienceStep extends StatelessWidget {
  const ExperienceStep({
    super.key,
    required this.selectedLevel,
    required this.onSelect,
  });

  final ExperienceLevel? selectedLevel;
  final ValueChanged<ExperienceLevel> onSelect;

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
            "What's your experience level?",
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "We'll tailor routine suggestions to match.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 24),
          ...ExperienceLevel.values.map((level) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OnboardingOptionCard(
                title: level.label,
                subtitle: level.description,
                selected: selectedLevel == level,
                onTap: () => onSelect(level),
              ),
            );
          }),
        ],
      ),
    );
  }
}
