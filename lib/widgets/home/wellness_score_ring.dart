import 'package:flutter/material.dart';

/// A circular progress ring showing today's overall Wellness Score
/// (0–100) in the center, colored on a red → orange → blue → green
/// scale so the ring reads as good/needs-work at a glance without
/// reading the number.
///
/// Purely presentational — [score] (0–100) is supplied by the
/// caller. Animates smoothly whenever [score] changes, so completing
/// a habit fills the ring rather than jumping straight to the new
/// value, matching [HydrationRing]'s behavior. The filled arc is a
/// gradient sweep from a dimmer tint of [colorFor]'s color into the
/// full color, rather than one flat stroke, and sits over a soft
/// color-matched glow rather than a plain track — meant to read as
/// something worth looking at, not just a data readout.
class WellnessScoreRing extends StatelessWidget {
  const WellnessScoreRing({
    super.key,
    required this.score,
    this.size = 176,
    this.strokeWidth = 16,
  });

  /// Today's overall wellness score, 0–100.
  final int score;

  /// Overall diameter of the ring.
  final double size;

  /// Thickness of the ring stroke.
  final double strokeWidth;

  /// The ring's color for a given [score]: red 0-30, orange 31-60,
  /// blue 61-85, green 86-100 — used both here and by
  /// [WellnessScoreCard]'s component breakdown bars, so every color
  /// on the card comes from this one place.
  static Color colorFor(int score) {
    if (score >= 86) return const Color(0xFF2E7D32);
    if (score >= 61) return const Color(0xFF2962FF);
    if (score >= 31) return const Color(0xFFF57C00);
    return const Color(0xFFD32F2F);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = (score / 100).clamp(0.0, 1.0);
    final ringColor = colorFor(score);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: progress),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, animatedProgress, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // A soft, color-matched glow behind the ring — part of
              // this card's glassmorphism treatment, not a separate
              // effect layered on top of it.
              Container(
                width: size * 0.86,
                height: size * 0.86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ringColor.withValues(alpha: 0.35),
                      blurRadius: size * 0.22,
                      spreadRadius: size * 0.01,
                    ),
                  ],
                ),
              ),
              CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(
                  progress: animatedProgress,
                  trackColor: colorScheme.onSurface.withValues(alpha: 0.08),
                  progressColor: ringColor,
                  strokeWidth: strokeWidth,
                ),
              ),
              child!,
            ],
          );
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ringColor,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'of 100',
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

  static const double _startAngle = -3.14159265 / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final sweepAngle = 2 * 3.14159265 * progress;

    // A gradient along just the filled portion of the arc — dimmer
    // at the start, full color by the end — rather than one flat
    // stroke color. startAngle/endAngle are set to exactly the arc
    // being drawn (not the full circle) so the gradient's two stops
    // land exactly at the arc's own start and end, however far
    // around that currently is mid-animation.
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + sweepAngle,
        colors: [progressColor.withValues(alpha: 0.45), progressColor],
      ).createShader(rect);

    canvas.drawArc(rect, _startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
