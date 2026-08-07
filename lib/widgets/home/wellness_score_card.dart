import 'dart:ui';

import 'package:flutter/material.dart';

import '../../services/wellness_score_service.dart';
import 'wellness_score_ring.dart';

/// Icon shown next to each [WellnessComponent] in the breakdown list.
IconData _iconFor(WellnessComponent component) {
  switch (component) {
    case WellnessComponent.exercise:
      return Icons.fitness_center;
    case WellnessComponent.hydration:
      return Icons.water_drop;
    case WellnessComponent.skincare:
      return Icons.spa;
    case WellnessComponent.posture:
      return Icons.accessibility_new;
  }
}

/// Dashboard card showing today's overall Wellness Score: a large
/// circular progress ring with the 0–100 total, a short
/// plain-language explanation of how the user is doing, and a compact
/// breakdown of how each of the four tracked habits contributed as
/// pill-style progress bars.
///
/// Purely presentational — takes an already-computed
/// [WellnessScoreSnapshot] rather than reading services directly, so
/// it can be dropped into Home (or anywhere else) without knowing
/// about [WellnessScoreScope]. Same contract as before this card's
/// visual redesign; only what it looks like changed, not what it
/// needs or does.
///
/// Frosted-glass treatment (a real [BackdropFilter] blur of whatever
/// sits behind it — [HomeScreen]'s own ambient background glow, by
/// design — plus a soft light border and layered shadow) rather than
/// a flat surface color, to read as the screen's centerpiece rather
/// than one dashboard tile among several.
class WellnessScoreCard extends StatelessWidget {
  const WellnessScoreCard({super.key, required this.snapshot});

  final WellnessScoreSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ringColor = WellnessScoreRing.colorFor(snapshot.score);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surface.withValues(alpha: 0.72),
                colorScheme.surface.withValues(alpha: 0.5),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: ringColor.withValues(alpha: 0.08),
                blurRadius: 40,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite_rounded, size: 18, color: ringColor),
                  const SizedBox(width: 8),
                  Text(
                    "TODAY'S WELLNESS SCORE",
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 380;
                  final ring = WellnessScoreRing(score: snapshot.score);
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot.explanation,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (final entry in snapshot.breakdown)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ComponentRow(entry: entry),
                        ),
                    ],
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        Center(child: ring),
                        const SizedBox(height: 20),
                        details,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ring,
                      const SizedBox(width: 24),
                      Expanded(child: details),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.entry});

  final WellnessComponentBreakdown entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final percent = (entry.progress * 100).round();
    final barColor = WellnessScoreRing.colorFor((entry.progress * 100).round());

    return Row(
      children: [
        Icon(_iconFor(entry.component), size: 15, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(entry.label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          // A capsule track/fill (fully rounded, not just softened
          // corners) reads as a pill in a way a lightly-rounded 4dp
          // radius doesn't — the whole point of this over the
          // straight bar it replaces.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: entry.progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Stack(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withValues(alpha: 0.08),
                        ),
                        child: const SizedBox.expand(),
                      ),
                      FractionallySizedBox(
                        widthFactor: value,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                barColor.withValues(alpha: 0.55),
                                barColor,
                              ],
                            ),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 34,
          child: Text(
            '$percent%',
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
