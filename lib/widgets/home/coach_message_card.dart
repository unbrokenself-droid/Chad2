import 'package:flutter/material.dart';

import '../../utils/daily_rotation.dart';
import '../coach/coach_avatar.dart';

/// Rotating coach messages — see [pickForToday]. Each names a
/// specific focus rather than generic encouragement, so this reads
/// like a coach who actually looked at the day's plan.
const List<String> _coachMessages = [
  "Today's focus is posture and relaxation.",
  "Let's reduce facial tension today.",
  'A steady pace beats rushing through it.',
  "Neck and jaw carry a lot — let's ease them today.",
  "Breathing well changes everything else. Let's start there.",
  "Small wins today add up to real change.",
  "You've got a good routine lined up — let's begin.",
];

/// Compact card pairing [CoachAvatar] with a short, daily-rotating
/// message — a lighter-weight, more frequent touchpoint than
/// [CoachGenerationScreen]/the session-complete screens, meant to
/// read as a quick check-in rather than another dashboard tile.
class CoachMessageCard extends StatelessWidget {
  const CoachMessageCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final message = pickForToday(_coachMessages);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const CoachAvatar(size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COACH',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.3,
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
