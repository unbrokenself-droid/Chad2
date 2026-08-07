import 'package:flutter/material.dart';

/// A small pill-shaped badge for surfacing a compact progress figure,
/// e.g. "2/5" completed exercises or "5/7 this week" for a streak.
///
/// Purely presentational. Colors default to a tinted version of the
/// current [ColorScheme.primary], but can be overridden so the chip
/// still reads clearly against a colored background, such as inside a
/// [FeatureCard].
class ProgressChip extends StatelessWidget {
  const ProgressChip({
    super.key,
    required this.label,
    this.icon,
    this.foregroundColor,
    this.backgroundColor,
  });

  /// The text shown in the chip, e.g. "2/5" or "5/7 this week".
  final String label;

  /// Optional leading icon, e.g. [Icons.check_circle].
  final IconData? icon;

  /// Overrides the chip's text/icon color. Defaults to
  /// [ColorScheme.primary].
  final Color? foregroundColor;

  /// Overrides the chip's background color. Defaults to a translucent
  /// tint of the foreground color.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = foregroundColor ?? theme.colorScheme.primary;
    final bg = backgroundColor ?? fg.withValues(alpha: 0.12);
    final chipIcon = icon;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chipIcon != null) ...[
              Icon(chipIcon, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
