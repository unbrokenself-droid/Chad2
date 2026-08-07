import 'package:flutter/material.dart';

import '../../utils/daily_rotation.dart';
import '../coach/coach_avatar.dart';

/// Short, rotating lines shown under the hero greeting — see
/// [pickForToday]. Kept short enough to read at a glance rather than
/// compete with the greeting above it for attention.
const List<String> _dailyQuotes = [
  'Small, consistent effort beats occasional intensity.',
  'Your face and posture carry the day\'s tension — meet it here.',
  'A few minutes of care now is easier than undoing tension later.',
  'Progress is a posture, not a single session.',
  'Relaxed today becomes resilient tomorrow.',
  'Showing up gently, every day, is the whole practice.',
  'Ease into it — nothing here needs to be forced.',
];

/// Premium hero header for the top of the Home screen: a two-line
/// greeting ("Good Evening," / "Abhay 👋"), the current workout streak
/// and today's date on one line, a short rotating motivational quote,
/// and [CoachAvatar] anchoring the top-right corner.
///
/// Purely presentational: [greeting] and [displayName] are the exact
/// same values [HomeScreen] already computes via
/// [PersonalizationService.greeting] and the onboarding profile's
/// name — this widget only changes how they're laid out and styled,
/// not what they say or where they come from. [currentStreak] is
/// likewise passed in rather than read from a scope directly, so this
/// stays a plain function of its inputs.
class HomeHeroHeader extends StatelessWidget {
  const HomeHeroHeader({
    super.key,
    required this.greeting,
    required this.displayName,
    required this.currentStreak,
  });

  final String greeting;
  final String displayName;
  final int currentStreak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final quote = pickForToday(_dailyQuotes);
    final dateLabel = _formatDate(DateTime.now());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$displayName 👋',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  if (currentStreak > 0)
                    _HeroChip(
                      icon: Icons.local_fire_department_rounded,
                      label: '$currentStreak-day streak',
                      color: const Color(0xFFF57C00),
                    ),
                  _HeroChip(
                    icon: Icons.calendar_today_rounded,
                    label: dateLabel,
                    color: colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                quote,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        const CoachAvatar(size: 64),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
