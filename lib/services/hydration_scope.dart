import 'package:flutter/widgets.dart';

import 'hydration_service.dart';

/// Makes a single [HydrationService] instance available to the whole
/// widget tree below it, without pulling in a state-management
/// package — the same approach [FavoritesScope] and
/// [DailyRoutineScope] use.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `HydrationScope.of(context)`.
class HydrationScope extends InheritedNotifier<HydrationService> {
  const HydrationScope({
    super.key,
    required HydrationService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [HydrationService] above [context].
  ///
  /// Registers [context] to rebuild whenever the service calls
  /// `notifyListeners()` (e.g. after water is logged elsewhere).
  /// Throws if no [HydrationScope] is found above [context], since
  /// every screen that needs hydration state expects one to always be
  /// present.
  static HydrationService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<HydrationScope>();
    assert(scope != null, 'No HydrationScope found in context');
    return scope!.notifier!;
  }
}
