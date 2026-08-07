import 'package:flutter/material.dart';

import 'primary_button.dart';

/// A single fact shown in a [FeatureCard]'s meta row, e.g. "5
/// exercises" or "12 min".
class FeatureCardStat {
  const FeatureCardStat({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// A prominent, gradient-backed hero card for highlighting a single
/// featured action.
///
/// Generalized from the Home tab's "Today's Routine" summary, but
/// generic enough for any card that pairs a headline with an optional
/// meta row, progress bar, and call-to-action button. Purely
/// presentational — every value is supplied by the caller and
/// [onActionPressed] is a plain callback with no logic of its own.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    this.stats = const [],
    this.progress,
    this.caption,
    this.actionLabel,
    this.actionIcon,
    this.onActionPressed,
    this.color,
    this.headerBadge,
    this.backgroundAsset,
  });

  /// Icon shown in a circular badge in the header.
  final IconData icon;

  /// Small, all-caps label above [title], e.g. "TODAY'S ROUTINE".
  final String eyebrow;

  /// The card's headline, e.g. the routine's name.
  final String title;

  /// Small icon+label facts shown in a row under the header, e.g.
  /// exercise count and duration. Omitted entirely if empty.
  final List<FeatureCardStat> stats;

  /// Optional 0.0–1.0 progress value, rendered as a thin animated bar.
  final double? progress;

  /// Optional caption shown under the progress bar, e.g.
  /// "2 of 5 completed".
  final String? caption;

  /// Label for the call-to-action button. If null, no button is shown.
  final String? actionLabel;

  /// Optional icon for the call-to-action button.
  final IconData? actionIcon;

  /// Called when the call-to-action button is tapped.
  final VoidCallback? onActionPressed;

  /// Base color the card's gradient and button are derived from.
  /// Defaults to [ColorScheme.primary].
  final Color? color;

  /// Optional small widget shown at the end of the header row, e.g. a
  /// [ProgressChip] summarizing completion at a glance.
  final Widget? headerBadge;

  /// Optional decorative image bled into the card's bottom-right
  /// corner as a faint, single-color watermark — tinted to
  /// [ColorScheme.onPrimary] at low opacity and clipped to the card's
  /// own rounded shape, never shown at its own original colors (which
  /// would compete with [color]'s gradient rather than sit quietly
  /// behind the actual content). Needs a transparent background of
  /// its own to read as a silhouette rather than a solid tinted
  /// rectangle.
  final String? backgroundAsset;

  /// Slightly darkens [color] to build a subtle same-hue gradient.
  static Color _darken(Color color, [double amount = 0.16]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0).toDouble())
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = color ?? colorScheme.primary;
    final progressValue = progress;
    final captionText = caption;
    final actionLabelText = actionLabel;
    final backgroundAssetPath = backgroundAsset;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor, _darken(baseColor)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: isDark ? 0.28 : 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      // The outer Container's own decoration already clips its
      // gradient fill to borderRadius correctly on its own; this
      // inner ClipRRect is specifically for backgroundAsset below,
      // which is deliberately positioned partly outside the card's
      // own bounds (so it reads as "bleeding off the corner" rather
      // than a neatly-contained sticker) and needs its own clip to
      // keep that overflow from spilling past the rounded shape.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            if (backgroundAssetPath != null)
              Positioned(
                right: -24,
                bottom: -30,
                child: Opacity(
                  opacity: 0.14,
                  child: Image.asset(
                    backgroundAssetPath,
                    width: 170,
                    color: colorScheme.onPrimary,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.onPrimary.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: colorScheme.onPrimary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eyebrow,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimary.withValues(
                                  alpha: 0.75,
                                ),
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (headerBadge != null) ...[
                        const SizedBox(width: 8),
                        headerBadge!,
                      ],
                    ],
                  ),
                  if (stats.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        for (var i = 0; i < stats.length; i++) ...[
                          if (i != 0) const SizedBox(width: 16),
                          Icon(
                            stats[i].icon,
                            size: 16,
                            color: colorScheme.onPrimary.withValues(
                              alpha: 0.85,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            stats[i].label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onPrimary.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (progressValue != null) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: progressValue),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return LinearProgressIndicator(
                            value: value,
                            minHeight: 7,
                            backgroundColor: colorScheme.onPrimary.withValues(
                              alpha: 0.2,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.onPrimary,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (captionText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      captionText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                  if (actionLabelText != null) ...[
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: actionLabelText,
                      icon: actionIcon,
                      onPressed: onActionPressed ?? () {},
                      backgroundColor: colorScheme.onPrimary,
                      foregroundColor: colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
