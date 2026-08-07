import 'package:flutter/material.dart';

import '../../services/badge_service.dart';

/// A single achievement badge, shown either locked (dimmed icon, a
/// progress bar toward its goal) or unlocked (full-color icon in a
/// filled circle, an "Unlocked" chip instead of a progress bar).
///
/// Purely presentational — takes an already-computed [BadgeProgress]
/// rather than reading [BadgeScope] directly, so it can be reused in
/// a grid, a carousel, or a celebration overlay without depending on
/// where the data comes from. The unlock transition itself (locked →
/// unlocked) is animated by [AnimatedSwitcher]/[AnimatedContainer], so
/// a badge crossing its goal while this tile is on screen visibly
/// "lights up" rather than just repainting.
class BadgeTile extends StatelessWidget {
  const BadgeTile({super.key, required this.progress, this.onTap});

  final BadgeProgress progress;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final definition = progress.definition;
    final unlocked = progress.unlocked;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: unlocked
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: unlocked
                ? colorScheme.primary.withValues(alpha: 0.35)
                : colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedScale(
              scale: unlocked ? 1.0 : 0.92,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
                ),
                child: Icon(
                  definition.icon,
                  color: unlocked
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              definition.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: unlocked
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              definition.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: unlocked
                  ? _UnlockedChip(key: const ValueKey('unlocked'))
                  : _ProgressBar(
                      key: const ValueKey('progress'),
                      progress: progress,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlockedChip extends StatelessWidget {
  const _UnlockedChip({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 15, color: colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          'Unlocked',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({super.key, required this.progress});

  final BadgeProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final definition = progress.definition;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: progress.progress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.12,
                ),
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${progress.current} of ${definition.goal} ${definition.unit}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
