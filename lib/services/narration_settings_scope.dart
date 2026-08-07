import 'package:flutter/widgets.dart';

import 'narration_settings_service.dart';

/// Makes a single [NarrationSettingsService] instance available to
/// the whole widget tree below it — the same approach [HydrationScope]
/// and every other `*Scope` in this app use.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `NarrationSettingsScope.of(context)`.
class NarrationSettingsScope extends InheritedNotifier<NarrationSettingsService> {
  const NarrationSettingsScope({
    super.key,
    required NarrationSettingsService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [NarrationSettingsService] above [context].
  ///
  /// Registers [context] to rebuild whenever the service calls
  /// `notifyListeners()` (e.g. after a slider changes in
  /// [NarrationSettingsSheet]). Throws if no [NarrationSettingsScope]
  /// is found above [context], since every screen that needs
  /// narration settings expects one to always be present.
  static NarrationSettingsService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<NarrationSettingsScope>();
    assert(scope != null, 'No NarrationSettingsScope found in context');
    return scope!.notifier!;
  }
}
