import 'dart:math';

import 'package:flutter/material.dart';

/// Wraps [child] with Home's ambient backdrop: the existing
/// surface-to-primary vertical gradient, plus two soft, low-opacity
/// radial glows and a handful of barely-visible floating particles —
/// restrained on purpose, so the effect reads as depth behind the
/// content rather than a pattern competing with it. Every element
/// here sits at 3-6% opacity or less, and the particles only pulse
/// gently rather than drift — a deliberate choice to keep a scrolling
/// dashboard calm rather than busy.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  /// Fixed positions/sizes for the particle layer, generated once
  /// rather than every build — only their opacity animates, so there's
  /// no need to recompute layout each frame.
  late final List<_Particle> _particles = _generateParticles();

  static List<_Particle> _generateParticles() {
    final random = Random(7); // fixed seed: same quiet layout every launch
    return List.generate(10, (i) {
      return _Particle(
        left: random.nextDouble(),
        top: random.nextDouble(),
        size: 2 + random.nextDouble() * 3,
        phase: random.nextDouble(),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Starting/stopping the repeat here (not the field initializer
    // above, where MediaQuery isn't safely readable yet) is what
    // makes disableAnimations genuinely stop this controller's ticker
    // rather than just hide its visual effect while it keeps running
    // in the background — the same distinction that made this ticker
    // the reason widget_test.dart's pumpAndSettle previously timed
    // out: a `..repeat()` that never actually stops means "no more
    // frames scheduled" is never true, no matter what's on screen.
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.4],
          colors: [
            Color.lerp(colorScheme.surface, colorScheme.primary, 0.05)!,
            colorScheme.surface,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _Glow(color: colorScheme.primary, size: 260),
          ),
          Positioned(
            bottom: 40,
            left: -80,
            child: _Glow(color: colorScheme.tertiary, size: 220),
          ),
          if (!reduceMotion)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _ParticlePainter(
                        particles: _particles,
                        t: _controller.value,
                        color: colorScheme.onSurface,
                      ),
                    );
                  },
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.06), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.left,
    required this.top,
    required this.size,
    required this.phase,
  });

  /// Fractional position (0-1) within the painted area.
  final double left;
  final double top;
  final double size;

  /// Offsets this particle's opacity pulse from the others, so they
  /// don't all brighten/dim in lockstep.
  final double phase;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.particles, required this.t, required this.color});

  final List<_Particle> particles;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final pulse = (sin((t + particle.phase) * 2 * pi) + 1) / 2;
      final opacity = 0.03 + pulse * 0.05;
      final paint = Paint()..color = color.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(particle.left * size.width, particle.top * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.color != color;
  }
}
