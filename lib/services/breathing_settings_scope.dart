import 'package:flutter/widgets.dart';

import 'breathing_settings_service.dart';

/// Makes a single [BreathingSettingsService] instance available to the
/// whole widget tree below it, without pulling in a state-management
/// package — the same approach [AccessibilityScope], [CompletionScope],
/// and the app's other scopes use.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `BreathingSettingsScope.of(context)`.
class BreathingSettingsScope extends InheritedNotifier<BreathingSettingsService> {
  const BreathingSettingsScope({
    super.key,
    required BreathingSettingsService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [BreathingSettingsService] above [context].
  ///
  /// Registers [context] to rebuild whenever a breathing preference
  /// changes anywhere in the app. Throws if no [BreathingSettingsScope]
  /// is found above [context].
  static BreathingSettingsService of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BreathingSettingsScope>();
    assert(scope != null, 'No BreathingSettingsScope found in context');
    return scope!.notifier!;
  }
}
