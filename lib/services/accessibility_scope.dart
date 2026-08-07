import 'package:flutter/widgets.dart';

import 'accessibility_service.dart';

/// Makes a single [AccessibilityService] instance available to the
/// whole widget tree below it, without pulling in a state-management
/// package — the same approach [ThemeModeScope] and [FavoritesScope]
/// use.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `AccessibilityScope.of(context)`.
class AccessibilityScope extends InheritedNotifier<AccessibilityService> {
  const AccessibilityScope({
    super.key,
    required AccessibilityService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [AccessibilityService] above [context].
  ///
  /// Registers [context] to rebuild whenever the service calls
  /// `notifyListeners()` (e.g. after a preference changes in
  /// Settings). Throws if no [AccessibilityScope] is found above
  /// [context], since every screen that needs accessibility
  /// preferences expects one to always be present.
  static AccessibilityService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AccessibilityScope>();
    assert(scope != null, 'No AccessibilityScope found in context');
    return scope!.notifier!;
  }
}
