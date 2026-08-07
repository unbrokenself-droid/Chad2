import 'package:flutter/material.dart';

import '../../services/badge_service.dart';

/// Compact Home-dashboard card summarizing achievement progress: how
/// many badges are unlocked out of the total, plus a row of small
/// badge icons (filled for unlocked, dimmed for locked) as a preview.
///
/// Tapping anywhere opens the full [BadgesScreen] via [onTap].
/// Purely presentational — takes an already-computed list of
/// [BadgeProgress] rather than reading [BadgeScope] directly.
class BadgesSummaryCard extends StatelessWidget {
  const BadgesSummaryCard({
    super.key,
    required this.progress,
    required this.onTap,
  });

  final List<BadgeProgress> progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final unlockedCount = progress.where((p) => p.unlocked).length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.military_tech,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Achievements',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$unlockedCount of ${progress.length} badges unlocked',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final entry in progress)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: entry.unlocked
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant.withValues(
                                      alpha: 0.12,
                                    ),
                            ),
                            child: Icon(
                              entry.definition.icon,
                              size: 15,
                              color: entry.unlocked
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurfaceVariant.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
