import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/badge_definition.dart';
import '../models/exercise.dart';
import '../services/app_notifications.dart';
import '../services/badge_scope.dart';
import '../services/badge_service.dart';
import '../services/completion_scope.dart';
import '../services/daily_routine_scope.dart';
import '../services/exercise_repository.dart';
import '../services/hydration_scope.dart';
import '../services/navigation_tab_controller.dart';
import '../services/navigation_tab_scope.dart';
import '../services/onboarding_scope.dart';
import '../services/onboarding_service.dart';
import '../services/personalization_service.dart';
import '../services/reminder_settings_scope.dart';
import '../services/reminder_settings_service.dart';
import '../services/rest_day_scope.dart';
import '../services/skincare_scope.dart';
import '../services/skincare_service.dart';
import '../services/streak_scope.dart';
import '../services/streak_service.dart';
import '../services/wellness_score_scope.dart';
import '../widgets/ads/adaptive_banner_ad.dart';
import '../widgets/badges/badge_unlock_dialog.dart';
import '../widgets/home/ambient_background.dart';
import '../widgets/home/badges_summary_card.dart';
import '../widgets/home/coach_message_card.dart';
import '../widgets/home/daily_insight_card.dart';
import '../widgets/home/home_hero_header.dart';
import '../widgets/home/hydration_checkin_card.dart';
import '../widgets/home/hydration_sheet.dart';
import '../widgets/home/posture_check_prompt.dart';
import '../widgets/home/progress_preview_section.dart';
import '../widgets/home/quick_actions_row.dart';
import '../widgets/home/reminder_sheet.dart';
import '../widgets/home/rest_day_sheet.dart';
import '../widgets/home/routine_hero_card.dart';
import '../widgets/home/skincare_checkin_card.dart';
import '../widgets/home/skincare_sheet.dart';
import '../widgets/home/streaks_overview_card.dart';
import '../widgets/home/wellness_score_card.dart';
import '../widgets/shared/reminder_card.dart';
import '../widgets/shared/section_header.dart';
import 'badges_screen.dart';
import 'breathing_hub_screen.dart';
import 'wellness_library_screen.dart';

/// Width at which the layout switches from a single stacked column to
/// a wider, side-by-side arrangement (tablets, foldables, desktop).
const double _wideBreakpoint = 700;

/// Home tab.
///
/// A dashboard-style layout combining the user's onboarding profile
/// (name, goals, and experience level, sourced from [OnboardingScope]
/// and turned into a greeting and a personalized routine via
/// [PersonalizationService]) with real state: today's
/// exercise-completion progress (sourced from the app's exercise
/// catalog and [CompletionScope]), today's water intake (sourced from
/// [HydrationScope]), today's morning/night skincare checklists
/// (sourced from [SkincareScope]), posture-reminder settings and
/// history (sourced from [ReminderSettingsScope]), and the workout,
/// hydration, skincare, and overall-wellness streaks (sourced from
/// [StreakScope], which derives them from the three services above),
/// today's overall Wellness Score (sourced from
/// [WellnessScoreScope]), and achievement badge progress (sourced
/// from [BadgeScope]) — including celebrating any badge unlocked
/// while this screen is visible with a one-time animated dialog (see
/// [showBadgeUnlockCelebration]).
/// Tapping the hydration, skincare, or posture cards opens their
/// respective tracking sheets; tapping the badges card opens the
/// full [BadgesScreen]. A "Quick Check-in" section below the
/// reminders — [HydrationCheckInCard] and [SkincareCheckInCard] —
/// offers the same two directly as tappable checkboxes, so logging a
/// glass of water or checking off a skincare step doesn't require
/// opening either sheet at all; both read and write through the same
/// [HydrationScope]/[SkincareScope] services as the sheets and cards
/// above, so every surface stays in sync automatically. Also shows
/// [PostureCheckPrompt] above the reminder cards whenever
/// [ReminderSettingsService.hasPendingPostureCheck]
/// is true — see that flag's doc comment for why posture specifically
/// needs an explicit acknowledgment UI that hydration and skincare
/// don't.
///
/// Built from the app's shared widget kit — [HomeHeroHeader],
/// [RoutineHeroCard], [CoachMessageCard], [QuickActionsRow],
/// [DailyInsightCard], [ProgressPreviewSection], [ReminderCard],
/// [StreaksOverviewCard], all wrapped in [AmbientBackground] — so this
/// screen mostly wires data into reusable pieces rather than
/// hand-rolling layout. See [RoutineHeroCard]'s own doc comment in
/// particular for how it's able to present three quite different
/// states (rest day / already completed / here's what's next) while
/// this screen still only ever hands it one "go to Routine" callback.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ---- Dummy data -----------------------------------------------------
  // Fallback only, used if the user skipped the name field during
  // onboarding; the real name comes from OnboardingScope below.
  static const String _fallbackUserName = 'there';

  static const PersonalizationService _personalization =
      PersonalizationService();

  static const ExerciseRepository _repository = ExerciseRepository();

  /// The full exercise catalog, used to know today's total exercise
  /// count and each exercise's duration. Empty until [_loadExercises]
  /// resolves, so the routine card just reads as "0 of 0" briefly on
  /// first launch rather than showing a loading spinner for this one
  /// section.
  List<Exercise> _allExercises = const [];

  /// Ids making up today's personalized routine, resolved once
  /// [_allExercises] has loaded and the onboarding profile is
  /// available. Empty until [_maybeBuildPersonalizedRoutine] resolves,
  /// so the routine card shows the full catalog count in the meantime
  /// rather than blocking on this.
  Set<String> _personalizedIds = const {};

  /// Guards against calling [DailyRoutineService.ensureTodayRoutine]
  /// more than once per catalog load; re-runs if the profile's goals
  /// change (see [didChangeDependencies]) so switching goals in
  /// Settings updates today's routine rather than leaving it stale.
  Set<OnboardingGoal>? _routineBuiltForGoals;

  /// The calendar day [_maybeBuildPersonalizedRoutine] last actually
  /// ran for — see [_refreshRoutineIfDayChanged].
  DateTime? _lastRoutineCheckDay;

  late final AnimationController _entranceController;

  /// The [BadgeService] this screen is currently listening to, so
  /// [dispose] can remove the exact same listener instance rather
  /// than risking a mismatch if [BadgeScope] ever resolved to a
  /// different service between calls.
  BadgeService? _badgeService;

  /// Guards against overlapping celebration dialogs: only one
  /// [_celebrateNewBadges] run is ever "in flight" showing dialogs
  /// one after another at a time.
  bool _showingCelebrations = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadExercises();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshRoutineIfDayChanged();
    }
  }

  /// Forces [_maybeBuildPersonalizedRoutine] to re-run if the calendar
  /// day has moved on since it last actually built anything — the
  /// same fix, for the same underlying regression, as
  /// [RoutineScreen._refreshIfDayChanged] (see that method's doc
  /// comment for the full explanation). [_maybeBuildPersonalizedRoutine]
  /// on its own only ever re-runs when the onboarding goals change;
  /// clearing [_routineBuiltForGoals] here is what makes its existing
  /// guard see "nothing built yet" and proceed again, rather than
  /// duplicating that method's logic here.
  void _refreshRoutineIfDayChanged() {
    final lastChecked = _lastRoutineCheckDay;
    final now = DateTime.now();
    final sameDay =
        lastChecked != null &&
        lastChecked.year == now.year &&
        lastChecked.month == now.month &&
        lastChecked.day == now.day;
    if (sameDay || !mounted) return;
    _routineBuiltForGoals = null;
    _maybeBuildPersonalizedRoutine();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceController.status == AnimationStatus.dismissed) {
      if (MediaQuery.of(context).disableAnimations) {
        _entranceController.value = 1.0;
      } else {
        _entranceController.forward();
      }
    }
    _maybeBuildPersonalizedRoutine();

    final badges = BadgeScope.of(context);
    if (!identical(badges, _badgeService)) {
      _badgeService?.removeListener(_onBadgesChanged);
      _badgeService = badges;
      badges.addListener(_onBadgesChanged);
    }
    // Also check right away — covers badges that were already newly
    // unlocked (e.g. by an action on another tab) before this screen
    // was built, not just ones unlocked while it's on screen.
    _onBadgesChanged();
  }

  void _onBadgesChanged() {
    if (_showingCelebrations) return;
    final badges = _badgeService;
    if (badges == null || badges.newlyUnlocked.isEmpty) return;
    _showingCelebrations = true;
    // Deferred to after the current frame/build so the dialog isn't
    // pushed in the middle of a widget build triggered by the same
    // notifyListeners() call that populated newlyUnlocked.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_celebrateNewBadges(badges));
    });
  }

  /// Shows one celebration dialog per badge in [badges.newlyUnlocked],
  /// one after another, then marks them acknowledged so the same
  /// unlock doesn't animate again on the next rebuild.
  Future<void> _celebrateNewBadges(BadgeService badges) async {
    final ids = List.of(badges.newlyUnlocked);
    for (final id in ids) {
      if (!mounted) break;
      await showBadgeUnlockCelebration(context, BadgeDefinition.forId(id));
    }
    if (mounted) badges.acknowledgeNewlyUnlocked();
    _showingCelebrations = false;
  }

  void _openBadges(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const BadgesScreen()),
    );
  }

  /// Builds (or rebuilds) today's personalized routine once the
  /// catalog has loaded, keyed off the current onboarding goals so a
  /// goal change elsewhere in the app refreshes it here too. Cheap and
  /// idempotent when goals haven't changed, since
  /// [DailyRoutineService.ensureTodayRoutine] itself
  /// no-ops once today's routine is already valid.
  void _maybeBuildPersonalizedRoutine() {
    if (_allExercises.isEmpty) return;
    final profile = OnboardingScope.of(context).profile;
    if (_routineBuiltForGoals != null &&
        setEquals(_routineBuiltForGoals, profile.goals)) {
      return;
    }
    _routineBuiltForGoals = profile.goals;
    _lastRoutineCheckDay = DateTime.now();
    final service = DailyRoutineScope.of(context);
    unawaited(
      service
          .ensureTodayRoutine(
            catalog: _allExercises,
            goals: profile.goals,
            experienceLevel: profile.experienceLevel,
          )
          .then((exercises) {
            if (!mounted) return;
            setState(() {
              _personalizedIds = exercises.map((e) => e.id).toSet();
            });
          }),
    );
  }

  Future<void> _loadExercises() async {
    try {
      final exercises = await _repository.loadExercises();
      if (!mounted) return;
      setState(() => _allExercises = exercises);
      _maybeBuildPersonalizedRoutine();
    } catch (_) {
      // Swallow load errors here: the Exercises tab already surfaces
      // a proper error state with retry, so this dashboard card just
      // stays at "0 of 0" rather than duplicating that handling.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _badgeService?.removeListener(_onBadgesChanged);
    _entranceController.dispose();
    super.dispose();
  }

  /// Wraps [child] in a fade + gentle upward slide, timed to appear in
  /// sequence with the other sections based on [index] of [total].
  Widget _staggered(int index, int total, Widget child) {
    final start = (index / total) * 0.5;
    final end = (start + 0.5).clamp(0.0, 1.0).toDouble();
    final animation = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context, ThemeData theme, bool isWide) {
    final completion = CompletionScope.of(context);
    final profile = OnboardingScope.of(context).profile;
    final greeting = _personalization.greeting(
      hour: DateTime.now().hour,
      name: profile.name,
      goals: profile.goals,
    );
    final trimmedName = profile.name?.trim();
    final displayName = (trimmedName != null && trimmedName.isNotEmpty)
        ? trimmedName
        : _fallbackUserName;

    // Real data from the exercise catalog + today's completion state,
    // rather than the fixed placeholder counts this screen used to
    // show. Intersected with the current catalog's ids so a
    // completion recorded for an exercise since removed from the
    // catalog can't inflate the count.
    final catalogIds = _allExercises.map((exercise) => exercise.id).toSet();
    final routineExercises = _personalizedIds.isEmpty
        ? _allExercises
        : _allExercises
              .where((exercise) => _personalizedIds.contains(exercise.id))
              .toList();
    final totalExercises = routineExercises.length;
    final relevantIds = _personalizedIds.isEmpty ? catalogIds : _personalizedIds;
    final completedToday =
        completion.completedTodayIds.intersection(relevantIds).length;
    final totalDuration = routineExercises.fold<Duration>(
      Duration.zero,
      (sum, exercise) => sum + exercise.duration,
    );

    final isRestDay = RestDayScope.of(context).isRestDay(DateTime.now());

    final streaks = StreakScope.of(context).allStreaks();
    final workoutStreak = streaks.firstWhere(
      (s) => s.kind == StreakKind.workout,
      orElse: () => streaks.first,
    );
    final streakCard = StreaksOverviewCard(
      streaks: streaks,
      onScheduleRestDay: () => showRestDaySheet(context),
    );

    final header = HomeHeroHeader(
      greeting: greeting,
      displayName: displayName,
      currentStreak: workoutStreak.currentStreak,
    );

    final routineService = DailyRoutineScope.of(context);
    final routineCard = RoutineHeroCard(
      isRestDay: isRestDay,
      sessionSummary: routineService.todaySessionSummary,
      totalExercises: totalExercises,
      completedToday: completedToday,
      totalDuration: totalDuration,
      difficultyLabel: routineService.difficulty.label,
      onAction: () =>
          NavigationTabScope.of(context, listen: false).switchTo(AppTab.routine),
    );

    const coachCard = CoachMessageCard();
    const insightCard = DailyInsightCard();

    final wellnessSnapshot = WellnessScoreScope.of(context).todaySnapshot();
    final wellnessCard = WellnessScoreCard(snapshot: wellnessSnapshot);

    final progressPreview = ProgressPreviewSection(
      currentStreak: workoutStreak.currentStreak,
      longestStreak: workoutStreak.longestStreak,
      totalSessions: completion.totalCompletedCount,
      wellnessScore: wellnessSnapshot.score,
    );

    final badgeProgress = BadgeScope.of(context).allProgress();
    final badgesCard = BadgesSummaryCard(
      progress: badgeProgress,
      onTap: () => _openBadges(context),
    );

    final hydration = HydrationScope.of(context);
    final hydrationSubtitle = hydration.goalReachedToday
        ? 'Goal reached — ${hydration.formatMl(hydration.todayIntakeMl)} '
              'of ${hydration.formatMl(hydration.goalMl)}'
        : '${hydration.formatMl(hydration.todayIntakeMl)} of '
              '${hydration.formatMl(hydration.goalMl)} today';
    final hydrationTip =
        (profile.goals.contains(OnboardingGoal.hydration) &&
                hydration.todayIntakeMl == 0)
        ? PersonalizationService.nonExerciseGoalTips[OnboardingGoal.hydration]
        : null;

    final reminderSettings = ReminderSettingsScope.of(context);

    final skincare = SkincareScope.of(context);
    final morningDone = skincare.completedCountFor(SkincareRoutine.morning);
    final morningTotal = skincare.totalCountFor(SkincareRoutine.morning);
    final nightDone = skincare.completedCountFor(SkincareRoutine.night);
    final nightTotal = skincare.totalCountFor(SkincareRoutine.night);
    final skincareSubtitle =
        skincare.isRoutineComplete(SkincareRoutine.morning) &&
            skincare.isRoutineComplete(SkincareRoutine.night)
        ? 'Morning & night routines complete'
        : 'Morning $morningDone/$morningTotal · Night $nightDone/$nightTotal';
    final skincareTip =
        (profile.goals.contains(OnboardingGoal.skincareConsistency) &&
                morningDone == 0 &&
                nightDone == 0)
        ? PersonalizationService
              .nonExerciseGoalTips[OnboardingGoal.skincareConsistency]
        : null;

    final reminders = [
      ReminderCard(
        icon: Icons.water_drop,
        title: 'Stay Hydrated',
        subtitle: hydrationTip ?? hydrationSubtitle,
        trailing: _ReminderProgressBadge(progress: hydration.todayProgress),
        onTap: () => showHydrationSheet(context),
      ),
      ReminderCard(
        icon: Icons.spa,
        title: 'Skincare Check-in',
        subtitle: skincareTip ?? skincareSubtitle,
        trailing: _ReminderProgressBadge(progress: skincare.todayProgress),
        onTap: () => showSkincareSheet(context),
      ),
      ReminderCard(
        icon: Icons.accessibility_new,
        title: 'Posture Check',
        subtitle:
            reminderSettings.isEnabled(ReminderKind.posture)
            ? '${reminderSettings.postureInterval.label} · '
                  '${reminderSettings.todayHistoryFor(ReminderKind.posture).length} today'
            : 'Sit up straight and relax your jaw',
        onTap: () => showReminderSheet(context, ReminderKind.posture),
      ),
      ReminderCard(
        icon: Icons.air_rounded,
        title: 'Guided Breathing',
        subtitle: 'Box, 4-7-8, Calm & Deep Belly sessions',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const BreathingHubScreen(),
          ),
        ),
      ),
      ReminderCard(
        icon: Icons.menu_book_outlined,
        title: 'Wellness Library',
        subtitle: 'Short reads on jaw, neck, posture & more',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const WellnessLibraryScreen(),
          ),
        ),
      ),
    ];

    final quickActions = QuickActionsRow(
      actions: [
        QuickAction(
          emoji: '💧',
          label: 'Hydration',
          onTap: () => showHydrationSheet(context),
        ),
        QuickAction(
          emoji: '🧴',
          label: 'Skincare',
          onTap: () => showSkincareSheet(context),
        ),
        QuickAction(
          emoji: '🧍',
          label: 'Posture',
          onTap: () => showReminderSheet(context, ReminderKind.posture),
        ),
        QuickAction(
          emoji: '🧘',
          label: 'Breathing',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const BreathingHubScreen()),
          ),
        ),
      ],
    );

    const remindersHeader = SectionHeader(title: 'Daily Reminders');
    const checkInHeader = SectionHeader(title: 'Quick Check-in');
    const hydrationCheckIn = HydrationCheckInCard();
    const skincareCheckIn = SkincareCheckInCard();

    // Each entry pairs a section with the space to leave after it.
    final List<({Widget child, double gap})> items;
    if (isWide) {
      items = [
        (child: header, gap: 28),
        (child: wellnessCard, gap: 28),
        (
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: routineCard),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: streakCard),
            ],
          ),
          gap: 24,
        ),
        (child: coachCard, gap: 24),
        (child: quickActions, gap: 28),
        (child: badgesCard, gap: 28),
        (child: remindersHeader, gap: 12),
        if (reminderSettings.hasPendingPostureCheck)
          (
            child: PostureCheckPrompt(reminders: reminderSettings),
            gap: 16,
          ),
        (
          child: Row(
            children: [
              for (var i = 0; i < reminders.length; i++) ...[
                if (i != 0) const SizedBox(width: 16),
                Expanded(child: reminders[i]),
              ],
            ],
          ),
          gap: 28,
        ),
        (child: checkInHeader, gap: 12),
        (
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: hydrationCheckIn),
              const SizedBox(width: 16),
              Expanded(child: skincareCheckIn),
            ],
          ),
          gap: 28,
        ),
        (child: insightCard, gap: 24),
        (child: progressPreview, gap: 0),
      ];
    } else {
      items = [
        (child: header, gap: 24),
        (child: wellnessCard, gap: 20),
        (child: routineCard, gap: 20),
        (child: coachCard, gap: 20),
        (child: quickActions, gap: 24),
        (child: streakCard, gap: 20),
        (child: badgesCard, gap: 28),
        (child: remindersHeader, gap: 12),
        if (reminderSettings.hasPendingPostureCheck)
          (
            child: PostureCheckPrompt(reminders: reminderSettings),
            gap: 12,
          ),
        (child: reminders[0], gap: 12),
        (child: reminders[1], gap: 12),
        (child: reminders[2], gap: 12),
        (child: reminders[3], gap: 12),
        (child: reminders[4], gap: 28),
        (child: checkInHeader, gap: 12),
        (child: hydrationCheckIn, gap: 12),
        (child: skincareCheckIn, gap: 24),
        (child: insightCard, gap: 20),
        (child: progressPreview, gap: 0),
      ];
    }

    final sections = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      sections.add(_staggered(i, items.length, items[i].child));
      if (items[i].gap > 0) sections.add(SizedBox(height: items[i].gap));
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      bottomNavigationBar: const AdaptiveBannerAd(),
      body: AmbientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= _wideBreakpoint;
              final horizontalPadding = isWide ? 32.0 : 20.0;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      32,
                    ),
                    children: _buildSections(context, theme, isWide),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A tiny circular progress indicator used as a reminder card's
/// trailing widget, giving an at-a-glance sense of today's progress
/// (hydration or skincare) without opening the full sheet.
class _ReminderProgressBadge extends StatelessWidget {
  const _ReminderProgressBadge({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return CircularProgressIndicator(
                value: value,
                strokeWidth: 3,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
              );
            },
          ),
          Icon(Icons.chevron_right, size: 16, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
