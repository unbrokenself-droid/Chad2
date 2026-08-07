import 'package:flutter/foundation.dart';

/// The five top-level destinations behind [MainNavigationScreen]'s
/// bottom navigation bar, in the same order [AppBottomNavigationBar]
/// displays them and [MainNavigationScreen]'s `_tabs` list builds
/// them.
enum AppTab { home, exercises, routine, progress, settings }

/// Lets any screen request switching the bottom navigation bar to a
/// different tab, without needing a reference to
/// [MainNavigationScreen] itself.
///
/// Before this existed, a screen nested inside one tab (e.g. Home)
/// had no way to send the user to another tab (e.g. Exercises) — the
/// only options were a dead-end button, or [MainNavigationScreen]
/// growing a bespoke callback threaded down for every screen that
/// might ever want one. This is deliberately generic instead: any
/// current or future screen reachable from inside the tab shell can
/// call [switchTo] the same way [MainNavigationScreen] itself
/// responds to a bottom-nav tap, and nothing needs a direct reference
/// to [MainNavigationScreen] to do it — see [NavigationTabScope].
///
/// Purely in-memory UI state, not persisted — like any other screen's
/// local navigation state, which tab was last selected doesn't need
/// to survive an app restart.
class NavigationTabController extends ChangeNotifier {
  AppTab _current = AppTab.home;

  /// The currently selected tab.
  AppTab get current => _current;

  /// Switches to [tab]. A no-op (and doesn't notify) if [tab] is
  /// already selected, so a button that unconditionally means "go to
  /// Exercises" can call this without checking first.
  void switchTo(AppTab tab) {
    if (tab == _current) return;
    _current = tab;
    notifyListeners();
  }
}
