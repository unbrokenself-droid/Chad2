import 'package:flutter/material.dart';

import '../../models/workout_collection.dart';
import '../../screens/upgrade_screen.dart';
import '../../services/ads_manager.dart';
import '../../services/ads_scope.dart';
import '../../services/workout_unlock_scope.dart';
import '../shared/fade_through_page_route.dart';
import '../shared/primary_button.dart';

/// Opens [WorkoutUnlockSheet] for [collection].
///
/// Convenience wrapper around [showModalBottomSheet], matching how
/// every other sheet in this app is exposed, so callers (see
/// [WorkoutCollectionCard]/[WorkoutCollectionDetailsScreen]) don't
/// need to know this sheet's shape or styling.
Future<void> showWorkoutUnlockSheet(
  BuildContext context, {
  required WorkoutCollection collection,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => WorkoutUnlockSheet(collection: collection),
  );
}

/// Lets the user choose how to unlock a locked featured
/// [WorkoutCollection]: watch one rewarded ad to unlock just this one
/// permanently, or upgrade to Premium to unlock every collection and
/// remove ads entirely.
///
/// Watching the ad never happens without this explicit choice — there
/// is no "auto-play" path into [AdsManager.showRewardedAd] anywhere
/// else in the app. A failed, skipped, or otherwise unrewarded ad
/// (see [RewardedAdResult]) leaves the collection locked and shows an
/// explanatory message in place of the options, rather than silently
/// closing the sheet as if nothing happened.
class WorkoutUnlockSheet extends StatefulWidget {
  const WorkoutUnlockSheet({super.key, required this.collection});

  final WorkoutCollection collection;

  @override
  State<WorkoutUnlockSheet> createState() => _WorkoutUnlockSheetState();
}

class _WorkoutUnlockSheetState extends State<WorkoutUnlockSheet> {
  bool _watchingAd = false;
  String? _errorMessage;

  Future<void> _watchRewardedAd(AdsManager ads) async {
    setState(() {
      _watchingAd = true;
      _errorMessage = null;
    });

    final result = await ads.showRewardedAd();
    if (!mounted) return;

    switch (result) {
      case RewardedAdResult.rewarded:
        await WorkoutUnlockScope.of(
          context,
        ).unlock(widget.collection.id);
        if (!mounted) return;
        Navigator.of(context).pop();
      case RewardedAdResult.notRewarded:
        setState(() {
          _watchingAd = false;
          _errorMessage =
              "Ad closed before finishing — this workout isn't unlocked. "
              'You can try again anytime.';
        });
      case RewardedAdResult.notReady:
        setState(() {
          _watchingAd = false;
          _errorMessage =
              "No ad is ready right now. Check your connection and try "
              'again in a moment.';
        });
      case RewardedAdResult.failedToShow:
        setState(() {
          _watchingAd = false;
          _errorMessage = 'Something went wrong showing the ad. Please '
              'try again.';
        });
    }
  }

  void _openUpgrade() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      FadeThroughPageRoute(builder: (context) => const UpgradeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ads = AdsScope.of(context);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_open_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unlock This Workout',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.collection.title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _UnlockOption(
              icon: Icons.smart_display_rounded,
              title: 'Watch an Ad',
              description:
                  'Watch one short ad to unlock this workout permanently.',
              buttonLabel: _watchingAd ? 'Loading…' : 'Watch Ad',
              onPressed: _watchingAd || !ads.isRewardedAdReady
                  ? null
                  : () => _watchRewardedAd(ads),
              loading: _watchingAd,
              filled: false,
            ),
            const SizedBox(height: 12),
            _UnlockOption(
              icon: Icons.workspace_premium_rounded,
              title: 'Upgrade to Premium',
              description:
                  'Unlock every workout collection forever and remove all '
                  'ads.',
              buttonLabel: 'Upgrade',
              onPressed: _openUpgrade,
              loading: false,
              filled: true,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlockOption extends StatelessWidget {
  const _UnlockOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    required this.loading,
    required this.filled,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final bool loading;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          if (filled)
            PrimaryButton(label: buttonLabel, onPressed: onPressed)
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(buttonLabel),
              ),
            ),
        ],
      ),
    );
  }
}
