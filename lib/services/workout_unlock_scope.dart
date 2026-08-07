import 'package:flutter/widgets.dart';

import 'workout_unlock_service.dart';

/// Makes a single [WorkoutUnlockService] instance available to the
/// whole widget tree below it — the same approach [PremiumScope] and
/// every other `*Scope` in this app use.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `WorkoutUnlockScope.of(context)`.
class WorkoutUnlockScope extends InheritedNotifier<WorkoutUnlockService> {
  const WorkoutUnlockScope({
    super.key,
    required WorkoutUnlockService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [WorkoutUnlockService] above [context].
  ///
  /// Registers [context] to rebuild whenever the service calls
  /// `notifyListeners()` (e.g. the instant a rewarded ad unlocks a
  /// collection). Throws if no [WorkoutUnlockScope] is found above
  /// [context], since every screen showing a featured collection
  /// expects one to always be present.
  static WorkoutUnlockService of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<WorkoutUnlockScope>();
    assert(scope != null, 'No WorkoutUnlockScope found in context');
    return scope!.notifier!;
  }
}
