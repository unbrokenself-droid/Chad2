import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../../services/favorites_scope.dart';
import '../shared/favorite_heart_button.dart';
import 'exercise_badge_content.dart';

/// Human-readable label helpers for [Exercise] enum fields.
extension ExerciseDifficultyLabel on ExerciseDifficulty {
  String get label {
    switch (this) {
      case ExerciseDifficulty.beginner:
        return 'Beginner';
      case ExerciseDifficulty.intermediate:
        return 'Intermediate';
      case ExerciseDifficulty.advanced:
        return 'Advanced';
    }
  }

  /// A short icon glyph reinforcing difficulty at a glance, so the
  /// signal doesn't rely on color alone (helpful for color-blind users
  /// and in low-contrast lighting).
  IconData get icon {
    switch (this) {
      case ExerciseDifficulty.beginner:
        return Icons.looks_one_outlined;
      case ExerciseDifficulty.intermediate:
        return Icons.looks_two_outlined;
      case ExerciseDifficulty.advanced:
        return Icons.looks_3_outlined;
    }
  }

  /// An accent color for badges, scoped to small UI details rather
  /// than the whole card/page so the app's restrained four-color
  /// palette stays intact everywhere else.
  Color get color {
    switch (this) {
      case ExerciseDifficulty.beginner:
        return const Color(0xFF2E7D32);
      case ExerciseDifficulty.intermediate:
        return const Color(0xFFB8860B);
      case ExerciseDifficulty.advanced:
        return const Color(0xFFC62828);
    }
  }
}

extension ExerciseBodyPartLabel on ExerciseBodyPart {
  String get label {
    switch (this) {
      case ExerciseBodyPart.forehead:
        return 'Forehead';
      case ExerciseBodyPart.eyes:
        return 'Eyes';
      case ExerciseBodyPart.cheeks:
        return 'Cheeks';
      case ExerciseBodyPart.jawline:
        return 'Jawline';
      case ExerciseBodyPart.lips:
        return 'Lips';
      case ExerciseBodyPart.neck:
        return 'Neck';
      case ExerciseBodyPart.shoulders:
        return 'Shoulders';
      case ExerciseBodyPart.fullFace:
        return 'Full Face';
      case ExerciseBodyPart.wholeBody:
        return 'Whole Body';
    }
  }
}

/// Short, user-facing labels for [ExerciseCategory], as used in filter
/// chips. Deliberately shorter than the doc comments on the enum
/// itself (e.g. "Jaw" rather than "Jaw Relaxation") so they read
/// comfortably on a compact [FilterChip].
extension ExerciseCategoryLabel on ExerciseCategory {
  String get label {
    switch (this) {
      case ExerciseCategory.jawRelaxation:
        return 'Jaw';
      case ExerciseCategory.neckMobility:
        return 'Neck';
      case ExerciseCategory.shoulderPosture:
        return 'Posture';
      case ExerciseCategory.facialMassage:
        return 'Facial Massage';
      case ExerciseCategory.breathing:
        return 'Breathing';
      case ExerciseCategory.stretching:
        return 'Stretching';
    }
  }
}

/// Formats a [Duration] as a short label, e.g. "1 min" or "2 min".
String formatExerciseDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes > 0) return '$minutes min';
  final seconds = duration.inSeconds;
  return '$seconds sec';
}

/// A single exercise's card in the Exercises catalog.
///
/// Material 3 styled: tonal icon badge, filled/outlined difficulty and
/// completion badges, a press-scale micro-interaction, and a ripple on
/// tap. Purely presentational otherwise — no navigation is wired up
/// yet, [onTap] is accepted for future use but optional.
class ExerciseCard extends StatefulWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onTap,
    this.trailing,
  });

  final Exercise exercise;
  final VoidCallback? onTap;

  /// Optional widget shown at the top-right of the card, next to the
  /// favorite heart. Used by [RoutineScreen] to add a per-exercise
  /// "more options" menu (remove/replace) without every other caller
  /// of [ExerciseCard] needing to know about that feature.
  final Widget? trailing;

  /// Unique Hero tag for this card's icon badge, matched by the same
  /// tag on [ExerciseDetailsScreen]'s header icon so tapping a card
  /// morphs its icon into the details page rather than just cutting
  /// to a new screen.
  static String heroTag(String exerciseId) => 'exercise-icon-$exerciseId';

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (pressed) {
      _pressController.forward();
    } else {
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final exercise = widget.exercise;
    final difficultyColor = exercise.difficulty.color;
    final favorites = FavoritesScope.of(context);

    final semanticLabel = StringBuffer(exercise.title)
      ..write(', ${exercise.difficulty.label} difficulty')
      ..write(', ${formatExerciseDuration(exercise.duration)}')
      ..write(', targets ${exercise.bodyPart.label}');
    if (exercise.completed) semanticLabel.write(', completed today');

    return Semantics(
      // Provides one summary announcement for the card's title,
      // difficulty, duration, body part, and completion state, so a
      // screen reader reads it as a single coherent item rather than
      // fragmenting into every Text/Icon child. The individual
      // Text/Icon descendants that make up that summary are wrapped
      // in [ExcludeSemantics] below so they don't also announce
      // themselves; the favorite heart button is deliberately left
      // out of that exclusion since it's a separate interactive
      // control layered on top of this summary, not part of it.
      label: semanticLabel.toString(),
      button: widget.onTap != null,
      container: true,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(scale: _scale.value, child: child);
        },
        child: Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          elevation: 0,
          color: colorScheme.surfaceContainerHighest,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: _setPressed,
            splashColor: colorScheme.primary.withValues(alpha: 0.10),
            highlightColor: colorScheme.primary.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: ExerciseCard.heroTag(exercise.id),
                        // A custom flight shuttle keeps the badge a
                        // plain circle mid-flight (no border/ring),
                        // then each end fades its own extra
                        // decoration in — avoids morphing the
                        // completed-state ring's border width, which
                        // Hero can't tween cleanly.
                        flightShuttleBuilder: (
                          flightContext,
                          animation,
                          direction,
                          fromContext,
                          toContext,
                        ) {
                          return _HeroIconBadge(
                            exercise: exercise,
                            color: colorScheme.primary,
                          );
                        },
                        child: _IconBadge(
                          exercise: exercise,
                          completed: exercise.completed,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ExcludeSemantics(
                                    child: Text(
                                      exercise.title,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                // Nudged up/right slightly so its
                                // larger tap target doesn't visually
                                // push the title text, while still
                                // overlapping comfortably with the
                                // card's padding.
                                Transform.translate(
                                  offset: const Offset(8, -8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FavoriteHeartButton(
                                        size: 20,
                                        isFavorite: favorites.isFavorite(
                                          exercise.id,
                                        ),
                                        onToggle: () =>
                                            favorites.toggle(exercise.id),
                                      ),
                                      if (widget.trailing != null)
                                        widget.trailing!,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ExcludeSemantics(
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  _MetaItem(
                                    icon: Icons.schedule,
                                    label: formatExerciseDuration(
                                      exercise.duration,
                                    ),
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  _MetaItem(
                                    icon: Icons.accessibility_new,
                                    label: exercise.bodyPart.label,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ExcludeSemantics(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DifficultyBadge(
                          label: exercise.difficulty.label,
                          icon: exercise.difficulty.icon,
                          color: difficultyColor,
                        ),
                        if (exercise.completed)
                          _CompletedBadge(color: colorScheme.primary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain, static version of the icon badge used only while a [Hero]
/// flight is in progress between [ExerciseCard] and
/// [ExerciseDetailsScreen]. Keeping this separate from [_IconBadge]
/// (which is stateful and can carry a completed-state border) avoids
/// asking Hero to tween a conditional border mid-flight, which it
/// can't do smoothly.
class _HeroIconBadge extends StatelessWidget {
  const _HeroIconBadge({required this.exercise, required this.color});

  final Exercise exercise;
  final Color color;

  static const double _size = 52;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: ExerciseBadgeContent(
        exercise: exercise,
        size: _size,
        iconSize: 26,
        color: color,
      ),
    );
  }
}

/// The circular icon badge at the top-left of an [ExerciseCard].
///
/// Shows a subtle animated highlight ring when the exercise is marked
/// [completed], so completion reads as more than a static color swap.
class _IconBadge extends StatefulWidget {
  const _IconBadge({
    required this.exercise,
    required this.completed,
    required this.color,
  });

  final Exercise exercise;
  final bool completed;
  final Color color;

  @override
  State<_IconBadge> createState() => _IconBadgeState();
}

class _IconBadgeState extends State<_IconBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const double _size = 52;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.completed) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _IconBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completed && !oldWidget.completed) {
      _controller.forward(from: 0);
    } else if (!widget.completed && oldWidget.completed) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: widget.completed ? 0.18 : 0.12),
        shape: BoxShape.circle,
        border: widget.completed
            ? Border.all(color: widget.color.withValues(alpha: 0.5), width: 2)
            : null,
      ),
      child: ExerciseBadgeContent(
        exercise: widget.exercise,
        size: _size,
        iconSize: 26,
        color: widget.color,
      ),
    );
  }
}

/// A small icon + label pair used for the duration and body-part
/// facts shown under an [ExerciseCard]'s title.
class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// A small pill-shaped badge showing an exercise's difficulty level,
/// combining an icon and label so the signal isn't color-only.
class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small pill badge marking an exercise as completed.
class _CompletedBadge extends StatelessWidget {
  const _CompletedBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            'Completed',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
