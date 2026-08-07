import 'package:flutter/material.dart';

/// Row of dots showing which step of the onboarding flow the user is
/// on, with the active/completed dots drawn wider and in the accent
/// color.
class OnboardingProgressDots extends StatelessWidget {
  const OnboardingProgressDots({
    super.key,
    required this.stepCount,
    required this.currentStep,
  });

  /// Total number of steps in the flow.
  final int stepCount;

  /// Zero-based index of the step currently shown.
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(stepCount, (index) {
        final isActive = index <= currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: index == currentStep ? 24 : 6,
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
