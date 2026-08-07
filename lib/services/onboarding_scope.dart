import 'package:flutter/widgets.dart';

import 'onboarding_service.dart';

/// Makes a single [OnboardingService] instance available to the whole
/// widget tree below it, without pulling in a state-management
/// package — the same approach [ReminderSettingsScope] and the app's
/// other scopes use.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `OnboardingScope.of(context)`.
class OnboardingScope extends InheritedNotifier<OnboardingService> {
  const OnboardingScope({
    super.key,
    required OnboardingService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [OnboardingService] above [context].
  ///
  /// By default, registers [context] to rebuild whenever the service
  /// calls `notifyListeners()` (e.g. after onboarding completes).
  /// Pass `listen: false` for one-off reads/writes (e.g. inside a
  /// button handler) where a rebuild isn't needed. Throws if no
  /// [OnboardingScope] is found above [context].
  static OnboardingService of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<OnboardingScope>()
        : context.getInheritedWidgetOfExactType<OnboardingScope>();
    assert(scope != null, 'No OnboardingScope found in context');
    return scope!.notifier!;
  }
}
