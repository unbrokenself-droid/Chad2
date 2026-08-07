import 'package:flutter/material.dart';

/// A soft, glowing orb that smoothly scales between [startScale] and
/// [endScale] as [controller] runs, used as the central visual for a
/// running [BreathingSessionScreen].
///
/// Designed to feel calm rather than mechanical: a soft-edged radial
/// gradient plus a couple of translucent outer rings that scale
/// slightly slower than the core (a gentle parallax), rather than a
/// single hard-edged circle. [child] — typically the current phase's
/// label — is centered on top and cross-fades in via its own
/// [AnimatedSwitcher] in the caller, so this widget only owns the
/// scale animation itself.
///
/// When [paused] is true, or when the platform's reduce-motion
/// setting is on, the orb holds at its current scale rather than
/// continuing to move — [BreathingSessionScreen] separately stops
/// [controller] in both cases, so this only needs to render whatever
/// value it's currently holding.
class BreathingOrb extends StatelessWidget {
  const BreathingOrb({
    super.key,
    required this.controller,
    required this.startScale,
    required this.endScale,
    required this.paused,
    required this.color,
    required this.child,
  });

  /// Drives the 0.0–1.0 progress from [startScale] to [endScale].
  final AnimationController controller;

  /// The orb's scale (relative to [_baseDiameter]) at the start of
  /// the current phase.
  final double startScale;

  /// The orb's scale at the end of the current phase.
  final double endScale;

  /// Whether the session is currently paused.
  final bool paused;

  /// The accent color the orb's gradient and rings are derived from.
  final Color color;

  /// Centered content, typically the phase label.
  final Widget child;

  static const double _baseDiameter = 220;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = reduceMotion
            ? endScale
            : Curves.easeInOutSine.transform(controller.value);
        final scale = reduceMotion
            ? endScale
            : startScale + (endScale - startScale) * t;
        final diameter = _baseDiameter * scale;

        return SizedBox(
          width: _baseDiameter * 1.6,
          height: _baseDiameter * 1.6,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outermost, faintest ring — moves at a slightly damped
              // scale so it feels like it's gently trailing the core.
              _ring(diameter: _baseDiameter * (0.55 + 0.35 * scale), alpha: 0.08),
              _ring(diameter: _baseDiameter * (0.7 + 0.28 * scale), alpha: 0.14),
              // The core orb itself, with a soft radial gradient
              // rather than a flat fill so it reads as glowing light
              // rather than a flat disc.
              Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color.lerp(color, Colors.white, 0.18)!,
                      color,
                      Color.lerp(color, Colors.black, 0.12)!,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ring({required double diameter, required double alpha}) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: alpha),
      ),
    );
  }
}
