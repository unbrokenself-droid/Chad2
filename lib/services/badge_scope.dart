import 'package:flutter/widgets.dart';

import 'badge_service.dart';

/// Makes a single [BadgeService] instance available to the whole
/// widget tree below it, without pulling in a state-management
/// package — the same approach [StreakScope] and [WellnessScoreScope]
/// use.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `BadgeScope.of(context)`.
class BadgeScope extends InheritedNotifier<BadgeService> {
  const BadgeScope({
    super.key,
    required BadgeService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [BadgeService] above [context].
  ///
  /// Registers [context] to rebuild whenever badge progress or unlock
  /// state changes. Throws if no [BadgeScope] is found above
  /// [context], since every screen that needs badge state expects one
  /// to always be present.
  static BadgeService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BadgeScope>();
    assert(scope != null, 'No BadgeScope found in context');
    return scope!.notifier!;
  }
}
