import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chadmate/services/skincare_service.dart';

import 'test_helpers.dart';

SkincareStep _stepById(String id) =>
    SkincareService.allSteps.firstWhere((s) => s.id == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SkincareService service;

  setUp(() async {
    resetSharedPreferences();
    service = SkincareService();
    await service.load();
  });

  final cleanser = _stepById('cleanser');
  final moisturizer = _stepById('moisturizer');
  final sunscreen = _stepById('sunscreen');
  final serum = _stepById('serum');

  group('default enabled steps', () {
    test('every step is enabled except Serum, which starts optional-off', () {
      expect(service.isStepEnabled(cleanser, SkincareRoutine.morning), isTrue);
      expect(
        service.isStepEnabled(moisturizer, SkincareRoutine.morning),
        isTrue,
      );
      expect(
        service.isStepEnabled(sunscreen, SkincareRoutine.morning),
        isTrue,
      );
      expect(service.isStepEnabled(serum, SkincareRoutine.morning), isFalse);
    });

    test('sunscreen only applies to the morning routine', () {
      expect(service.stepsFor(SkincareRoutine.night), isNot(contains(sunscreen)));
      expect(service.stepsFor(SkincareRoutine.morning), contains(sunscreen));
    });

    test('default enabled counts: morning has 3, night has 2', () {
      expect(service.totalCountFor(SkincareRoutine.morning), 3);
      expect(service.totalCountFor(SkincareRoutine.night), 2);
    });
  });

  group('checking off steps', () {
    test('a step not checked off does not count toward completion', () {
      expect(
        service.isStepCompleted(cleanser, SkincareRoutine.morning),
        isFalse,
      );
    });

    test('setStepCompleted checks off a step for today by default', () async {
      await service.setStepCompleted(cleanser, SkincareRoutine.morning);

      expect(
        service.isStepCompleted(cleanser, SkincareRoutine.morning),
        isTrue,
      );
      expect(service.completedCountFor(SkincareRoutine.morning), 1);
    });

    test('toggleStep flips state and reports the new value', () async {
      final first = await service.toggleStep(cleanser, SkincareRoutine.night);
      expect(first, isTrue);

      final second = await service.toggleStep(
        cleanser,
        SkincareRoutine.night,
      );
      expect(second, isFalse);
    });

    test(
      'disabling a step also un-checks it, so it stops counting toward '
      "today's completion",
      () async {
        await service.setStepCompleted(cleanser, SkincareRoutine.morning);
        await service.setStepEnabled(cleanser, SkincareRoutine.morning, false);

        expect(
          service.isStepCompleted(cleanser, SkincareRoutine.morning),
          isFalse,
        );
        // Also no longer part of the routine's total.
        expect(service.totalCountFor(SkincareRoutine.morning), 2);
      },
    );
  });

  group('isDayComplete — requires BOTH routines fully done', () {
    Future<void> completeMorning(DateTime? date) async {
      await service.setStepCompleted(cleanser, SkincareRoutine.morning, true, date);
      await service.setStepCompleted(
        moisturizer,
        SkincareRoutine.morning,
        true,
        date,
      );
      await service.setStepCompleted(
        sunscreen,
        SkincareRoutine.morning,
        true,
        date,
      );
    }

    Future<void> completeNight(DateTime? date) async {
      await service.setStepCompleted(cleanser, SkincareRoutine.night, true, date);
      await service.setStepCompleted(
        moisturizer,
        SkincareRoutine.night,
        true,
        date,
      );
    }

    test('morning alone is not a complete day', () async {
      await completeMorning(null);
      expect(service.isDayComplete(), isFalse);
    });

    test('night alone is not a complete day', () async {
      await completeNight(null);
      expect(service.isDayComplete(), isFalse);
    });

    test('both routines fully done makes the day complete', () async {
      await completeMorning(null);
      await completeNight(null);
      expect(service.isDayComplete(), isTrue);
    });

    test(
      'missing a single enabled step in either routine keeps the day '
      'incomplete',
      () async {
        await completeMorning(null);
        // Only cleanser at night — moisturizer missing.
        await service.setStepCompleted(cleanser, SkincareRoutine.night);

        expect(service.isDayComplete(), isFalse);
      },
    );

    test(
      'disabling an optional step is not the same as completing it — '
      'a routine with zero enabled steps is never considered complete',
      () async {
        // Disable every morning step, one at a time.
        for (final step in service.stepsFor(SkincareRoutine.morning)) {
          await service.setStepEnabled(step, SkincareRoutine.morning, false);
        }
        await completeNight(null);

        expect(service.totalCountFor(SkincareRoutine.morning), 0);
        expect(service.isDayComplete(), isFalse);
      },
    );
  });

  group('daily reset across a date rollover', () {
    final day1 = DateTime(2026, 3, 10);
    final day2 = DateTime(2026, 3, 11);

    test('a step checked off on one day does not appear on another', () async {
      await service.setStepCompleted(
        cleanser,
        SkincareRoutine.morning,
        true,
        day1,
      );

      expect(
        service.isStepCompleted(cleanser, SkincareRoutine.morning, day1),
        isTrue,
      );
      expect(
        service.isStepCompleted(cleanser, SkincareRoutine.morning, day2),
        isFalse,
      );
    });

    test(
      'a fully complete day does not carry over as complete into the '
      'next day',
      () async {
        for (final step in service.stepsFor(SkincareRoutine.morning)) {
          await service.setStepCompleted(
            step,
            SkincareRoutine.morning,
            true,
            day1,
          );
        }
        for (final step in service.stepsFor(SkincareRoutine.night)) {
          await service.setStepCompleted(
            step,
            SkincareRoutine.night,
            true,
            day1,
          );
        }

        expect(service.isDayComplete(day1), isTrue);
        expect(service.isDayComplete(day2), isFalse);
      },
    );

    test('earliestCompletedDay finds the true earliest day', () async {
      final earlier = DateTime(2026, 2, 1);
      await service.setStepCompleted(
        cleanser,
        SkincareRoutine.morning,
        true,
        day1,
      );
      await service.setStepCompleted(
        cleanser,
        SkincareRoutine.morning,
        true,
        earlier,
      );

      expect(service.earliestCompletedDay, earlier);
    });
  });

  group('legacy format migration', () {
    // SkincareService's completion storage keys are private, so the
    // pre- and post-migration key names are duplicated here rather
    // than imported — same tradeoff test/widget_test.dart already
    // makes for OnboardingService's keys. If either name ever
    // changes, this needs updating too. (Enabled-step prefs are a
    // separate, unrelated key that was never part of this migration —
    // see SkincareService's class doc comment for why.)
    const legacyKey = 'skincare_completions_by_date';
    const jsonKey = 'skincare_completions_by_date_v2';

    test(
      'a legacy delimiter-encoded value is decoded and adopted on load',
      () async {
        resetSharedPreferences(
          seed: {
            legacyKey: '2026-03-01=cleanser:morning,moisturizer:morning',
          },
        );

        final migrated = SkincareService();
        await migrated.load();

        expect(
          migrated.isStepCompleted(
            cleanser,
            SkincareRoutine.morning,
            DateTime(2026, 3, 1),
          ),
          isTrue,
        );
        expect(
          migrated.isStepCompleted(
            moisturizer,
            SkincareRoutine.morning,
            DateTime(2026, 3, 1),
          ),
          isTrue,
        );
        // Not part of the seeded entry for that day.
        expect(
          migrated.isStepCompleted(
            sunscreen,
            SkincareRoutine.morning,
            DateTime(2026, 3, 1),
          ),
          isFalse,
        );
      },
    );

    test('a migrated value is written back out as JSON under the new key', () async {
      resetSharedPreferences(
        seed: {legacyKey: '2026-03-01=cleanser:morning'},
      );

      final migrated = SkincareService();
      await migrated.load();

      final prefs = SharedPreferencesAsync();
      final storedJson = await prefs.getString(jsonKey);
      expect(storedJson, isNotNull);
      expect(jsonDecode(storedJson!), {
        '2026-03-01': ['cleanser:morning'],
      });
    });

    test(
      'once migrated, data survives even if the legacy key is cleared '
      'afterward — it no longer depends on it',
      () async {
        resetSharedPreferences(
          seed: {legacyKey: '2026-03-01=cleanser:morning'},
        );
        final first = SkincareService();
        await first.load();

        final prefs = SharedPreferencesAsync();
        await prefs.remove(legacyKey);

        final second = SkincareService();
        await second.load();

        expect(
          second.isStepCompleted(
            cleanser,
            SkincareRoutine.morning,
            DateTime(2026, 3, 1),
          ),
          isTrue,
        );
      },
    );

    test(
      'an existing JSON value takes priority over a stale legacy value '
      '— migration never overwrites already-migrated data',
      () async {
        resetSharedPreferences(
          seed: {
            legacyKey: '2026-03-01=sunscreen:morning',
            jsonKey: jsonEncode({
              '2026-03-01': ['cleanser:morning'],
            }),
          },
        );

        final service = SkincareService();
        await service.load();

        expect(
          service.isStepCompleted(
            cleanser,
            SkincareRoutine.morning,
            DateTime(2026, 3, 1),
          ),
          isTrue,
        );
        expect(
          service.isStepCompleted(
            sunscreen,
            SkincareRoutine.morning,
            DateTime(2026, 3, 1),
          ),
          isFalse,
        );
      },
    );

    test(
      'a fresh install with neither key set starts with nothing completed',
      () async {
        resetSharedPreferences();

        final service = SkincareService();
        await service.load();

        expect(service.isStepCompleted(cleanser, SkincareRoutine.morning), isFalse);

        // Nothing to migrate, so no JSON value should have been
        // written for a user who never had any legacy data.
        final prefs = SharedPreferencesAsync();
        expect(await prefs.getString(jsonKey), isNull);
      },
    );
  });
}
