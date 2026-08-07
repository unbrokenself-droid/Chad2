import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'crash_reporter.dart';

/// The app's single entry point for analytics and crash reporting,
/// and the thing that decides whether either is allowed to run at
/// all.
///
/// Every telemetry call in the app goes through here rather than
/// touching an [AnalyticsService] or [CrashReporter] directly, so
/// there is exactly one place where the user's opt-out is enforced —
/// a call site that forgot to check consent isn't possible, because
/// call sites can't reach the underlying services.
///
/// **Consent model.** Both analytics and crash reporting default to
/// enabled, with a clear opt-out in Settings → Privacy. That's the
/// standard, generally-defensible position for non-advertising,
/// non-profiling telemetry, and it's what the bundled Privacy Policy
/// describes. It is *not* automatically sufficient everywhere: under
/// GDPR/ePrivacy, analytics that sets a device identifier commonly
/// requires opt-*in* consent from EU/UK users before any collection
/// starts, not merely a disclosed opt-out. If ChadMate ships to those
/// markets with a real provider active, expect to need a consent
/// prompt on first launch that defaults to off — [setAnalyticsEnabled]
/// and [setCrashReportingEnabled] are already the right hooks for
/// that, so it's a UI change rather than a re-architecture. Flagging
/// rather than deciding: which markets this ships to, and what legal
/// advice applies, isn't something the code can settle.
class TelemetryService extends ChangeNotifier {
  TelemetryService({
    AnalyticsService? analytics,
    CrashReporter? crashReporter,
    SharedPreferencesAsync? preferences,
  }) : _analytics = analytics ?? DebugAnalyticsService(),
       _crashReporter = crashReporter ?? DebugCrashReporter(),
       _preferences = preferences ?? SharedPreferencesAsync();

  static const String _analyticsKey = 'telemetry_analytics_enabled';
  static const String _crashReportingKey = 'telemetry_crash_enabled';

  /// Both default on — see the consent discussion in this class's doc
  /// comment before changing these, since the bundled Privacy Policy
  /// text describes exactly this behavior and would need updating
  /// alongside.
  static const bool defaultAnalyticsEnabled = true;
  static const bool defaultCrashReportingEnabled = true;

  final AnalyticsService _analytics;
  final CrashReporter _crashReporter;
  final SharedPreferencesAsync _preferences;

  bool _analyticsEnabled = defaultAnalyticsEnabled;
  bool _crashReportingEnabled = defaultCrashReportingEnabled;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get analyticsEnabled => _analyticsEnabled;
  bool get crashReportingEnabled => _crashReportingEnabled;

  /// Loads the stored preferences and initializes whichever providers
  /// are currently enabled. Safe to call more than once.
  Future<void> load() async {
    _analyticsEnabled =
        await _preferences.getBool(_analyticsKey) ?? defaultAnalyticsEnabled;
    _crashReportingEnabled =
        await _preferences.getBool(_crashReportingKey) ??
        defaultCrashReportingEnabled;
    _loaded = true;
    notifyListeners();

    await _analytics.initialize();
    await _crashReporter.initialize();
    // Push the loaded state down to the providers so their own
    // background collection matches the user's choice, not just the
    // explicit calls this app makes.
    await _analytics.setCollectionEnabled(_analyticsEnabled);
    await _crashReporter.setCollectionEnabled(_crashReportingEnabled);
  }

  Future<void> setAnalyticsEnabled(bool value) async {
    if (value == _analyticsEnabled) return;
    _analyticsEnabled = value;
    notifyListeners();
    await _preferences.setBool(_analyticsKey, value);
    await _analytics.setCollectionEnabled(value);
  }

  Future<void> setCrashReportingEnabled(bool value) async {
    if (value == _crashReportingEnabled) return;
    _crashReportingEnabled = value;
    notifyListeners();
    await _preferences.setBool(_crashReportingKey, value);
    await _crashReporter.setCollectionEnabled(value);
  }

  /// Logs [event], if analytics is enabled.
  ///
  /// Deliberately fire-and-forget and failure-swallowing: telemetry
  /// is never important enough to break a user-facing flow, so a
  /// provider being down, rate-limited, or misconfigured must not
  /// turn into a visible error in the middle of someone's exercise
  /// session.
  Future<void> logEvent(AnalyticsEvent event) async {
    if (!_analyticsEnabled) return;
    try {
      await _analytics.logEvent(event);
    } catch (error, stack) {
      debugPrint('TelemetryService: failed to log ${event.name}: $error');
      // Not reported through _crashReporter — a telemetry failure
      // reporting itself as a crash is a good way to turn one broken
      // provider into a flood.
      assert(() {
        debugPrintStack(stackTrace: stack);
        return true;
      }());
    }
  }

  Future<void> logScreenView(String screenName) async {
    if (!_analyticsEnabled) return;
    try {
      await _analytics.logScreenView(screenName);
    } catch (error) {
      debugPrint('TelemetryService: failed to log screen view: $error');
    }
  }

  /// Records an error, if crash reporting is enabled. Gated
  /// separately from analytics because they're genuinely different
  /// tradeoffs — someone may reasonably want to help fix crashes
  /// without contributing usage data.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? context,
  }) async {
    if (!_crashReportingEnabled) return;
    try {
      await _crashReporter.recordError(
        error,
        stack,
        fatal: fatal,
        context: context,
      );
    } catch (reportingError) {
      debugPrint('TelemetryService: failed to record error: $reportingError');
    }
  }

  Future<void> logBreadcrumb(String message) async {
    if (!_crashReportingEnabled) return;
    try {
      await _crashReporter.log(message);
    } catch (_) {
      // Breadcrumbs are the least important telemetry there is;
      // failing to record one is not worth any noise.
    }
  }
}
