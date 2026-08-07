import 'package:flutter/material.dart';

import 'wellness_score_ring.dart';

/// Compact "Progress" preview section: four stat cards summarizing
/// [currentStreak], [longestStreak], [totalSessions], and a
/// [wellnessScore]-derived level label.
///
/// Every number here is real, already-tracked data passed in by
/// [HomeScreen] — [currentStreak]/[longestStreak] from
/// [StreakScope.allStreaks], [totalSessions] from
/// [ExerciseCompletionService.totalCompletedCount], and
/// [wellnessScore] from [WellnessScoreScope.todaySnapshot]. There's no
/// "sessions/minutes this week" figure here: no service in this app
/// currently tracks a rolling weekly total or a running total of
/// minutes spent, and this redesign didn't add one — showing a made-up
/// number instead of a real one would be worse than a shorter list.
/// [_levelFor] is the one new "derivation" this widget does, and it's
/// a pure presentation mapping (a number to a label and color band),
/// not new business logic — the same kind of banding
/// [WellnessScoreRing.colorFor] already does for the ring itself.
class ProgressPreviewSection extends StatelessWidget {
  const ProgressPreviewSection({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalSessions,
    required this.wellnessScore,
  });

  final int currentStreak;
  final int longestStreak;
  final int totalSessions;
  final int wellnessScore;

  static String _levelFor(int score) {
    if (score >= 86) return 'Excellent';
    if (score >= 61) return 'Strong';
    if (score >= 31) return 'Building';
    return 'Getting Started';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final levelColor = WellnessScoreRing.colorFor(wellnessScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.query_stats_rounded, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'YOUR PROGRESS',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: [
            _StatCard(
              icon: Icons.local_fire_department_rounded,
              value: '$currentStreak',
              label: 'Current Streak',
              color: const Color(0xFFF57C00),
            ),
            _StatCard(
              icon: Icons.emoji_events_rounded,
              value: '$longestStreak',
              label: 'Longest Streak',
              color: const Color(0xFF2962FF),
            ),
            _StatCard(
              icon: Icons.check_circle_rounded,
              value: '$totalSessions',
              label: 'Total Sessions',
              color: const Color(0xFF2E7D32),
            ),
            _StatCard(
              icon: Icons.auto_awesome_rounded,
              value: _levelFor(wellnessScore),
              label: 'Wellness Level',
              color: levelColor,
              compactValue: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.compactValue = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  /// Whether [value] is a word (e.g. "Building") rather than a
  /// number — uses a smaller text style so longer labels don't
  /// crowd the card the way a short number wouldn't.
  final bool compactValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (compactValue
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleLarge)
                    ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
