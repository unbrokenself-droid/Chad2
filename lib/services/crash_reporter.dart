import 'package:flutter/foundation.dart';

/// Where uncaught errors go.
///
/// Provider-agnostic for the same reason [AnalyticsService] is —
/// today's implementation writes to the debug console, and swapping
/// in Crashlytics (or Sentry, or anything else) is one line in
/// `main.dart` with no call-site changes.
abstract class CrashReporter {
  /// Called once at startup, before any [recordError] call.
  Future<void> initialize();

  /// Records a non-fatal or uncaught error with its stack trace.
  ///
  /// [fatal] distinguishes a crash that killed the app from a caught
  /// error worth knowing about — most providers separate the two in
  /// their dashboards, and conflating them makes crash-free-rate
  /// meaningless.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? context,
  });

  /// Adds a breadcrumb shown alongside any crash reported afterward.
  /// Useful for narrowing down *where* a crash happened, without
  /// needing a full analytics event for every navigation.
  Future<void> log(String message);

  /// Turns crash collection on or off at the provider level, in
  /// addition to [TelemetryService]'s own gate.
  Future<void> setCollectionEnabled(bool enabled);
}

/// The default [CrashReporter]: prints to the debug console.
/// **Nothing leaves the device.**
///
/// Ships today because no crash-reporting provider is configured yet
/// — see `firebase_telemetry.dart.template` and the README's
/// "Telemetry" section.
///
/// Worth being clear about the limitation: printing a fatal error to
/// a console nobody is watching in production is not crash
/// reporting. Until a real provider is wired up, production crashes
/// remain invisible — which is exactly the gap the audit flagged, and
/// this class does not close it on its own. What it does close is the
/// *plumbing* gap: `main.dart`'s error handlers now route somewhere,
/// so activating a provider is a one-line change rather than a
/// from-scratch integration.
class DebugCrashReporter implements CrashReporter {
  @override
  Future<void> initialize() async {
    debugPrint('[crash] initialized (debug sink — nothing is sent)');
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? context,
  }) async {
    debugPrint(
      '[crash] ${fatal ? 'FATAL' : 'non-fatal'}'
      '${context == null ? '' : ' ($context)'}: $error',
    );
    if (stack != null) debugPrint('$stack');
  }

  @override
  Future<void> log(String message) async {
    debugPrint('[crash:breadcrumb] $message');
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    debugPrint('[crash] collection enabled: $enabled');
  }
}

/// A [CrashReporter] that discards everything, silently. Used by
/// tests and when the user opts out — see [TelemetryService].
class NoOpCrashReporter implements CrashReporter {
  const NoOpCrashReporter();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? context,
  }) async {}

  @override
  Future<void> log(String message) async {}

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
}
