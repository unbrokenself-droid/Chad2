import 'package:flutter/material.dart';

import '../../services/accessibility_scope.dart';
import '../../utils/app_haptics.dart';

/// A tappable bookmark icon that toggles bookmarked state with a
/// small pop animation.
///
/// Purely presentational with respect to *what* is bookmarked —
/// [isBookmarked] and [onToggle] are supplied by the caller (backed
/// by [LibraryBookmarksService]), so this widget only owns the
/// transient animation, not the persisted data. Deliberately simpler
/// than [FavoriteHeartButton]'s heart-burst effect, since bookmarking
/// an article is a lower-emphasis action than favoriting an exercise.
class BookmarkButton extends StatefulWidget {
  const BookmarkButton({
    super.key,
    required this.isBookmarked,
    required this.onToggle,
    this.size = 22,
    this.activeColor,
    this.inactiveColor,
  });

  final bool isBookmarked;
  final VoidCallback onToggle;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  State<BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<BookmarkButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onToggle();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    widget.isBookmarked ? AppHaptics.light() : AppHaptics.medium();
    if (!reduceMotion) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = widget.activeColor ?? colorScheme.primary;
    final inactive = widget.inactiveColor ?? colorScheme.onSurfaceVariant;
    final color = widget.isBookmarked ? active : inactive;
    final label = widget.isBookmarked ? 'Remove bookmark' : 'Bookmark article';

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
          child: Center(
            child: AnimatedBuilder(
              animation: _scale,
              builder: (context, child) {
                return Transform.scale(scale: _scale.value, child: child);
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  widget.isBookmarked
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  key: ValueKey(widget.isBookmarked),
                  color: color,
                  size: widget.size,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
