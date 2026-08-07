import 'package:flutter/widgets.dart';

import 'theme_mode_service.dart';

/// Makes a single [ThemeModeService] instance available to the whole
/// widget tree below it, without pulling in a state-management
/// package — the same approach [FavoritesScope] and [HydrationScope]
/// use.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `ThemeModeScope.of(context)`.
class ThemeModeScope extends InheritedNotifier<ThemeModeService> {
  const ThemeModeScope({
    super.key,
    required ThemeModeService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [ThemeModeService] above [context].
  ///
  /// Registers [context] to rebuild whenever the service calls
  /// `notifyListeners()` (e.g. after the appearance mode changes in
  /// Settings). Throws if no [ThemeModeScope] is found above
  /// [context], since every screen that needs the theme mode expects
  /// one to always be present.
  static ThemeModeService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeModeScope>();
    assert(scope != null, 'No ThemeModeScope found in context');
    return scope!.notifier!;
  }
}
