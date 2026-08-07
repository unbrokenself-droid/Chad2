import 'package:flutter/material.dart';

/// A card containing a small labelled line chart, e.g. a consistency
/// percentage trending over the last few weeks.
///
/// Drawn with a single [CustomPaint] rather than a charting package,
/// so it stays lightweight and themable from the app's own
/// [ColorScheme]. Purely presentational — [values] and [labels] are
/// supplied by the caller as static/dummy data.
class LineChartCard extends StatelessWidget {
  const LineChartCard({
    super.key,
    required this.title,
    required this.values,
    required this.labels,
    this.subtitle,
    this.maxValue = 100,
  });

  /// The chart's heading, e.g. 'Hydration Consistency'.
  final String title;

  /// Optional small line under [title], e.g. 'Last 4 weeks'.
  final String? subtitle;

  /// One point per entry, on a 0..[maxValue] scale.
  final List<double> values;

  /// One label per point, shown underneath, e.g. week numbers.
  final List<String> labels;

  /// The scale's upper bound, e.g. 100 for a percentage.
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    assert(
      values.length == labels.length,
      'values and labels must be the same length',
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtitleText = subtitle;

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
            const SizedBox(height: 16),
            SizedBox(
              height: 110,
              width: double.infinity,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, animatedValue, _) {
                  return CustomPaint(
                    painter: _LineChartPainter(
                      values: values,
                      maxValue: maxValue,
                      lineColor: colorScheme.primary,
                      fillColor: colorScheme.primary,
                      gridColor: theme.dividerColor,
                      progress: animatedValue,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final label in labels)
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.maxValue,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.progress,
  });

  final List<double> values;
  final double maxValue;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  /// 0.0–1.0 draw-in animation progress.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    // Horizontal gridlines.
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.length < 2) return;

    final stepX = size.width / (values.length - 1);
    Offset pointFor(int i) {
      final normalized = (values[i] / (maxValue == 0 ? 1 : maxValue)).clamp(
        0.0,
        1.0,
      );
      return Offset(stepX * i, size.height * (1 - normalized));
    }

    final points = List.generate(values.length, pointFor);

    // Reveal the line left-to-right as [progress] animates in.
    final revealX = size.width * progress;
    final visiblePoints = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      if (points[i].dx <= revealX) {
        visiblePoints.add(points[i]);
      } else {
        if (visiblePoints.isNotEmpty) {
          final prev = points[i - 1];
          final next = points[i];
          final t = ((revealX - prev.dx) / (next.dx - prev.dx)).clamp(
            0.0,
            1.0,
          );
          visiblePoints.add(Offset.lerp(prev, next, t)!);
        }
        break;
      }
    }
    if (visiblePoints.length < 2) return;

    final linePath = Path()..moveTo(visiblePoints.first.dx, visiblePoints.first.dy);
    for (final point in visiblePoints.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(visiblePoints.last.dx, size.height)
      ..lineTo(visiblePoints.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            fillColor.withValues(alpha: 0.28),
            fillColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final dotPaint = Paint()..color = lineColor;
    final dotHaloPaint = Paint()..color = lineColor.withValues(alpha: 0.18);
    for (final point in visiblePoints) {
      canvas.drawCircle(point, 6, dotHaloPaint);
      canvas.drawCircle(point, 3.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.progress != progress;
  }
}
