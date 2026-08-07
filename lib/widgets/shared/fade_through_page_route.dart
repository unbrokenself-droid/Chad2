import 'package:flutter/material.dart';

/// A [PageRouteBuilder] that combines a subtle fade with a gentle
/// upward slide, giving pushed screens a smoother, more intentional
/// entrance than the platform default — while staying simple enough
/// to pair cleanly with a [Hero] animation running at the same time.
///
/// The incoming page fades and slides up from a small offset; the
/// outgoing page fades out in place. Both curves are eased so the
/// motion settles rather than stopping abruptly. When the platform's
/// reduce-motion accessibility setting is on, the transition collapses
/// to an instant cut (no fade or slide) rather than skipping partway
/// through a motion the user asked to avoid.
class FadeThroughPageRoute<T> extends PageRouteBuilder<T> {
  FadeThroughPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (MediaQuery.of(context).disableAnimations) {
              return child;
            }

            final entering = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final exiting = CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(entering),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(entering),
                child: FadeTransition(
                  opacity: Tween<double>(
                    begin: 1,
                    end: 0.4,
                  ).animate(exiting),
                  child: child,
                ),
              ),
            );
          },
        );
}
