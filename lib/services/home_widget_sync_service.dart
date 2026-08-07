import 'package:home_widget/home_widget.dart';

import 'hydration_service.dart';
import 'skincare_service.dart';

/// Keeps the two Android home-screen widgets (hydration and skincare
/// check-in) in sync with [HydrationService]/[SkincareService], and
/// folds back in anything logged from a widget tap while the app
/// wasn't open.
///
/// **Why a tap doesn't call straight into [HydrationService]/
/// [SkincareService]:** a home-screen widget can be tapped while the
/// Flutter engine isn't running at all. `home_widget` does offer a
/// background-callback mechanism that can start a headless engine to
/// handle a tap directly in Dart, but that's a genuinely separate
/// code path with its own failure modes — this first version doesn't
/// take it on. Instead, `HydrationWidgetProvider.kt` /
/// `SkincareWidgetProvider.kt` handle a tap entirely natively:
/// incrementing a small "pending" counter directly in the same
/// SharedPreferences file `home_widget` already uses, and redrawing
/// immediately so the *widget itself* stays responsive with no Dart
/// involved yet. This service is the other half — the one place that
/// actually calls [HydrationService.addIntake] /
/// [SkincareService.toggleStep] for something logged via a widget, so
/// there's still exactly one path into that real data, not two.
///
/// **When reconciliation happens:** [reconcilePendingWidgetTaps] is
/// meant to run once, near app startup (see `main.dart`), the same as
/// this app's other one-time load steps. That means a widget tap
/// catches up with the real app data the next time the app is
/// opened, not the instant it's tapped.
///
/// **Why the widgets stay fresh in between app opens, but only up to
/// a point:** [pushHydrationData]/[pushSkincareData] are also called
/// from `main.dart` every time [HydrationService]/[SkincareService]
/// notify a change, so anything logged *in the app* reaches the
/// widget right away. Android's own background-update budget (the
/// `updatePeriodMillis` safety-net in each widget's `_widget_info.xml`
/// tops out at roughly 30 minutes) is what a change would otherwise
/// have to wait on without this.
class HomeWidgetSyncService {
  HomeWidgetSyncService({
    required HydrationService hydration,
    required SkincareService skincare,
  }) : _hydration = hydration,
       _skincare = skincare;

  final HydrationService _hydration;
  final SkincareService _skincare;

  /// Matches HydrationWidgetProvider.kt's manifest-declared name
  /// exactly (no package prefix — `home_widget` resolves that itself
  /// from the app's own applicationId).
  static const String _hydrationProviderName = 'HydrationWidgetProvider';

  /// Matches SkincareWidgetProvider.kt's manifest-declared name.
  static const String _skincareProviderName = 'SkincareWidgetProvider';

  // Keys this service writes; HydrationWidgetProvider.kt reads them
  // (and never writes them).
  static const String _hydrationTotalGlassesKey =
      'hydration_widget_total_glasses';
  static const String _hydrationFilledGlassesKey =
      'hydration_widget_filled_glasses';

  // Keys this service writes; SkincareWidgetProvider.kt reads them
  // (and never writes them).
  static const String _skincareRoutineLabelKey =
      'skincare_widget_routine_label';
  static const String _skincareTotalStepsKey = 'skincare_widget_total_steps';
  static const String _skincareCompletedStepsKey =
      'skincare_widget_completed_steps';

  // Keys the native widgets write (HydrationWidgetProvider.kt's
  // ACTION_ADD_GLASS / SkincareWidgetProvider.kt's ACTION_CHECK_STEP
  // handlers); this service reads them once, then resets them to 0.
  static const String _hydrationPendingGlassesKey =
      'hydration_widget_pending_glasses';
  static const String _skincarePendingStepsKey =
      'skincare_widget_pending_steps';

  /// Same "one glass" amount [HydrationCheckInCard] uses, so a glass
  /// logged from the widget adds exactly the amount a glass logged
  /// in-app would.
  int get _glassSizeMl => _hydration.quickAddAmountsMl[1];

  /// Applies any hydration/skincare progress logged from a widget tap
  /// while the app wasn't open, then refreshes both widgets with
  /// fresh data either way — so even a first launch, with nothing
  /// pending yet, still gets the widgets showing real data instead of
  /// their placeholder defaults.
  ///
  /// Safe to call more than once; a second call with nothing new
  /// pending just re-pushes the same (already-correct) data.
  Future<void> reconcilePendingWidgetTaps() async {
    final pendingGlasses =
        await HomeWidget.getWidgetData<int>(_hydrationPendingGlassesKey) ?? 0;
    if (pendingGlasses > 0) {
      await _hydration.addIntake(pendingGlasses * _glassSizeMl);
      await HomeWidget.saveWidgetData<int>(_hydrationPendingGlassesKey, 0);
    }

    final pendingSteps =
        await HomeWidget.getWidgetData<int>(_skincarePendingStepsKey) ?? 0;
    if (pendingSteps > 0) {
      final routine = _skincare.routineNeedingAttention;
      final incompleteSteps = _skincare
          .enabledStepsFor(routine)
          .where((step) => !_skincare.isStepCompleted(step, routine))
          .take(pendingSteps);
      for (final step in incompleteSteps) {
        await _skincare.toggleStep(step, routine);
      }
      await HomeWidget.saveWidgetData<int>(_skincarePendingStepsKey, 0);
    }

    await pushHydrationData();
    await pushSkincareData();
  }

  /// Writes [HydrationService]'s current progress to the same storage
  /// `HydrationWidgetProvider.kt` reads, then asks Android to redraw
  /// it. Called once during reconciliation and again every time
  /// [HydrationService] changes (see `main.dart`'s listener), so the
  /// widget reflects anything logged in-app too, not only its own
  /// taps.
  Future<void> pushHydrationData() async {
    final glassSize = _glassSizeMl;
    final total = (_hydration.goalMl / glassSize).ceil().clamp(1, 12);
    final filled = (_hydration.todayIntakeMl / glassSize).round().clamp(
      0,
      total,
    );
    await HomeWidget.saveWidgetData<int>(_hydrationTotalGlassesKey, total);
    await HomeWidget.saveWidgetData<int>(_hydrationFilledGlassesKey, filled);
    await HomeWidget.updateWidget(androidName: _hydrationProviderName);
  }

  /// Writes [SkincareService]'s current progress to the same storage
  /// `SkincareWidgetProvider.kt` reads, then asks Android to redraw
  /// it. See [pushHydrationData]'s doc comment — same triggers.
  Future<void> pushSkincareData() async {
    final routine = _skincare.routineNeedingAttention;
    final total = _skincare.totalCountFor(routine);
    final completed = _skincare.completedCountFor(routine);
    await HomeWidget.saveWidgetData<String>(
      _skincareRoutineLabelKey,
      routine == SkincareRoutine.morning ? 'Morning' : 'Night',
    );
    await HomeWidget.saveWidgetData<int>(_skincareTotalStepsKey, total);
    await HomeWidget.saveWidgetData<int>(
      _skincareCompletedStepsKey,
      completed,
    );
    await HomeWidget.updateWidget(androidName: _skincareProviderName);
  }
}
