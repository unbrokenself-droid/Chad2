import 'package:flutter/material.dart';

import '../../models/workout_collection.dart';
import '../../services/premium_scope.dart';
import '../../services/workout_unlock_scope.dart';
import '../shared/primary_button.dart';

/// Premium card for one [WorkoutCollection], shown in
/// [ExercisesScreen]'s horizontal collections rail. Tapping anywhere
/// on the card opens [WorkoutCollectionDetailsScreen]; the "Start"
/// button skips straight to [WorkoutSessionScreen] instead, for
/// anyone who already knows they want to jump in — *unless* the
/// collection is locked (see below), in which case both instead call
/// [onUnlockRequested].
///
/// **Locking.** A collection is locked when it's
/// [WorkoutCollection.featured], the user isn't
/// [PremiumService.isPremium], and it hasn't already been unlocked via
/// [WorkoutUnlockService] — read directly from [PremiumScope]/
/// [WorkoutUnlockScope] rather than passed in, so this card reacts
/// immediately to either changing (a purchase completing, a rewarded
/// ad unlocking this exact collection) without [ExercisesScreen]
/// needing to know or recompute anything. Locked, the card shows a
/// blurred overlay with a lock badge and an "Unlock" button in place
/// of the normal content, and both that button and the card's own tap
/// target call [onUnlockRequested] — [onTap]/[onStart] never fire on a
/// locked card at all.
///
/// **Background.** [WorkoutCollection.backgroundImage] is shown under
/// a dark gradient scrim (for text legibility regardless of the
/// photo's own brightness) when one exists; the handful of
/// collections without one yet fall back to the original tinted
/// gradient.
class WorkoutCollectionCard extends StatelessWidget {
  const WorkoutCollectionCard({
    super.key,
    required this.collection,
    required this.onTap,
    required this.onStart,
    required this.onUnlockRequested,
  });

  final WorkoutCollection collection;
  final VoidCallback onTap;
  final VoidCallback onStart;

  /// Called instead of [onTap]/[onStart] whenever this card is
  /// locked — see this class's doc comment.
  final VoidCallback onUnlockRequested;

  static const Map<WorkoutCollectionTier, IconData> _tierIcons = {
    WorkoutCollectionTier.beginner: Icons.spa_outlined,
    WorkoutCollectionTier.intermediate: Icons.trending_up_rounded,
    WorkoutCollectionTier.advanced: Icons.local_fire_department_rounded,
  };

  static const Map<WorkoutCollectionTier, Color> _tierColors = {
    WorkoutCollectionTier.beginner: Color(0xFF2E7D32),
    WorkoutCollectionTier.intermediate: Color(0xFF2962FF),
    WorkoutCollectionTier.advanced: Color(0xFFC2185B),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tierColor = _tierColors[collection.tier]!;
    final minutes = (collection.totalDuration.inSeconds / 60).ceil();
    final backgroundImage = collection.backgroundImage;

    final premium = PremiumScope.of(context);
    final unlockService = WorkoutUnlockScope.of(context);
    // Every collection is locked behind Premium/a rewarded-ad unlock
    // now, not just the ones marked featured — WorkoutCollection.featured
    // still exists and still drives which collections surface under
    // the "Featured" filter chip, it just no longer doubles as "is
    // this one locked" too.
    final isLocked = !premium.isPremium && !unlockService.isUnlocked(collection.id);

    return SizedBox(
      width: 260,
      height: 260,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLocked ? onUnlockRequested : onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (backgroundImage != null)
                Image.asset(
                  backgroundImage,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _GradientBackground(color: tierColor),
                )
              else
                _GradientBackground(color: tierColor),
              // Dark scrim so title/description/chips stay legible
              // over a photo of any brightness — heavier toward the
              // bottom, where the text actually sits.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _tierIcons[collection.tier],
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      collection.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      collection.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MetaChip(
                            icon: Icons.signal_cellular_alt_rounded,
                            label: collection.tier.label,
                          ),
                        ),
                        Expanded(
                          child: _MetaChip(
                            icon: Icons.schedule_rounded,
                            label: '$minutes min',
                          ),
                        ),
                        Expanded(
                          child: _MetaChip(
                            icon: Icons.format_list_numbered_rounded,
                            label: '${collection.exercises.length}x',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: isLocked ? 'Unlock' : 'Start',
                      icon: isLocked
                          ? Icons.lock_rounded
                          : Icons.play_arrow_rounded,
                      onPressed: isLocked ? onUnlockRequested : onStart,
                      backgroundColor: Colors.white,
                      foregroundColor: tierColor,
                    ),
                  ],
                ),
              ),
              if (isLocked)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              if (isLocked) const _LockedOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientBackground extends StatelessWidget {
  const _GradientBackground({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.9),
            color.withValues(alpha: 0.55),
          ],
        ),
      ),
    );
  }
}

/// The blurred "this is Premium content" cover shown over a locked
/// card — separate from the small corner lock badge
/// [WorkoutCollectionCard] draws alongside it, which stays visible
/// even before this overlay's own content is read.
///
/// A plain darkened scrim, deliberately not blurred — no
/// [BackdropFilter] here, just [ColoredBox] over the card underneath.
class _LockedOverlay extends StatelessWidget {
  const _LockedOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 34,
              ),
              SizedBox(height: 8),
              Text(
                'Premium Workout',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
