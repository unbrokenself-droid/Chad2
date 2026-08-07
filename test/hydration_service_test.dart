import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chadmate/services/hydration_service.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HydrationService service;

  setUp(() async {
    resetSharedPreferences();
    service = HydrationService();
    await service.load();
  });

  group('defaults', () {
    test('starts at the default goal with zero intake', () {
      expect(service.goalMl, HydrationService.defaultGoalMl);
      expect(service.todayIntakeMl, 0);
      expect(service.todayProgress, 0.0);
      expect(service.goalReachedToday, isFalse);
    });
  });

  group('logging intake', () {
    test('addIntake accumulates across multiple calls', () async {
      await service.addIntake(250);
      await service.addIntake(250);
      await service.addIntake(100);

      expect(service.todayIntakeMl, 600);
    });

    test('todayProgress reflects intake as a fraction of the goal', () async {
      await service.setGoal(1000);
      await service.addIntake(250);

      expect(service.todayProgress, closeTo(0.25, 0.0001));
    });

    test('todayProgress clamps at 1.0 even past the goal', () async {
      await service.setGoal(500);
      await service.addIntake(900);

      expect(service.todayProgress, 1.0);
    });

    test('goalReachedToday flips exactly at the goal, not before', () async {
      await service.setGoal(500);
      await service.addIntake(499);
      expect(service.goalReachedToday, isFalse);

      await service.addIntake(1);
      expect(service.goalReachedToday, isTrue);
    });

    test('resetIntake zeroes today only', () async {
      await service.addIntake(500);
      await service.resetIntake();

      expect(service.todayIntakeMl, 0);
    });
  });

  group('setGoal', () {
    test('updates goalMl and is reflected in progress immediately', () async {
      await service.setGoal(3000);
      expect(service.goalMl, 3000);
    });

    test('clamps unreasonably small goals up to 250ml', () async {
      await service.setGoal(50);
      expect(service.goalMl, 250);
    });
  });

  group('daily reset across a date rollover', () {
    final day1 = DateTime(2026, 3, 10);
    final day2 = DateTime(2026, 3, 11);

    test('intake logged for one day does not appear on another', () async {
      await service.addIntake(500, day1);

      expect(service.intakeOn(day1), 500);
      expect(service.intakeOn(day2), 0);
    });

    test(
      'goalReachedOn is evaluated per day — hitting the goal yesterday '
      "does not carry over as 'reached' for a fresh day",
      () async {
        await service.setGoal(500);
        await service.addIntake(500, day1);

        expect(service.goalReachedOn(day1), isTrue);
        expect(service.goalReachedOn(day2), isFalse);
      },
    );

    test('each day accumulates independently', () async {
      await service.addIntake(200, day1);
      await service.addIntake(300, day1);
      await service.addIntake(400, day2);

      expect(service.intakeOn(day1), 500);
      expect(service.intakeOn(day2), 400);
    });

    test('two different times on the same calendar day share one total', () async {
      final morning = DateTime(2026, 3, 10, 7, 0);
      final evening = DateTime(2026, 3, 10, 21, 0);
      await service.addIntake(250, morning);
      await service.addIntake(250, evening);

      expect(service.intakeOn(day1), 500);
    });

    test('resetIntake only clears the specified day', () async {
      await service.addIntake(500, day1);
      await service.addIntake(400, day2);

      await service.resetIntake(day1);

      expect(service.intakeOn(day1), 0);
      expect(service.intakeOn(day2), 400);
    });

    test('earliestLoggedDay finds the true earliest day', () async {
      final earlier = DateTime(2026, 2, 1);
      await service.addIntake(250, day1);
      await service.addIntake(250, earlier);

      expect(service.earliestLoggedDay, earlier);
    });

    test('earliestLoggedDay is null when nothing has ever been logged', () {
      expect(service.earliestLoggedDay, isNull);
    });
  });

  group('legacy format migration', () {
    // HydrationService's storage keys are private, so the pre- and
    // post-migration key names are duplicated here rather than
    // imported — same tradeoff test/widget_test.dart already makes
    // for OnboardingService's keys. If either name ever changes, this
    // needs updating too.
    const legacyKey = 'hydration_intake_by_date';
    const jsonKey = 'hydration_intake_by_date_v2';

    test(
      'a legacy delimiter-encoded value is decoded and adopted on load',
      () async {
        resetSharedPreferences(
          seed: {legacyKey: '2026-03-01:500;2026-03-02:750'},
        );

        final migrated = HydrationService();
        await migrated.load();

        expect(migrated.intakeOn(DateTime(2026, 3, 1)), 500);
        expect(migrated.intakeOn(DateTime(2026, 3, 2)), 750);
      },
    );

    test('a migrated value is written back out as JSON under the new key', () async {
      resetSharedPreferences(seed: {legacyKey: '2026-03-01:500'});

      final migrated = HydrationService();
      await migrated.load();

      final prefs = SharedPreferencesAsync();
      final storedJson = await prefs.getString(jsonKey);
      expect(storedJson, isNotNull);
      expect(jsonDecode(storedJson!), {'2026-03-01': 500});
    });

    test(
      'once migrated, data survives even if the legacy key is cleared '
      'afterward — it no longer depends on it',
      () async {
        resetSharedPreferences(seed: {legacyKey: '2026-03-01:500'});
        final first = HydrationService();
        await first.load();

        final prefs = SharedPreferencesAsync();
        await prefs.remove(legacyKey);

        final second = HydrationService();
        await second.load();

        expect(second.intakeOn(DateTime(2026, 3, 1)), 500);
      },
    );

    test(
      'an existing JSON value takes priority over a stale legacy value '
      '— migration never overwrites already-migrated data',
      () async {
        resetSharedPreferences(
          seed: {
            legacyKey: '2026-03-01:999',
            jsonKey: jsonEncode({'2026-03-01': 500}),
          },
        );

        final service = HydrationService();
        await service.load();

        expect(service.intakeOn(DateTime(2026, 3, 1)), 500);
      },
    );

    test('a fresh install with neither key set starts with zero intake', () async {
      resetSharedPreferences();

      final service = HydrationService();
      await service.load();

      expect(service.todayIntakeMl, 0);

      // Nothing to migrate, so no JSON value should have been written
      // for a user who never had any legacy data to begin with.
      final prefs = SharedPreferencesAsync();
      expect(await prefs.getString(jsonKey), isNull);
    });
  });
}
