import 'package:flutter/material.dart';

import '../../services/reminder_settings_service.dart';
import '../../utils/app_haptics.dart';

/// The card shown on Home when [ReminderSettingsService.hasPendingPostureCheck]
/// is true — a posture interval elapsed while the app was open, and
/// nothing has confirmed the user actually checked yet.
///
/// Two genuinely different actions, not one: "I checked" credits an
/// acknowledgment (feeding the Wellness Score and the Posture
/// Champion badge); "Not now" dismisses without crediting anything.
/// Both matter. A card with only the first option would leave someone
/// who hasn't actually checked their posture right now — mid-drive,
/// in a meeting, whatever — with no honest way to make the prompt go
/// away, which would just trade a silently-firing timer's false
/// credit for a socially-pressured one instead of fixing anything.
///
/// Deliberately a separate widget rather than a new mode bolted onto
/// the shared `ReminderCard` used elsewhere on this screen: that
/// widget wraps its whole row in one tap target, with no independent
/// zone for a second action, and reworking a component several other
/// cards depend on just for this one case isn't a good trade for what
/// staying self-contained costs here.
class PostureCheckPrompt extends StatelessWidget {
  const PostureCheckPrompt({super.key, required this.reminders});

  final ReminderSettingsService reminders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.accessibility_new,
                color: colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Posture check',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sit up straight and relax your jaw, then let us know.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.85,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            AppHaptics.medium();
                            reminders.acknowledgePostureCheck();
                          },
                          child: const Text('I checked'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.85),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () {
                          AppHaptics.selection();
                          reminders.dismissPostureCheckPrompt();
                        },
                        child: const Text('Not now'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
