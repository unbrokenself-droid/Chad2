import 'package:flutter/material.dart';

/// Wraps [child] in a one-time fade + slide-up entrance animation,
/// delayed by [index] so a list or grid of these appears to cascade
/// in rather than popping in all at once.
///
/// Purely cosmetic: it does not affect layout size or hit-testing
/// once the animation completes. Respects the platform's
/// reduce-motion setting — when enabled, [child] simply appears
/// immediately with no fade, slide, or stagger delay.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;

    if (MediaQuery.of(context).disableAnimations) {
      // Reduce-motion: skip straight to the end state, no delay.
      _controller.value = 1.0;
      return;
    }

    // Cap the stagger delay so long lists don't leave later items
    // waiting an unreasonably long time before appearing.
    final delayMs = (widget.index * 40).clamp(0, 400);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
