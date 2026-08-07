import 'package:flutter/material.dart';

import '../../models/premium_feature.dart';
import '../../services/premium_scope.dart';
import 'upgrade_card.dart';

/// Shows [child] if [feature] is unlocked for the user's current
/// tier, or an [UpgradeCard] in its place otherwise.
///
/// The single entry point screens should use to gate a whole section
/// of UI behind Premium — wrap the feature's content in this rather
/// than branching on `PremiumScope.of(context).isUnlocked(...)`
/// directly, so every locked spot in the app gets the same upgrade
/// treatment for free and stays in sync if that treatment changes.
///
/// ```dart
/// PremiumGate(
///   feature: PremiumFeature.customRoutines,
///   child: CustomRoutinesScreen(),
/// )
/// ```
///
/// For gating a small action rather than replacing a whole section
/// (e.g. a button that should open a paywall instead of running its
/// normal action), use [PremiumScope.of(context).isUnlocked] directly.
class PremiumGate extends StatelessWidget {
  const PremiumGate({
    super.key,
    required this.feature,
    required this.child,
    this.style = UpgradeCardStyle.full,
    this.title,
    this.message,
  });

  /// The feature this section of UI requires.
  final PremiumFeature feature;

  /// The real content, shown once [feature] is unlocked.
  final Widget child;

  /// Passed through to [UpgradeCard] when locked.
  final UpgradeCardStyle style;

  /// Passed through to [UpgradeCard] when locked.
  final String? title;

  /// Passed through to [UpgradeCard] when locked.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final premium = PremiumScope.of(context);
    if (premium.isUnlocked(feature)) return child;
    return UpgradeCard(
      feature: feature,
      style: style,
      title: title,
      message: message,
    );
  }
}
