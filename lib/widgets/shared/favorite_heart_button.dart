import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/accessibility_scope.dart';
import '../../utils/app_haptics.dart';

/// A tappable heart icon that toggles favorited state with a bouncy
/// pop animation, plus a brief burst of small satellite hearts when
/// an exercise is newly favorited.
///
/// Purely presentational and stateless with respect to *what* is
/// favorited — [isFavorite] and [onToggle] are supplied by the caller
/// (typically backed by a `FavoritesService`), so this widget only
/// owns the transient animation state, not the persisted data.
class FavoriteHeartButton extends StatefulWidget {
  const FavoriteHeartButton({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    this.size = 24,
    this.activeColor,
    this.inactiveColor,
    this.semanticLabel,
  });

  /// Whether the exercise this button represents is currently
  /// favorited. Drives the filled/outline icon swap and pop animation.
  final bool isFavorite;

  /// Called when the user taps the heart. The caller is responsible
  /// for actually flipping and persisting the favorite state (e.g. via
  /// `FavoritesService.toggle`); this widget only reports the tap.
  final VoidCallback onToggle;

  /// Diameter of the heart icon itself, in logical pixels. The tap
  /// target is padded out to at least 40x40 regardless of this value.
  final double size;

  /// Color used when favorited. Defaults to a warm red so the filled
  /// heart reads clearly against the app's blue accent elsewhere.
  final Color? activeColor;

  /// Color used when not favorited. Defaults to a muted outline tone.
  final Color? inactiveColor;

  /// Overrides the semantic label announced by screen readers.
  /// Defaults to "Add to favorites" / "Remove from favorites".
  final String? semanticLabel;

  @override
  State<FavoriteHeartButton> createState() => _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends State<FavoriteHeartButton>
    with TickerProviderStateMixin {
  late final AnimationController _popController;
  late final Animation<double> _scale;
  late final AnimationController _burstController;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    // Overshoots past 1.0 then settles, so the heart reads as a pop
    // rather than a flat linear grow.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
    ]).animate(_popController);

    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _popController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  void _handleTap() {
    final wasFavorite = widget.isFavorite;
    widget.onToggle();
    // Only pop/burst on the favorite → newly-favorited transition, not
    // on un-favoriting, so removing a favorite reads as a calmer,
    // more deliberate action. The haptic mirrors that same asymmetry:
    // a firmer confirmation when adding, a lighter tick when removing.
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ??
        false;
    if (!wasFavorite) {
      AppHaptics.medium();
      if (!reduceMotion) {
        _popController.forward(from: 0);
        _burstController.forward(from: 0);
      }
    } else {
      AppHaptics.light();
      if (!reduceMotion) {
        _popController.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = widget.activeColor ?? const Color(0xFFE0435B);
    final inactive = widget.inactiveColor ?? colorScheme.onSurfaceVariant;
    final color = widget.isFavorite ? active : inactive;
    final label = widget.semanticLabel ??
        (widget.isFavorite ? 'Remove from favorites' : 'Add to favorites');
    // Base padding keeps the tap target at 40x40 minimum, comfortably
    // inside guidelines already; the "Larger Touch Targets"
    // accessibility preference bumps that to at least 48x48 to match
    // the app's other enlarged controls.
    final largeTargets = AccessibilityScope.of(context).largeTouchTargets;
    final tapTargetSize = largeTargets
        ? (widget.size + 16).clamp(48, double.infinity)
        : widget.size + 16;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: SizedBox(
          width: tapTargetSize.toDouble(),
          height: tapTargetSize.toDouble(),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _burstController,
                builder: (context, child) {
                  if (_burstController.isDismissed) {
                    return const SizedBox.shrink();
                  }
                  return _HeartBurst(
                    progress: _burstController.value,
                    color: active,
                    radius: widget.size * 0.9,
                  );
                },
              ),
              AnimatedBuilder(
                animation: _scale,
                builder: (context, child) {
                  return Transform.scale(scale: _scale.value, child: child);
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(widget.isFavorite),
                    color: color,
                    size: widget.size,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A short-lived burst of small hearts radiating outward, shown once
/// when an exercise is newly favorited (not on un-favoriting).
class _HeartBurst extends StatelessWidget {
  const _HeartBurst({
    required this.progress,
    required this.color,
    required this.radius,
  });

  final double progress;
  final Color color;
  final double radius;

  static const int _particleCount = 6;

  @override
  Widget build(BuildContext context) {
    // Particles fly outward and fade in the back half of the
    // animation, so the burst reads as a quick sparkle rather than a
    // lingering distraction.
    final distance = Curves.easeOut.transform(progress) * radius;
    final opacity = (1 - progress).clamp(0.0, 1.0);

    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < _particleCount; i++)
            Builder(
              builder: (context) {
                final angle = (2 * math.pi / _particleCount) * i;
                final dx = distance * math.cos(angle);
                final dy = distance * math.sin(angle);
                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: Opacity(
                    opacity: opacity,
                    child: Icon(
                      Icons.favorite,
                      size: 8,
                      color: color,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

}
