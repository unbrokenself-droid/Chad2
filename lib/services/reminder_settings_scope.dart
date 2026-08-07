import 'package:flutter/widgets.dart';

import 'reminder_settings_service.dart';

/// Makes a single [ReminderSettingsService] instance available to the
/// whole widget tree below it, without pulling in a state-management
/// package — the same approach [HydrationScope] and [SkincareScope]
/// use.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `ReminderSettingsScope.of(context)`.
class ReminderSettingsScope
    extends InheritedNotifier<ReminderSettingsService> {
  const ReminderSettingsScope({
    super.key,
    required ReminderSettingsService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [ReminderSettingsService] above [context].
  ///
  /// Registers [context] to rebuild whenever the service calls
  /// `notifyListeners()` (e.g. after any reminder's toggle or
  /// schedule changes). Throws if no [ReminderSettingsScope] is found
  /// above [context], since every screen that needs reminder state
  /// expects one to always be present.
  static ReminderSettingsService of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ReminderSettingsScope>();
    assert(scope != null, 'No ReminderSettingsScope found in context');
    return scope!.notifier!;
  }
}
