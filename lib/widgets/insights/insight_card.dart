import 'package:flutter/material.dart';

/// How confident an [InsightCard]'s finding is, driven by how much
/// history backs it.
///
/// Purely presentational: callers decide the level based on how many
/// days of local data went into the insight, and the card renders a
/// small badge accordingly rather than stating a finding with more
/// confidence than the underlying sample supports.
enum InsightConfidence {
  /// Backed by a healthy amount of history. No badge shown — this is
  /// the default, unhedged presentation.
  established,

  /// Backed by only a handful of data points. Shown with a subtle
  /// "Early trend" badge so the user knows to expect it to shift as
  /// more history accumulates.
  emerging,
}

/// A single personalized insight tile for the Insights page.
///
/// Pairs an icon with a short headline finding and a supporting
/// explanation, optionally with a trend arrow (for insights that
/// compare two periods) and a confidence badge (for insights derived
/// from a small sample). Purely presentational — every value is
/// supplied by the caller, computed from local on-device statistics.
class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.icon,
    required this.title,
    required this.headline,
    required this.detail,
    this.trend,
    this.confidence = InsightConfidence.established,
    this.color,
  });

  /// Icon shown in the leading circular badge.
  final IconData icon;

  /// Small, all-caps-styled label identifying the kind of insight,
  /// e.g. "MOST CONSISTENT DAY".
  final String title;

  /// The finding itself, shown large, e.g. "Sundays" or "Neck Mobility".
  final String headline;

  /// One or two sentences of supporting explanation, e.g. "You've
  /// completed exercises on 8 of your last 10 Sundays."
  final String detail;

  /// Optional trend direction for insights that compare two periods
  /// (e.g. this week vs. last week). Omitted entirely if null.
  final InsightTrend? trend;

  /// How much history backs this finding. See [InsightConfidence].
  final InsightConfidence confidence;

  /// Base color for the icon badge. Defaults to [ColorScheme.primary].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseColor = color ?? colorScheme.primary;
    final trendValue = trend;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      elevation: 2,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
      surfaceTintColor: colorScheme.surfaceTint,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: baseColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (confidence == InsightConfidence.emerging)
                            _EmergingBadge(color: baseColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              headline,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (trendValue != null) ...[
                            const SizedBox(width: 6),
                            _TrendChip(trend: trendValue),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              detail,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A trend comparing two periods, shown as a small colored chip with
/// an up/down/flat arrow and a percentage or unit change.
class InsightTrend {
  const InsightTrend({required this.direction, required this.label});

  /// Builds a "no meaningful change" trend, shown with a flat arrow.
  const InsightTrend.flat(this.label) : direction = InsightTrendDirection.flat;

  /// Whether this trend is an improvement, a decline, or roughly flat.
  final InsightTrendDirection direction;

  /// Short label shown next to the arrow, e.g. "+18%" or "-3 min".
  final String label;
}

/// Direction of an [InsightTrend], used to pick its arrow and color.
enum InsightTrendDirection { up, down, flat }

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.trend});

  final InsightTrend trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (icon, color) = switch (trend.direction) {
      InsightTrendDirection.up => (
          Icons.trending_up,
          const Color(0xFF2E7D32),
        ),
      InsightTrendDirection.down => (
          Icons.trending_down,
          colorScheme.error,
        ),
      InsightTrendDirection.flat => (
          Icons.trending_flat,
          colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 3),
          Text(
            trend.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergingBadge extends StatelessWidget {
  const _EmergingBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'EARLY TREND',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 9,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// A short, muted empty-state message shown in place of an insight
/// that doesn't have enough local history to compute yet.
class InsightEmptyCard extends StatelessWidget {
  const InsightEmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.onSurfaceVariant, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
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
