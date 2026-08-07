import 'package:flutter/material.dart';

import '../../services/accessibility_scope.dart';

/// The tap-target size every widget below enforces when
/// `AccessibilityService.largeTouchTargets` is on — Material's own
/// standard minimum (48x48dp), which is exactly what that setting's
/// doc comment already promises ("at least 48x48"). Not a new,
/// separate number invented for this fix; the two existing
/// implementations ([FavoriteHeartButton], [BookmarkButton]) already
/// target this same value, so using it here keeps every place that
/// reads the setting agreeing on what "large" means.
const double kLargeTouchTargetSize = 48.0;

/// Ensures [child] occupies at least [kLargeTouchTargetSize] in both
/// dimensions when `largeTouchTargets` is on; otherwise returns
/// [child] completely unchanged, with no extra widget in the tree.
///
/// For wrapping a small, fixed-size interactive element from the
/// outside — an icon button, a menu trigger — where there's no
/// existing size/style property on the widget itself to adjust
/// directly. That's a real distinction, not a stylistic one: a
/// [FilledButton] or Material [Chip] already has its own
/// `minimumSize`/sizing properties, and setting those directly is
/// the correct, idiomatic fix for those — wrapping them in an
/// external box instead can leave the *visible* size unchanged while
/// the ink response/tap region silently doesn't match it, which is a
/// worse, more confusing outcome than the gap this exists to close.
/// See `accessibility_service.dart`'s `largeTouchTargets` doc comment
/// for the promise this keeps, and `PrimaryButton`, `SettingsNavTile`,
/// `AppBottomNavigationBar`, and the three filter-chip widgets for
/// examples of the "adjust the widget's own sizing property instead"
/// approach.
class MinTapTarget extends StatelessWidget {
  const MinTapTarget({
    super.key,
    required this.child,
    this.minSize = kLargeTouchTargetSize,
  });

  final Widget child;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    final largeTargets = AccessibilityScope.of(context).largeTouchTargets;
    if (!largeTargets) return child;

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
      child: Center(child: child),
    );
  }
}
