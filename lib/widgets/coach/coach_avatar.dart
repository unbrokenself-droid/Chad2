import 'package:flutter/material.dart';

/// A soft, glowing circular avatar standing in for "the coach"
/// wherever this app speaks in that voice — [CoachGenerationScreen],
/// the routine session-complete dashboard, and anywhere else a warm,
/// personal presence is called for.
///
/// Defaults to an abstract gradient orb rather than a photo of a
/// person: a specific human's face as a permanent, recurring app
/// mascot is a real likeness/rights question, not just an asset-swap
/// decision. [imageAsset] is the escape hatch for call sites that do
/// have a specific, cleared image for their exact moment — see
/// [CoachGenerationScreen]'s two call sites and the routine
/// session-complete screens, which each pass their own — while
/// everywhere else still gets the same safe default. Either way,
/// every call site just asks for "the coach avatar," not for any
/// particular image — this remains the one place that would need to
/// change to swap what "no [imageAsset] given" falls back to.
class CoachAvatar extends StatelessWidget {
  const CoachAvatar({
    super.key,
    this.size = 96,
    this.pulse = false,
    this.imageAsset,
  });

  final double size;

  /// Whether this instance should gently scale in and out on a loop —
  /// used on [CoachGenerationScreen] to read as "alive/working" while
  /// generation is in progress; left off (a still avatar) wherever
  /// the coach is just present rather than actively "thinking".
  final bool pulse;

  /// An optional specific image for this call site to show instead of
  /// the default gradient-and-icon orb — e.g.
  /// `'assets/images/coach/workout_complete.png'`. Rendered at the
  /// same circular footprint either way, so swapping this in for a
  /// particular screen doesn't change that screen's layout at all.
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final asset = imageAsset;

    final orb = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: asset == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.55),
                ],
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.35),
            blurRadius: size * 0.35,
            spreadRadius: size * 0.02,
          ),
        ],
      ),
      child: asset == null
          ? Icon(
              Icons.self_improvement_rounded,
              color: Colors.white,
              size: size * 0.46,
            )
          : ClipOval(
              child: Image.asset(
                asset,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // Falls back to the default icon look if the asset is
                // ever missing/fails to decode, rather than a broken-
                // image glyph on what's meant to be a premium screen.
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.self_improvement_rounded,
                    color: Colors.white,
                    size: size * 0.46,
                  ),
                ),
              ),
            ),
    );

    if (!pulse || MediaQuery.of(context).disableAnimations) return orb;

    return _PulsingAvatar(child: orb);
  }
}

class _PulsingAvatar extends StatefulWidget {
  const _PulsingAvatar({required this.child});

  final Widget child;

  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.08);
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}
