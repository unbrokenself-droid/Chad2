import 'package:flutter/widgets.dart';

import 'custom_routines_service.dart';

/// Makes a single [CustomRoutinesService] instance available to the
/// whole widget tree below it, the same [InheritedNotifier] pattern
/// [FavoritesScope] and [DailyRoutineScope] use.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `CustomRoutinesScope.of(context)`.
class CustomRoutinesScope extends InheritedNotifier<CustomRoutinesService> {
  const CustomRoutinesScope({
    super.key,
    required CustomRoutinesService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [CustomRoutinesService] above [context].
  ///
  /// Registers [context] to rebuild whenever the service calls
  /// `notifyListeners()` (e.g. after a routine is created, renamed,
  /// or edited elsewhere). Throws if no [CustomRoutinesScope] is
  /// found above [context], since every screen that needs custom
  /// routines expects one to always be present.
  static CustomRoutinesService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<CustomRoutinesScope>();
    assert(scope != null, 'No CustomRoutinesScope found in context');
    return scope!.notifier!;
  }
}
