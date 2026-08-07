import 'package:flutter/widgets.dart';

import 'wellness_score_service.dart';

/// Makes a single [WellnessScoreService] instance available to the
/// whole widget tree below it, without pulling in a state-management
/// package — the same approach [HydrationScope] and [StreakScope]
/// use.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `WellnessScoreScope.of(context)`.
class WellnessScoreScope extends InheritedNotifier<WellnessScoreService> {
  const WellnessScoreScope({
    super.key,
    required WellnessScoreService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [WellnessScoreService] above [context].
  ///
  /// Registers [context] to rebuild whenever the score's underlying
  /// data changes (exercise, hydration, skincare, or posture
  /// reminders). Throws if no [WellnessScoreScope] is found above
  /// [context], since every screen that needs the wellness score
  /// expects one to always be present.
  static WellnessScoreService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<WellnessScoreScope>();
    assert(scope != null, 'No WellnessScoreScope found in context');
    return scope!.notifier!;
  }
}
