import 'package:flutter/material.dart';

/// A circular progress ring showing today's water intake against the
/// daily goal, with the current amount in milliliters centered inside
/// it.
///
/// Purely presentational — [progress] (0.0 to 1.0), [amountLabel],
/// and [goalLabel] are all supplied by the caller. Animates smoothly
/// whenever [progress] changes, so logging a glass of water fills the
/// ring rather than jumping straight to the new value.
class HydrationRing extends StatelessWidget {
  const HydrationRing({
    super.key,
    required this.progress,
    required this.amountLabel,
    required this.goalLabel,
    this.size = 140,
    this.strokeWidth = 12,
  });

  /// Today's progress toward the daily goal, clamped 0.0–1.0.
  final double progress;

  /// Text shown large in the center, e.g. `'1250 ml'`.
  final String amountLabel;

  /// Smaller supporting text shown below [amountLabel], e.g.
  /// `'of 2000 ml'`.
  final String goalLabel;

  /// Overall diameter of the ring.
  final double size;

  /// Thickness of the ring stroke.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, animatedProgress, child) {
          return CustomPaint(
            painter: _RingPainter(
              progress: animatedProgress,
              trackColor: colorScheme.primary.withValues(alpha: 0.12),
              progressColor: colorScheme.primary,
              strokeWidth: strokeWidth,
            ),
            child: child,
          );
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.water_drop, color: colorScheme.primary, size: 20),
              const SizedBox(height: 4),
              Text(
                amountLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                goalLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Start at the top (-90°) and sweep clockwise proportional to
    // progress, matching the visual convention of the week/streak
    // dots elsewhere in the app.
    const startAngle = -3.14159265 / 2;
    final sweepAngle = 2 * 3.14159265 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
