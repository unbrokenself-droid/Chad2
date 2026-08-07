import 'package:flutter_test/flutter_test.dart';

import 'package:chadmate/services/analytics_service.dart';
import 'package:chadmate/services/crash_reporter.dart';
import 'package:chadmate/services/telemetry_service.dart';

import 'test_helpers.dart';

/// Records what it was asked to send, so tests can assert on whether
/// the opt-out gate actually blocked anything — the one property of
/// this layer that genuinely matters and can't be checked by reading
/// the code alone.
class _RecordingAnalytics implements AnalyticsService {
  final List<AnalyticsEvent> events = [];
  final List<String> screens = [];
  bool? collectionEnabled;
  var initialized = false;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<void> logEvent(AnalyticsEvent event) async => events.add(event);

  @override
  Future<void> logScreenView(String screenName) async =>
      screens.add(screenName);

  @override
  Future<void> setCollectionEnabled(bool enabled) async =>
      collectionEnabled = enabled;
}

class _RecordingCrashReporter implements CrashReporter {
  final List<Object> errors = [];
  bool? collectionEnabled;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? context,
  }) async => errors.add(error);

  @override
  Future<void> log(String message) async {}

  @override
  Future<void> setCollectionEnabled(bool enabled) async =>
      collectionEnabled = enabled;
}

/// An analytics sink that always throws, to verify a broken provider
/// can't take a user-facing flow down with it.
class _ThrowingAnalytics implements AnalyticsService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> logEvent(AnalyticsEvent event) async =>
      throw StateError('provider is down');

  @override
  Future<void> logScreenView(String screenName) async =>
      throw StateError('provider is down');

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingAnalytics analytics;
  late _RecordingCrashReporter crashReporter;
  late TelemetryService telemetry;

  setUp(() async {
    resetSharedPreferences();
    analytics = _RecordingAnalytics();
    crashReporter = _RecordingCrashReporter();
    telemetry = TelemetryService(
      analytics: analytics,
      crashReporter: crashReporter,
    );
    await telemetry.load();
    // Known baseline regardless of what a previous test left in
    // shared_preferences.
    await telemetry.setAnalyticsEnabled(true);
    await telemetry.setCrashReportingEnabled(true);
  });

  group('TelemetryService gating', () {
    test('forwards events while analytics is enabled', () async {
      await telemetry.logEvent(
        AnalyticsEvent.paywallViewed(source: 'settings_row'),
      );

      expect(analytics.events, hasLength(1));
      expect(analytics.events.single.name, 'paywall_viewed');
      expect(analytics.events.single.parameters['source'], 'settings_row');
    });

    test('drops events once analytics is disabled', () async {
      await telemetry.setAnalyticsEnabled(false);

      await telemetry.logEvent(
        AnalyticsEvent.paywallViewed(source: 'settings_row'),
      );
      await telemetry.logScreenView('Settings');

      expect(analytics.events, isEmpty);
      expect(analytics.screens, isEmpty);
    });

    test('tells the provider to stop collecting, not just stop calling '
        'it', () async {
      await telemetry.setAnalyticsEnabled(false);

      // The distinction matters: a provider SDK gathers session and
      // device data on its own without any explicit log call, so
      // merely skipping our own calls would leave an opted-out user
      // still being collected from.
      expect(analytics.collectionEnabled, isFalse);
    });

    test('gates crash reporting separately from analytics', () async {
      await telemetry.setAnalyticsEnabled(false);

      await telemetry.recordError(StateError('boom'), StackTrace.current);

      expect(
        crashReporter.errors,
        hasLength(1),
        reason: 'disabling analytics should not disable crash reporting',
      );
    });

    test('drops errors once crash reporting is disabled', () async {
      await telemetry.setCrashReportingEnabled(false);

      await telemetry.recordError(StateError('boom'), StackTrace.current);

      expect(crashReporter.errors, isEmpty);
      expect(crashReporter.collectionEnabled, isFalse);
    });

    test('a failing provider never throws into the caller', () async {
      final resilient = TelemetryService(
        analytics: _ThrowingAnalytics(),
        crashReporter: crashReporter,
      );
      await resilient.load();
      await resilient.setAnalyticsEnabled(true);

      // The assertion is that these complete at all — telemetry must
      // never be able to break the flow that fired it.
      await expectLater(
        resilient.logEvent(
          AnalyticsEvent.routineSessionStarted(
            exerciseCategory: 'jaw',
            difficulty: 'beginner',
          ),
        ),
        completes,
      );
      await expectLater(resilient.logScreenView('Home'), completes);
    });
  });

  group('AnalyticsEvent', () {
    test('event names are Firebase-compatible', () {
      final events = [
        AnalyticsEvent.onboardingCompleted(
          goalCount: 2,
          experienceLevel: 'beginner',
          anyReminderEnabled: true,
        ),
        AnalyticsEvent.routineSessionStarted(
          exerciseCategory: 'jaw',
          difficulty: 'beginner',
        ),
        AnalyticsEvent.routineSessionFinished(
          exerciseCategory: 'jaw',
          completed: true,
          elapsedSeconds: 45,
        ),
        AnalyticsEvent.paywallViewed(source: 'settings_row'),
        AnalyticsEvent.purchaseStarted(productId: 'premium_yearly'),
        AnalyticsEvent.purchaseCompleted(
          productId: 'premium_yearly',
          productKind: 'yearlySubscription',
        ),
        AnalyticsEvent.purchaseFailed(
          productId: 'premium_yearly',
          reason: 'cancelled',
        ),
        AnalyticsEvent.reminderToggled(kind: 'hydration', enabled: true),
      ];

      for (final event in events) {
        expect(
          event.name.length,
          lessThanOrEqualTo(40),
          reason: '${event.name} exceeds Firebase\'s 40-char event name limit',
        );
        expect(
          RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(event.name),
          isTrue,
          reason: '${event.name} is not a valid Firebase event name',
        );
        for (final key in event.parameters.keys) {
          expect(
            RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(key),
            isTrue,
            reason: '$key is not a valid Firebase parameter name',
          );
        }
      }
    });
  });
}
