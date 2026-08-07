import 'package:flutter/widgets.dart';

import 'daily_routine_service.dart';

/// Makes a single [DailyRoutineService] instance available to the
/// whole widget tree below it, without pulling in a state-management
/// package — the same approach [FavoritesScope] and [CompletionScope]
/// use.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `DailyRoutineScope.of(context)`.
class DailyRoutineScope extends InheritedNotifier<DailyRoutineService> {
  const DailyRoutineScope({
    super.key,
    required DailyRoutineService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [DailyRoutineService] above [context].
  ///
  /// Registers [context] to rebuild whenever the service calls
  /// `notifyListeners()` (e.g. once today's routine is generated).
  /// Throws if no [DailyRoutineScope] is found above [context], since
  /// every screen that needs the daily routine expects one to always
  /// be present.
  static DailyRoutineService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<DailyRoutineScope>();
    assert(scope != null, 'No DailyRoutineScope found in context');
    return scope!.notifier!;
  }
}
