import 'package:flutter/widgets.dart';

import 'ads_manager.dart';

/// Makes a single [AdsManager] instance available to the whole widget
/// tree below it — the same approach [PremiumScope] and every other
/// `*Scope` in this app use.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `AdsScope.of(context)`.
class AdsScope extends InheritedNotifier<AdsManager> {
  const AdsScope({super.key, required AdsManager manager, required super.child})
    : super(notifier: manager);

  /// Returns the nearest [AdsManager] above [context].
  ///
  /// Registers [context] to rebuild whenever the manager calls
  /// `notifyListeners()` (e.g. once a preloaded ad finishes loading,
  /// or the instant Premium unlocks and every ad is disposed). Throws
  /// if no [AdsScope] is found above [context], since every screen
  /// that touches ads expects one to always be present.
  static AdsManager of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AdsScope>();
    assert(scope != null, 'No AdsScope found in context');
    return scope!.notifier!;
  }
}
