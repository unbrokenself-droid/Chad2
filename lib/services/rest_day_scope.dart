import 'package:flutter/widgets.dart';

import 'rest_day_service.dart';

/// Makes a single [RestDayService] instance available to the whole
/// widget tree below it, without pulling in a state-management
/// package — the same approach [CompletionScope], [HydrationScope],
/// and [SkincareScope] use.
///
/// Wrap the app with this once (see `main.dart`), above the
/// [StreakScope] that reads from it, then read the service anywhere
/// below with `RestDayScope.of(context)`.
class RestDayScope extends InheritedNotifier<RestDayService> {
  const RestDayScope({
    super.key,
    required RestDayService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [RestDayService] above [context].
  ///
  /// Registers [context] to rebuild whenever a rest day is scheduled
  /// or unscheduled anywhere in the app. Throws if no [RestDayScope]
  /// is found above [context], since every screen that needs rest-day
  /// state expects one to always be present.
  static RestDayService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RestDayScope>();
    assert(scope != null, 'No RestDayScope found in context');
    return scope!.notifier!;
  }
}
