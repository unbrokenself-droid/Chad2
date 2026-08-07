import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:chadmate/main.dart';
import 'package:chadmate/services/analytics_service.dart';
import 'package:chadmate/services/crash_reporter.dart';
import 'package:chadmate/services/telemetry_service.dart';
import 'package:chadmate/widgets/app_bottom_navigation_bar.dart';

import 'test_helpers.dart';

/// Stands in for `tester.pumpAndSettle()` in this test. Home now
/// includes deliberately-infinite `..repeat()` animations by design —
/// the ambient background's glow/particles, and (whenever today's
/// routine isn't already complete) the Start button's pulse — none of
/// which are meant to ever stop on their own. pumpAndSettle considers
/// a tree "settled" only once no more frames are scheduled, which an
/// animation that loops forever by design can never satisfy; it would
/// just pump until it hits its own internal safety limit and throw a
/// timeout, regardless of how long that limit is set to. A handful of
/// bounded pumps gives async loads (the exercise catalog, onboarding
/// profile, routine generation) and one-shot entrance animations
/// plenty of room to finish instead, without waiting on something
/// that, now, never actually goes idle.
Future<void> pumpUntilLoaded(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  // _AppEntryPoint (main.dart) shows OnboardingFlowScreen, not
  // MainNavigationScreen, until onboarding is complete — and with a
  // genuinely empty store, it never is. This test is about bottom
  // nav behavior, not onboarding, so it seeds a completed profile
  // directly rather than clicking through five onboarding steps just
  // to reach the screen it actually wants to assert on.
  //
  // Keys and shape are OnboardingService's own private storage format
  // (see lib/services/onboarding_service.dart's _completedKey,
  // _profileKey, and OnboardingProfile._toJson) — both private to
  // that file, so they can't be imported and have to be duplicated
  // here. If either ever changes shape, this needs updating too.
  setUp(
    () => resetSharedPreferences(
      seed: {
        'onboarding_completed': true,
        'onboarding_profile': jsonEncode({
          'name': 'Alex',
          'goals': ['jawRelaxation'],
          'experienceLevel': 'beginner',
          'remindersOptedIn': <String>[],
        }),
      },
    ),
  );

  testWidgets('bottom navigation bar shows all five tabs and switches '
      'between them', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChadMateApp(
        // No-op rather than the app's DebugAnalyticsService default, so
        // navigating through five tabs doesn't spray telemetry output
        // across the test log.
        telemetryService: TelemetryService(
          analytics: const NoOpAnalyticsService(),
          crashReporter: const NoOpCrashReporter(),
        ),
      ),
    );
    // Let the initial entrance animations and the async catalog/service
    // loads settle before asserting on content — see pumpUntilLoaded's
    // own doc comment for why pumpAndSettle can't be used for this
    // anymore.
    await pumpUntilLoaded(tester);

    final navBar = find.byType(AppBottomNavigationBar);
    expect(navBar, findsOneWidget);

    const labels = ['Home', 'Exercises', 'Routine', 'Progress', 'Settings'];

    // Every destination label should appear exactly once in the nav bar.
    for (final label in labels) {
      expect(
        find.descendant(of: navBar, matching: find.text(label)),
        findsOneWidget,
      );
    }

    // Home's greeting section is shown by default.
    expect(find.textContaining('👋'), findsOneWidget);

    // Tapping each other destination should bring that tab's content to
    // the front. Each tab has a distinct large section-header title, so
    // that title appearing is used as the signal the tab switched.
    const titleForTab = {
      'Exercises': 'in your library',
      'Routine': "Today's Plan",
      'Progress': 'Consistency at a glance',
      'Settings': 'Make it yours',
    };

    for (final label in labels.skip(1)) {
      await tester.tap(
        find.descendant(of: navBar, matching: find.text(label)),
      );
      await pumpUntilLoaded(tester);

      final expectedTitle = titleForTab[label];
      if (expectedTitle != null) {
        expect(find.textContaining(expectedTitle), findsWidgets);
      }
    }
  });
}
