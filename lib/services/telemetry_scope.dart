import 'package:flutter/widgets.dart';

import 'telemetry_service.dart';

/// Makes the app's single [TelemetryService] available to any screen
/// — the same [InheritedNotifier] pattern every other service-backed
/// scope in this app uses.
class TelemetryScope extends InheritedNotifier<TelemetryService> {
  const TelemetryScope({
    super.key,
    required TelemetryService service,
    required super.child,
  }) : super(notifier: service);

  /// Looks up the nearest [TelemetryScope].
  ///
  /// [listen] defaults to `false` here, unlike most scopes in this
  /// app — the overwhelmingly common use is firing an event from a
  /// callback or `initState`, which has no reason to rebuild when a
  /// telemetry preference changes. Pass `true` from the Settings
  /// screen, where the toggles genuinely need to reflect current
  /// state.
  static TelemetryService of(BuildContext context, {bool listen = false}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<TelemetryScope>()
        : context
              .getElementForInheritedWidgetOfExactType<TelemetryScope>()
              ?.widget
              as TelemetryScope?;
    assert(scope != null, 'No TelemetryScope found in context');
    return scope!.notifier!;
  }
}
