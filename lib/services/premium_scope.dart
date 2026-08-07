import 'package:flutter/widgets.dart';

import 'premium_service.dart';

/// Makes a single [PremiumService] instance available to the whole
/// widget tree below it, without pulling in a state-management
/// package — the same approach [ThemeModeScope] and [FavoritesScope]
/// use.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `PremiumScope.of(context)`.
class PremiumScope extends InheritedNotifier<PremiumService> {
  const PremiumScope({
    super.key,
    required PremiumService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [PremiumService] above [context].
  ///
  /// Registers [context] to rebuild whenever the service calls
  /// `notifyListeners()` (e.g. after the user upgrades or downgrades).
  /// Throws if no [PremiumScope] is found above [context], since
  /// every screen that checks feature access expects one to always be
  /// present.
  static PremiumService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PremiumScope>();
    assert(scope != null, 'No PremiumScope found in context');
    return scope!.notifier!;
  }
}
