import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding/onboarding_flow_screen.dart';
import 'services/accessibility_scope.dart';
import 'services/accessibility_service.dart';
import 'services/ads_manager.dart';
import 'services/ads_scope.dart';
import 'services/background_music_scope.dart';
import 'services/background_music_service.dart';
import 'services/badge_scope.dart';
import 'services/badge_service.dart';
import 'services/breathing_settings_scope.dart';
import 'services/breathing_settings_service.dart';
import 'services/completion_scope.dart';
import 'services/custom_routines_scope.dart';
import 'services/custom_routines_service.dart';
import 'services/daily_routine_scope.dart';
import 'services/daily_routine_service.dart';
import 'services/exercise_completion_service.dart';
import 'services/exercise_narrator.dart';
import 'services/exercise_narrator_scope.dart';
import 'services/favorites_scope.dart';
import 'services/favorites_service.dart';
import 'services/home_widget_sync_service.dart';
import 'services/hydration_scope.dart';
import 'services/hydration_service.dart';
import 'services/library_bookmarks_scope.dart';
import 'services/library_bookmarks_service.dart';
import 'services/narration_settings_scope.dart';
import 'services/narration_settings_service.dart';
import 'services/navigation_tab_controller.dart';
import 'services/navigation_tab_scope.dart';
import 'services/onboarding_scope.dart';
import 'services/onboarding_service.dart';
import 'services/premium_scope.dart';
import 'services/premium_service.dart';
import 'services/reminder_settings_scope.dart';
import 'services/reminder_settings_service.dart';
import 'services/rest_day_scope.dart';
import 'services/rest_day_service.dart';
import 'services/skincare_scope.dart';
import 'services/skincare_service.dart';
import 'services/streak_scope.dart';
import 'services/streak_service.dart';
import 'services/telemetry_scope.dart';
import 'services/telemetry_service.dart';
import 'services/theme_mode_scope.dart';
import 'services/theme_mode_service.dart';
import 'services/tts_exercise_narrator.dart';
import 'services/wellness_score_scope.dart';
import 'services/wellness_score_service.dart';
import 'services/workout_unlock_scope.dart';
import 'services/workout_unlock_service.dart';

/// The single [TelemetryService] the app uses, created before
/// [runApp] so the error handlers below can reach it.
///
/// A top-level rather than a field on [ChadMateApp] specifically
/// because [FlutterError.onError] and [PlatformDispatcher.onError]
/// are global hooks that fire outside any widget's lifetime,
/// including for errors thrown before the first frame — a scoped
/// instance would be unreachable exactly when it matters most. It's
/// also handed to [ChadMateApp] so the widget tree reaches the same
/// instance through [TelemetryScope], rather than a second one with
/// its own separate consent state.
final TelemetryService _telemetryService = TelemetryService();

void main() {
  // runZonedGuarded catches async errors that escape the Flutter
  // framework's own handling — the ones that otherwise vanish
  // entirely in release builds.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Loaded before runApp so an opted-out user's preference is
      // already in effect for the very first events, rather than
      // collection starting and then being switched off a moment
      // later.
      await _telemetryService.load();

      // Framework-level errors (build/layout/paint failures).
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        previousOnError?.call(details);
        _telemetryService.recordError(
          details.exception,
          details.stack,
          fatal: true,
          context: details.context?.toString(),
        );
      };

      // Errors from the platform side that never reach the framework.
      PlatformDispatcher.instance.onError = (error, stack) {
        _telemetryService.recordError(error, stack, fatal: true);
        // false = "not fully handled", so the platform still applies
        // its own default behavior rather than this silently
        // swallowing the error.
        return false;
      };

      runApp(ChadMateApp(telemetryService: _telemetryService));
    },
    (error, stack) {
      _telemetryService.recordError(error, stack, fatal: true);
    },
  );
}

/// Root widget for the ChadMate app.
///
/// Wires up the Material 3 theme and the five-tab navigation shell.
/// Also owns the single, app-wide [FavoritesService],
/// [ExerciseCompletionService], [DailyRoutineService],
/// [CustomRoutinesService], [HydrationService], [SkincareService],
/// [StreakService], [ReminderSettingsService], [WellnessScoreService],
/// [BadgeService], [ThemeModeService], [BreathingSettingsService],
/// [NarrationSettingsService], and [ExerciseNarrator] instances and
/// makes them available to every screen via [FavoritesScope],
/// [CompletionScope], [DailyRoutineScope], [CustomRoutinesScope],
/// [HydrationScope], [SkincareScope], [StreakScope],
/// [ReminderSettingsScope], [WellnessScoreScope], [BadgeScope],
/// [ThemeModeScope], [BreathingSettingsScope],
/// [NarrationSettingsScope], and [ExerciseNarratorScope], loading
/// persisted favorites, completion history, today's routine, custom
/// routines, hydration, skincare, reminder, badge-unlock,
/// appearance-mode, guided-breathing, and narration-preference data
/// from disk as soon as the app starts.
/// [StreakService] and [WellnessScoreService]
/// need no load step of their own — both are derived on demand from
/// the other services' already-loaded data. [BadgeService] does load
/// its own state (which badges are unlocked), but derives every
/// badge's live progress the same read-through way. The concrete
/// [ExerciseNarrator] published via [ExerciseNarratorScope] is a
/// [TtsExerciseNarrator] today — this is the one place that knows
/// that; see [ExerciseNarrator]'s own doc comment for why nothing
/// else in the app does, or needs to.
///
/// The resolved [ThemeData] — light, dark, AMOLED black, or whichever
/// of light/dark the OS is currently set to for "System Default" — is
/// computed in [build] from [ThemeModeService.mode] and wrapped in an
/// [AnimatedTheme] via [MaterialApp.builder], so switching appearance
/// mode in Settings cross-fades every color on screen rather than
/// snapping instantly.
///
/// Also owns the single [NavigationTabController], made available via
/// [NavigationTabScope] — unlike the services above, this holds no
/// persisted preference; it's what lets a screen nested inside one
/// tab switch the bottom navigation bar to another tab directly (see
/// [MainNavigationScreen]).
///
/// Also owns [HomeWidgetSyncService], which isn't published via any
/// scope — nothing reads state from it directly, it just keeps the
/// two Android home-screen widgets (hydration and skincare check-in)
/// synced with [_hydrationService]/[_skincareService] in the
/// background. See that class's own doc comment for the full flow.
///
/// [telemetryService] is the one service this widget does *not*
/// construct itself: [main] creates it first so the global error
/// handlers can reach it before the widget tree exists, then passes
/// the same instance in here to be published via [TelemetryScope].
class ChadMateApp extends StatefulWidget {
  const ChadMateApp({super.key, required this.telemetryService});

  final TelemetryService telemetryService;

  @override
  State<ChadMateApp> createState() => _ChadMateAppState();
}

class _ChadMateAppState extends State<ChadMateApp> {
  final FavoritesService _favoritesService = FavoritesService();
  final ExerciseCompletionService _completionService =
      ExerciseCompletionService();
  final DailyRoutineService _dailyRoutineService = DailyRoutineService();
  final CustomRoutinesService _customRoutinesService = CustomRoutinesService();
  final HydrationService _hydrationService = HydrationService();
  final SkincareService _skincareService = SkincareService();
  // Bridges the two above to the Android home-screen widgets — see
  // its own doc comment for the full sync flow. Declared `late final`
  // since it needs _hydrationService/_skincareService, which are
  // themselves declared just above; Dart's field-initializer order
  // (top to bottom) guarantees those are already set by the time this
  // one's lazily evaluated.
  late final HomeWidgetSyncService _homeWidgetSyncService =
      HomeWidgetSyncService(
        hydration: _hydrationService,
        skincare: _skincareService,
      );
  final LibraryBookmarksService _libraryBookmarksService =
      LibraryBookmarksService();
  final RestDayService _restDayService = RestDayService();
  // Telemetry is injected here rather than the reminder toggle being
  // instrumented at its UI call sites, because reminders can be
  // enabled from three different places (onboarding, the Home
  // reminder sheet, Settings) and instrumenting the service catches
  // all of them without depending on every future call site
  // remembering to.
  late final ReminderSettingsService _reminderSettingsService =
      ReminderSettingsService(telemetry: widget.telemetryService);
  final OnboardingService _onboardingService = OnboardingService();
  final ThemeModeService _themeModeService = ThemeModeService();
  final PremiumService _premiumService = PremiumService();
  late final AdsManager _adsManager = AdsManager(premium: _premiumService);
  final WorkoutUnlockService _workoutUnlockService = WorkoutUnlockService();
  final AccessibilityService _accessibilityService = AccessibilityService();
  final BreathingSettingsService _breathingSettingsService =
      BreathingSettingsService();
  final NarrationSettingsService _narrationSettingsService =
      NarrationSettingsService();
  late final ExerciseNarrator _exerciseNarrator = TtsExerciseNarrator(
    settings: _narrationSettingsService,
  );
  final BackgroundMusicService _backgroundMusicService =
      BackgroundMusicService();
  final NavigationTabController _navigationTabController =
      NavigationTabController();
  late final StreakService _streakService;
  late final WellnessScoreService _wellnessScoreService;
  late final BadgeService _badgeService;

  @override
  void initState() {
    super.initState();
    // Built (not just declared) here, once the other three services
    // it reads from already exist, so it can start listening to them
    // right away. It has nothing of its own to load from disk — every
    // streak is derived on demand from those services' already-loaded
    // history — so there's no corresponding `.load()` call below.
    _streakService = StreakService(
      completion: _completionService,
      hydration: _hydrationService,
      skincare: _skincareService,
      restDays: _restDayService,
    );
    // Same pattern as _streakService: a pure read-through layer over
    // exercise, hydration, skincare, and reminder state, so it has
    // nothing of its own to load either.
    _wellnessScoreService = WellnessScoreService(
      exercise: _completionService,
      hydration: _hydrationService,
      skincare: _skincareService,
      reminders: _reminderSettingsService,
    );
    // Built after _streakService, since badge progress for streak-based
    // achievements (7-Day Streak, Hydration Hero, Consistent Skincare)
    // reads through it. Unlike the two services above, this one does
    // have its own persisted state — which badges have been earned —
    // so it needs a `.load()` call below.
    _badgeService = BadgeService(
      exercise: _completionService,
      hydration: _hydrationService,
      skincare: _skincareService,
      streak: _streakService,
      reminders: _reminderSettingsService,
    );
    // Fire-and-forget: screens read completion/favorite/routine state
    // synchronously and simply see "nothing yet" for everything until
    // these resolve (usually well before the user reaches a screen
    // that needs them), then rebuild via the scopes once real data
    // loads. The daily routine itself isn't generated here — that
    // needs the exercise catalog, which the Routine screen loads and
    // passes to `ensureTodayRoutine` — this just restores whatever was
    // already generated earlier today, if anything.
    _favoritesService.load();
    _completionService.load();
    _dailyRoutineService.load();
    _customRoutinesService.load();
    _hydrationService.load();
    _skincareService.load();
    // Keeps the Android home-screen widgets showing fresh data
    // whenever either service changes from *inside* the app (a tap
    // on HydrationCheckInCard/SkincareCheckInCard, the full sheets,
    // etc.) — separate from _syncHomeWidgets below, which is what
    // catches up on anything logged from the widgets themselves.
    _hydrationService.addListener(_homeWidgetSyncService.pushHydrationData);
    _skincareService.addListener(_homeWidgetSyncService.pushSkincareData);
    _syncHomeWidgets();
    _restDayService.load();
    // Restores which Wellness Library articles were bookmarked in
    // previous sessions. All library content itself is bundled with
    // the app (see WellnessLibraryContent), so only bookmark state
    // needs to be loaded here.
    _libraryBookmarksService.load();
    // Also re-arms every enabled reminder's OS-level notification
    // schedule and in-app history ticker from last session.
    _reminderSettingsService.load();
    // Restores which badges were already unlocked in previous
    // sessions. Depends on the services above only for live progress
    // computation (already wired above), not for this load step.
    _badgeService.load();
    // Determines whether the onboarding flow or the main app shell is
    // shown first — see `home:` below, which reads
    // `_onboardingService.hasCompletedOnboarding` once this resolves.
    _onboardingService.load();
    // Restores the user's chosen appearance mode (light/dark/AMOLED/
    // system). Until this resolves, [_AnimatedAppTheme] falls back to
    // [ThemeModeService.defaultMode] (System Default) — in practice
    // this is a single fast local read, so there's no visible flash
    // of the wrong theme on startup.
    _themeModeService.load();
    // Restores text scale, high contrast, reduce motion, and touch
    // target preferences from last session. Until this resolves,
    // every reader below falls back to standard/off values, which
    // matches the app's previous fixed behavior.
    _accessibilityService.load();
    // Restores whether the user is on Free or Premium. Until this
    // resolves, every `PremiumService.isUnlocked` check falls back to
    // Free (locked), matching a new install's default tier.
    _premiumService.load();
    // Starts the Mobile Ads SDK and preloads the rewarded/interstitial
    // ads. Fired before _premiumService.load() above is guaranteed to
    // have resolved, deliberately: AdsManager's own Premium listener
    // (see its class doc comment) disposes anything it started
    // loading the moment that resolves to an actual Premium
    // entitlement, so this doesn't need to wait its turn — it just
    // self-corrects a beat later for the (uncommon) case where it
    // guessed wrong.
    _adsManager.initialize();
    // Restores which featured collections have been unlocked on this
    // device via a rewarded ad. Until this resolves, every
    // WorkoutUnlockService.isUnlocked check reports false — the same
    // "not yet unlocked" state as any collection that's never been
    // unlocked at all, so nothing looks broken in that brief window.
    _workoutUnlockService.load();
    // Restores the guided-breathing vibration-cue preference and the
    // last pattern/duration chosen, so the breathing hub can
    // pre-select them.
    _breathingSettingsService.load();
    // Restores the user's chosen speech rate, pitch, and volume for
    // exercise narration. Until this resolves, TtsExerciseNarrator
    // falls back to NarrationSettingsService's defaults — a normal,
    // unhurried reading pace rather than anything jarring.
    _narrationSettingsService.load();
    // Restores whether background music is enabled, its volume, and
    // which track was last selected. Until this resolves,
    // BackgroundMusicService falls back to its own defaults (enabled,
    // moderate volume, the first bundled track) — the same
    // "reasonable default until loaded" pattern every other service
    // here follows.
    _backgroundMusicService.load();
  }

  /// Loads hydration/skincare, then reconciles anything logged from
  /// the Android home-screen widgets while the app wasn't open (see
  /// [HomeWidgetSyncService]'s doc comment for the full flow), then
  /// pushes fresh data to both widgets either way.
  ///
  /// Awaits its own `.load()` calls even though [initState] above
  /// already fires unawaited ones for the same two services — safe
  /// alongside them (`HydrationService.load`'s doc comment: safe to
  /// call more than once), and it's what lets
  /// [HomeWidgetSyncService.reconcilePendingWidgetTaps] below be
  /// properly awaited after both are actually ready, rather than
  /// racing the unawaited pair above.
  Future<void> _syncHomeWidgets() async {
    await _hydrationService.load();
    await _skincareService.load();
    await _homeWidgetSyncService.reconcilePendingWidgetTaps();
  }

  @override
  void dispose() {
    _favoritesService.dispose();
    _completionService.dispose();
    _dailyRoutineService.dispose();
    _customRoutinesService.dispose();
    _hydrationService.removeListener(_homeWidgetSyncService.pushHydrationData);
    _skincareService.removeListener(_homeWidgetSyncService.pushSkincareData);
    _hydrationService.dispose();
    _skincareService.dispose();
    _restDayService.dispose();
    _libraryBookmarksService.dispose();
    _reminderSettingsService.dispose();
    _onboardingService.dispose();
    _themeModeService.dispose();
    _accessibilityService.dispose();
    _premiumService.dispose();
    _adsManager.dispose();
    _workoutUnlockService.dispose();
    _breathingSettingsService.dispose();
    _narrationSettingsService.dispose();
    _exerciseNarrator.dispose();
    _backgroundMusicService.dispose();
    _navigationTabController.dispose();
    _streakService.dispose();
    _wellnessScoreService.dispose();
    _badgeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FavoritesScope(
      service: _favoritesService,
      child: CompletionScope(
        service: _completionService,
        child: DailyRoutineScope(
          service: _dailyRoutineService,
          child: CustomRoutinesScope(
            service: _customRoutinesService,
            child: HydrationScope(
              service: _hydrationService,
              child: SkincareScope(
                service: _skincareService,
                child: LibraryBookmarksScope(
                  service: _libraryBookmarksService,
                  child: RestDayScope(
                    service: _restDayService,
                    child: StreakScope(
                      service: _streakService,
                      child: ReminderSettingsScope(
                        service: _reminderSettingsService,
                        child: WellnessScoreScope(
                          service: _wellnessScoreService,
                          child: BadgeScope(
                            service: _badgeService,
                            child: OnboardingScope(
                              service: _onboardingService,
                              child: ThemeModeScope(
                                service: _themeModeService,
                                child: AccessibilityScope(
                                  service: _accessibilityService,
                                  child: PremiumScope(
                                    service: _premiumService,
                                    child: AdsScope(
                                      manager: _adsManager,
                                      child: WorkoutUnlockScope(
                                        service: _workoutUnlockService,
                                        child: BreathingSettingsScope(
                                      service: _breathingSettingsService,
                                      child: NarrationSettingsScope(
                                        service: _narrationSettingsService,
                                        child: ExerciseNarratorScope(
                                          narrator: _exerciseNarrator,
                                          child: BackgroundMusicScope(
                                            service: _backgroundMusicService,
                                            child: NavigationTabScope(
                                              service: _navigationTabController,
                                              child: TelemetryScope(
                                                service: widget.telemetryService,
                                              child: MaterialApp(
                                                title: 'ChadMate',
                                                debugShowCheckedModeBanner: false,
                                                // Fallback only — every screen inside
                                                // `home` actually renders under the
                                                // resolved, animated theme applied by
                                                // `builder` below via
                                                // [_AnimatedAppTheme]. `theme`/
                                                // `darkTheme` here just give
                                                // framework-level chrome that sits
                                                // outside `builder`'s child (e.g. the
                                                // very first frame before it mounts)
                                                // a reasonable light/dark default
                                                // instead of Flutter's bare
                                                // [ThemeData] fallback.
                                                theme: AppTheme.light,
                                                darkTheme: AppTheme.dark,
                                                themeMode: ThemeMode.system,
                                                builder: (context, child) {
                                                  return _AnimatedAppTheme(
                                                    child: child,
                                                  );
                                                },
                                                home: const _AppEntryPoint(),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
  ),
  );
  }
}

/// Resolves [ThemeModeService.mode] to a concrete [ThemeData] and
/// wraps [child] in an [AnimatedTheme] so every color on screen
/// cross-fades smoothly whenever the resolved theme changes — either
/// because the user picked a new mode in Settings, or because
/// [AppThemeMode.system] is active and the OS-level brightness
/// changed underneath it.
///
/// Placed via [MaterialApp.builder] rather than passed as
/// `MaterialApp.theme`, since [MaterialApp] itself only knows how to
/// animate between its own `theme`/`darkTheme` pair (a plain light/dark
/// split) — it has no concept of a third AMOLED palette. Resolving
/// the mode here instead means all four [AppThemeMode] values are
/// handled uniformly, each just producing a [ThemeData] that gets
/// smoothly tweened into.
class _AnimatedAppTheme extends StatelessWidget {
  const _AnimatedAppTheme({required this.child});

  final Widget? child;

  static ThemeData _resolve(BuildContext context, AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return AppTheme.light;
      case AppThemeMode.dark:
        return AppTheme.dark;
      case AppThemeMode.amoled:
        return AppTheme.amoled;
      case AppThemeMode.system:
        final isDark =
            MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        return isDark ? AppTheme.dark : AppTheme.light;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeModeScope.of(context);
    final accessibility = AccessibilityScope.of(context);
    var resolvedTheme = _resolve(context, themeService.mode);
    if (accessibility.highContrast) {
      resolvedTheme = AppTheme.applyHighContrast(resolvedTheme);
    }

    final mediaQuery = MediaQuery.of(context);
    // Layers the app's own text-scale step on top of whatever the OS
    // already applies, and combines the app-level reduce-motion
    // toggle with the OS setting — either one being on is enough to
    // simplify every animation below (see [StaggeredEntrance] and
    // [FadeThroughPageRoute], which both already read
    // `MediaQuery.disableAnimations`).
    final osScale = mediaQuery.textScaler.scale(1.0);
    final combinedScale =
        (osScale * accessibility.textScale.multiplier).clamp(0.8, 3.0);
    final scaledMediaQuery = mediaQuery.copyWith(
      textScaler: TextScaler.linear(combinedScale),
      disableAnimations:
          mediaQuery.disableAnimations || accessibility.reduceMotion,
    );

    return MediaQuery(
      data: scaledMediaQuery,
      child: AnimatedTheme(
        data: resolvedTheme,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
        child: AnimatedContainer(
          // Mirrors the scaffold-level background color change with
          // the same duration/curve as the theme cross-fade above, so
          // the very first frame after switching modes doesn't show a
          // hard-edged color underneath widgets that haven't repainted
          // yet — most visible right at the screen's edges/behind the
          // status bar during the transition.
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
          color: resolvedTheme.scaffoldBackgroundColor,
          child: child,
        ),
      ),
    );
  }
}

/// Decides whether to show the onboarding flow or the main app shell.
///
/// Waits for [OnboardingService.isLoaded] before deciding anything,
/// so a returning user never sees onboarding flash on screen while
/// persisted state is still being read from disk. Once loaded, shows
/// [OnboardingFlowScreen] until [OnboardingService.hasCompletedOnboarding]
/// becomes true — set by that flow's final step — at which point this
/// rebuilds (via [OnboardingScope]'s `notifyListeners()`) and swaps to
/// [MainNavigationScreen] automatically, with no manual navigation call
/// required.
class _AppEntryPoint extends StatelessWidget {
  const _AppEntryPoint();

  @override
  Widget build(BuildContext context) {
    final onboarding = OnboardingScope.of(context);

    if (!onboarding.isLoaded) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return onboarding.hasCompletedOnboarding
        ? const MainNavigationScreen()
        : const OnboardingFlowScreen();
  }
}
