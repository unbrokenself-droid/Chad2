import 'package:flutter/material.dart';

/// A card containing a small labelled bar chart, e.g. minutes
/// exercised per day over the last week.
///
/// Built from plain [Column]/[Container] widgets rather than a
/// charting package, so it stays lightweight and themable from the
/// app's own [ColorScheme]. Purely presentational — [values] and
/// [labels] are supplied by the caller as static/dummy data.
class BarChartCard extends StatelessWidget {
  const BarChartCard({
    super.key,
    required this.title,
    required this.values,
    required this.labels,
    this.subtitle,
    this.valueSuffix = '',
  }) : assert(
         values.length == labels.length,
         'values and labels must be the same length',
       );

  /// The chart's heading, e.g. 'Minutes Exercised'.
  final String title;

  /// Optional small line under [title], e.g. 'Last 7 days'.
  final String? subtitle;

  /// One bar height per entry.
  final List<double> values;

  /// One label per bar, shown underneath, e.g. day initials.
  final List<String> labels;

  /// Appended to the value shown above the tallest bar, e.g. ' min'.
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtitleText = subtitle;
    final maxValue = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      elevation: 2,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.35),
      surfaceTintColor: colorScheme.surfaceTint,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitleText != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitleText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(values.length, (i) {
                  final fraction = (values[i] / safeMax).clamp(0.0, 1.0);
                  final isPeak = values[i] == maxValue;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i == values.length - 1 ? 0 : 8,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isPeak)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${values[i].round()}$valueSuffix',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          Expanded(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: fraction),
                              duration: Duration(
                                milliseconds: 500 + i * 80,
                              ),
                              curve: Curves.easeOutCubic,
                              builder: (context, animatedValue, _) {
                                return FractionallySizedBox(
                                  heightFactor: animatedValue.clamp(
                                    0.03,
                                    1.0,
                                  ),
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isPeak
                                          ? colorScheme.primary
                                          : colorScheme.primary.withValues(
                                              alpha: 0.45,
                                            ),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            labels[i],
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
