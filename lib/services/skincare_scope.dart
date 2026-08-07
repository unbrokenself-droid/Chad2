import 'package:flutter/widgets.dart';

import 'skincare_service.dart';

/// Makes a single [SkincareService] instance available to the whole
/// widget tree below it, without pulling in a state-management
/// package — the same approach [FavoritesScope] and [HydrationScope]
/// use.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `SkincareScope.of(context)`.
class SkincareScope extends InheritedNotifier<SkincareService> {
  const SkincareScope({
    super.key,
    required SkincareService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [SkincareService] above [context].
  ///
  /// Registers [context] to rebuild whenever the service calls
  /// `notifyListeners()` (e.g. after a step is checked off
  /// elsewhere). Throws if no [SkincareScope] is found above
  /// [context], since every screen that needs skincare state expects
  /// one to always be present.
  static SkincareService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SkincareScope>();
    assert(scope != null, 'No SkincareScope found in context');
    return scope!.notifier!;
  }
}
