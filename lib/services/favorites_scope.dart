import 'package:flutter/widgets.dart';

import 'favorites_service.dart';

/// Makes a single [FavoritesService] instance available to the whole
/// widget tree below it, without pulling in a state-management
/// package for what's otherwise the app's only shared, cross-screen
/// piece of state.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `FavoritesScope.of(context)`.
class FavoritesScope extends InheritedNotifier<FavoritesService> {
  const FavoritesScope({
    super.key,
    required FavoritesService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [FavoritesService] above [context].
  ///
  /// Registers [context] to rebuild whenever the service calls
  /// `notifyListeners()` (e.g. after a favorite is toggled elsewhere),
  /// same as `InheritedWidget.dependOnInheritedWidgetOfExactType`.
  /// Throws if no [FavoritesScope] is found above [context], since
  /// every screen that needs favorites expects one to always be
  /// present.
  static FavoritesService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<FavoritesScope>();
    assert(scope != null, 'No FavoritesScope found in context');
    return scope!.notifier!;
  }
}
