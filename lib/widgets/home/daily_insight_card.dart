import 'package:flutter/material.dart';

import '../../utils/daily_rotation.dart';

/// Rotating insights — see [pickForToday]. Each is a short, concrete
/// piece of framing rather than a generic platitude, in keeping with
/// this card's "worth actually reading" purpose.
const List<String> _dailyInsights = [
  'Consistency beats intensity. Completing today\'s session is more '
      'valuable than skipping it for a longer workout tomorrow.',
  'Tension held in the jaw often shows up first as a tight neck or '
      'rounded shoulders — they\'re more connected than they feel.',
  'A short session done today compounds faster than a long session '
      'planned for "someday."',
  'Posture isn\'t about holding a position — it\'s about noticing '
      'when you\'ve drifted out of one, sooner each time.',
  'Slow breathing isn\'t just calming — it\'s a direct signal to the '
      'muscles in your face and neck to release.',
  'The habit matters more than any single session. Showing up '
      'today is what makes tomorrow easier.',
];

/// Premium "Today's Insight" card — a single rotating piece of
/// wellness framing, styled distinctly from the reminder/action cards
/// around it so it reads as something to pause and read rather than
/// tap through.
class DailyInsightCard extends StatelessWidget {
  const DailyInsightCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final insight = pickForToday(_dailyInsights);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.14),
            colorScheme.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_rounded, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                "TODAY'S INSIGHT",
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}
