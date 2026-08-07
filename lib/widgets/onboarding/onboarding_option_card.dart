import 'package:flutter/material.dart';

import '../../services/accessibility_scope.dart';
import '../shared/min_tap_target.dart' show kLargeTouchTargetSize;

/// A tappable card representing one selectable option in an
/// onboarding step (a goal, an experience level, a reminder to
/// enable). Shows a leading emoji/icon, a title, an optional
/// subtitle, and a trailing check when selected.
class OnboardingOptionCard extends StatelessWidget {
  const OnboardingOptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leadingEmoji,
    this.leadingIcon,
  });

  final String title;
  final String? subtitle;
  final String? leadingEmoji;
  final IconData? leadingIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // AccessibilityScope is available even here, before onboarding
    // finishes — main.dart wraps the whole app, including the
    // onboarding flow itself, not just the screens behind it. A user
    // who already has this on (e.g. redoing onboarding) benefits from
    // it just as much here as anywhere else.
    final largeTargets = AccessibilityScope.of(context).largeTouchTargets;
    final verticalPadding = largeTargets ? 18.0 : 14.0;

    return Semantics(
      button: true,
      selected: selected,
      label: subtitle != null ? '$title. $subtitle' : title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: kLargeTouchTargetSize),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? colorScheme.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  if (leadingEmoji != null)
                    Text(leadingEmoji!, style: const TextStyle(fontSize: 24))
                  else if (leadingIcon != null)
                    Icon(
                      leadingIcon,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  if (leadingEmoji != null || leadingIcon != null)
                    const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: selected ? 1 : 0,
                    child: Icon(
                      Icons.check_circle,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
