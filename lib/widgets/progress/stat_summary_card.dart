import 'package:flutter/material.dart';

/// A compact metric tile used in the Progress screen's stats grid.
///
/// Shows an icon (optionally ringed with a [progress] indicator), a
/// large headline [value], a [label], and an optional small [caption]
/// underneath. Purely presentational — every value is supplied by the
/// caller as static/dummy data.
class StatSummaryCard extends StatelessWidget {
  const StatSummaryCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.caption,
    this.progress,
  });

  /// Icon shown in the circular badge, e.g. [Icons.local_fire_department].
  final IconData icon;

  /// The headline figure, e.g. '7', '186', or '82%'.
  final String value;

  /// The metric's name, e.g. 'Day Streak'.
  final String label;

  /// Optional small supporting line under [label], e.g. 'this week'.
  final String? caption;

  /// Optional 0.0–1.0 value rendered as a ring around the icon badge.
  /// Omitted entirely if null.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final captionText = caption;
    final progressValue = progress;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      elevation: 2,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.35),
      surfaceTintColor: colorScheme.surfaceTint,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (progressValue != null)
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: progressValue),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, animatedValue, _) {
                        return SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            value: animatedValue,
                            strokeWidth: 3,
                            backgroundColor: colorScheme.primary.withValues(
                              alpha: 0.14,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.primary,
                            ),
                          ),
                        );
                      },
                    ),
                  Container(
                    width: progressValue != null ? 34 : 40,
                    height: progressValue != null ? 34 : 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: colorScheme.primary,
                      size: progressValue != null ? 17 : 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (captionText != null) ...[
              const SizedBox(height: 2),
              Text(
                captionText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
