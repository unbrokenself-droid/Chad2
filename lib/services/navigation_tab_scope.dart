import 'package:flutter/widgets.dart';

import 'navigation_tab_controller.dart';

/// Makes the app's single [NavigationTabController] available to any
/// screen — the same [InheritedNotifier] pattern every other
/// service-backed scope in this app uses (see `PremiumScope` for a
/// close comparison), so a widget anywhere below this in the tree can
/// read [NavigationTabController.current] or call
/// [NavigationTabController.switchTo] without threading a callback
/// down through every intermediate widget.
class NavigationTabScope extends InheritedNotifier<NavigationTabController> {
  const NavigationTabScope({
    super.key,
    required NavigationTabController service,
    required super.child,
  }) : super(notifier: service);

  /// Looks up the nearest [NavigationTabScope].
  ///
  /// With [listen] true (the default), the calling widget rebuilds
  /// whenever the selected tab changes — appropriate for something
  /// that needs to *display* the current tab. Pass `false` from
  /// callbacks and event handlers that only need to call
  /// [NavigationTabController.switchTo] once, without subscribing to
  /// future changes (e.g. a button that sends the user to another
  /// tab has no reason to rebuild every time the tab changes for some
  /// unrelated reason).
  static NavigationTabController of(
    BuildContext context, {
    bool listen = true,
  }) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<NavigationTabScope>()
        : context
              .getElementForInheritedWidgetOfExactType<NavigationTabScope>()
              ?.widget
              as NavigationTabScope?;
    assert(scope != null, 'No NavigationTabScope found in context');
    return scope!.notifier!;
  }
}
