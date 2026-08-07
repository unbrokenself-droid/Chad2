import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../services/daily_routine_scope.dart';
import '../services/daily_routine_service.dart';
import '../services/exercise_repository.dart';
import '../services/navigation_tab_controller.dart';
import '../services/navigation_tab_scope.dart';
import '../services/onboarding_scope.dart';
import '../services/onboarding_service.dart';
import '../services/rest_day_scope.dart';
import '../services/streak_scope.dart';
import '../services/streak_service.dart';
import '../utils/app_haptics.dart';
import '../widgets/coach/coach_avatar.dart';
import '../widgets/exercises/exercise_card.dart';
import '../widgets/routine/routine_difficulty_sheet.dart';
import '../widgets/routine/routine_exercise_options_menu.dart';
import '../widgets/routine/routine_replacement_sheet.dart';
import '../widgets/shared/fade_through_page_route.dart';
import '../widgets/shared/primary_button.dart';
import '../widgets/shared/section_header.dart';
import '../widgets/shared/staggered_entrance.dart';
import 'coach_generation_screen.dart';
import 'custom_routines_screen.dart';
import 'exercise_details_screen.dart';
import 'workout_session_screen.dart';

/// Routine tab.
///
/// Shows today's automatically generated routine as **one continuous,
/// ordered list** — not grouped into a section per category. A
/// routine covers every [ExerciseCategory] every day, regardless of
/// [RoutineDifficulty]; what changes between levels is how many
/// exercises come from each category, not which categories show up
/// (see [DailyRoutineService]'s class doc comment for the full
/// reasoning behind that split). Personalization from the user's
/// onboarding goals (see [PersonalizationService]) still shifts which
/// categories' exercises appear *earlier* in the list, but no longer
/// affects which categories are included at all — that's now fixed.
/// The routine is generated once per calendar day by
/// [DailyRoutineService] and persisted locally, so it stays the same
/// across app restarts for the rest of the day.
///
/// "Start Routine" is this screen's primary action: it launches
/// [WorkoutSessionScreen], a single continuous guided session that
/// runs every exercise in today's routine back to back with rest
/// periods in between and no manual "open the next exercise" step —
/// the Routine tab's whole reason for being distinct from the
/// Exercises tab's browse-one-at-a-time library. Tapping an
/// individual exercise card still opens its regular details screen
/// instead, for previewing or running just that one exercise on its
/// own outside of a full session.
///
/// Each exercise card also carries a "more options" menu so the user
/// can customize today's plan: remove an exercise entirely, or
/// replace it with another exercise from the same category. Both
/// actions go through [DailyRoutineService], which persists the
/// change locally (via `SharedPreferences`) so it survives an app
/// restart for the rest of the day.
///
/// "Adjust Difficulty" opens [RoutineDifficultySheet] to pick between
/// Beginner/Intermediate/Advanced — a change here is sticky (it
/// applies to today's regenerated routine immediately, and every day
/// after, until changed again), unlike the exercise-level
/// remove/replace actions above, which only ever affect today.
///
/// A "My Routines" action (in the app bar and next to the "Today's
/// Plan" heading) opens [CustomRoutinesScreen], where the user can
/// build their own named, reorderable routines from any exercise in
/// the catalog — separate from this screen's auto-generated daily
/// plan, and persisted indefinitely via [CustomRoutinesService].
///
/// On a day scheduled as a rest day (see [RestDayService]/
/// [RestDaySheet]), this screen shows [_RestDayState] instead of any
/// exercise content at all — no list, no "Start Routine" — rather
/// than a routine that would be misleading to run.
class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen>
    with WidgetsBindingObserver {
  static const ExerciseRepository _repository = ExerciseRepository();

  late Future<List<Exercise>> _catalogFuture;
  bool _initialized = false;

  /// The calendar day [_catalogFuture] was last computed for — see
  /// [_refreshIfDayChanged], which compares this against the actual
  /// current day on every app resume, not just this widget's first
  /// build.
  DateTime? _lastLoadedDay;

  /// Whether "View Today's Session" has been tapped, temporarily
  /// showing the completed exercise list in place of
  /// [_SessionCompleteDashboard] — reset back to `false` any time a
  /// new routine is generated (see [_startRoutine]'s sibling
  /// generation call sites), so a fresh day or a difficulty change
  /// doesn't leave yesterday's "expanded" choice stuck on.
  bool _showCompletedSession = false;

  /// The full exercise catalog, once loaded. Kept around (rather than
  /// just today's picks) so "replace" has other same-category
  /// exercises to offer, and so the routine can be re-resolved from
  /// [DailyRoutineService]'s live id list on every rebuild.
  List<Exercise> _catalog = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `DailyRoutineScope.of` must be called while this element is
    // part of the tree (it registers a dependency), so it's read here
    // rather than inside the async `_loadCatalog` future — by the
    // time that future resolves past its first `await`, this context
    // may no longer be safely usable for that lookup.
    if (!_initialized) {
      _initialized = true;
      _lastLoadedDay = DateTime.now();
      final routineService = DailyRoutineScope.of(context);
      final profile = OnboardingScope.of(context).profile;
      _catalogFuture = _loadCatalog(routineService, profile.goals, profile.experienceLevel);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshIfDayChanged();
    }
  }

  /// Re-runs [_loadCatalog] — regenerating today's routine and
  /// clearing any stale completion summary in the process, exactly
  /// like a fresh app launch on a new day already would — if the
  /// calendar day has moved on since it was last run.
  ///
  /// This is the fix for a real regression: previously, "has today
  /// changed" was only ever checked the first time this widget was
  /// built — once per app *process*, not once per day. Android very
  /// commonly keeps an app's process alive across being backgrounded
  /// rather than truly restarting it, so a day rolling over while the
  /// app just sat in the background (or the user briefly switched
  /// away and back near midnight) left [DailyRoutineService]'s
  /// generated routine, exercise ids, and completion summary all
  /// stuck on the previous day indefinitely — nothing was ever
  /// checking again to notice and refresh them. That showed up as
  /// "the Routine tab is blank the next day": actually still
  /// yesterday's already-completed session, with no fresh routine
  /// underneath it and no obvious way forward. Checking on every
  /// resume (not just the first build) means this self-heals
  /// regardless of how long the app process happens to survive in
  /// the background.
  void _refreshIfDayChanged() {
    final lastLoaded = _lastLoadedDay;
    final now = DateTime.now();
    final sameDay =
        lastLoaded != null &&
        lastLoaded.year == now.year &&
        lastLoaded.month == now.month &&
        lastLoaded.day == now.day;
    if (sameDay || !mounted) return;

    _lastLoadedDay = now;
    final routineService = DailyRoutineScope.of(context);
    final profile = OnboardingScope.of(context).profile;
    setState(() {
      _showCompletedSession = false;
      _catalogFuture = _loadCatalog(
        routineService,
        profile.goals,
        profile.experienceLevel,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<List<Exercise>> _loadCatalog(
    DailyRoutineService routineService,
    Set<OnboardingGoal> goals,
    ExperienceLevel? experienceLevel,
  ) async {
    final catalog = await _repository.loadExercises();
    await routineService.ensureTodayRoutine(
      catalog: catalog,
      goals: goals,
      experienceLevel: experienceLevel,
    );
    _catalog = catalog;
    return catalog;
  }

  void _retry() {
    final routineService = DailyRoutineScope.of(context);
    final profile = OnboardingScope.of(context).profile;
    setState(() => _catalogFuture =
        _loadCatalog(routineService, profile.goals, profile.experienceLevel));
  }

  void _openDetails(Exercise exercise) {
    Navigator.of(context).push(
      FadeThroughPageRoute(
        builder: (context) => ExerciseDetailsScreen(exercise: exercise),
      ),
    );
  }

  Future<void> _removeExercise(
    DailyRoutineService routineService,
    Exercise exercise,
  ) async {
    final removedIndex = await routineService.removeExercise(exercise.id);
    if (removedIndex == null || !mounted) return;
    AppHaptics.medium();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed ${exercise.title} from today'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              AppHaptics.selection();
              routineService.restoreExercise(exercise.id, removedIndex);
            },
          ),
        ),
      );
  }

  Future<void> _replaceExercise(
    DailyRoutineService routineService,
    Exercise exercise,
  ) async {
    final todayIds = routineService.todayExerciseIds.toSet();
    final candidates = _catalog
        .where((e) =>
            e.category == exercise.category &&
            e.id != exercise.id &&
            !todayIds.contains(e.id))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    final selected = await RoutineReplacementSheet.show(
      context,
      category: exercise.category,
      currentExerciseId: exercise.id,
      candidates: candidates,
    );

    if (selected == null || !mounted) return;
    await routineService.replaceExercise(
      oldExerciseId: exercise.id,
      newExerciseId: selected.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Swapped in ${selected.title}')),
      );
  }

  void _openCustomRoutines() {
    Navigator.of(context).push(
      FadeThroughPageRoute(
        builder: (context) => const CustomRoutinesScreen(),
      ),
    );
  }

  /// Launches [WorkoutSessionScreen] as a single, continuous, guided
  /// session covering every exercise currently in today's routine, in
  /// order. Not offered at all when the routine is empty (nothing to
  /// remove/replace it down to zero, but a shuffle or removing every
  /// exercise could) — there'd be nothing for a session to run.
  void _startRoutine(List<Exercise> routine) {
    if (routine.isEmpty) return;
    AppHaptics.medium();
    Navigator.of(context).push(
      FadeThroughPageRoute(
        builder: (context) => WorkoutSessionScreen(exercises: routine),
      ),
    );
  }

  /// Opens [RoutineDifficultySheet] and, if the user confirms a level
  /// rather than cancelling, shows [CoachGenerationScreen] while
  /// [DailyRoutineService.setDifficulty] regenerates today's routine
  /// to match it — the same full-screen "the coach is rebuilding your
  /// workout" takeover [OnboardingFlowScreen] shows the first time a
  /// routine is ever generated, not an instant list swap.
  Future<void> _adjustDifficulty(DailyRoutineService routineService) async {
    final selected = await showRoutineDifficultySheet(
      context,
      currentDifficulty: routineService.difficulty,
    );
    if (selected == null || !mounted) return;
    if (selected == routineService.difficulty) return;
    final goals = OnboardingScope.of(context).profile.goals;

    await Navigator.of(context).push<List<Exercise>>(
      MaterialPageRoute(
        builder: (context) => CoachGenerationScreen(
          title: 'Coach is rebuilding your routine',
          imageAsset: 'assets/images/coach/rebuilding_routine.png',
          generate: () => routineService.setDifficulty(
            difficulty: selected,
            catalog: _catalog,
            goals: goals,
          ),
        ),
      ),
    );
    if (!mounted) return;
    AppHaptics.medium();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            "Today's plan updated to ${selected.label} — "
            '${selected.exercisesPerCategory} exercises per category.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final routineService = DailyRoutineScope.of(context);
    final isRestDay = RestDayScope.of(context).isRestDay(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routine'),
        actions: [
          IconButton(
            onPressed: _openCustomRoutines,
            icon: const Icon(Icons.playlist_play),
            tooltip: 'My Routines',
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            final horizontalPadding = isWide ? 32.0 : 20.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: FutureBuilder<List<Exercise>>(
                  future: _catalogFuture,
                  builder: (context, snapshot) {
                    final routine = _resolveRoutine(routineService);
                    final sessionSummary = routineService.todaySessionSummary;
                    final totalDuration = routine.fold<Duration>(
                      Duration.zero,
                      (sum, exercise) => sum + exercise.duration,
                    );
                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        20,
                        horizontalPadding,
                        32,
                      ),
                      children: [
                        SectionHeader(
                          size: SectionHeaderSize.large,
                          subtitle: 'Your Routine',
                          title: "Today's Plan",
                          trailing: OutlinedButton.icon(
                            onPressed: _openCustomRoutines,
                            icon: const Icon(Icons.playlist_play, size: 18),
                            label: const Text('My Routines'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (snapshot.connectionState ==
                            ConnectionState.waiting)
                          Padding(
                            padding: const EdgeInsets.only(top: 48),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Semantics has no const constructor.
                                  Semantics(
                                    label: "Loading today's routine",
                                    child: const CircularProgressIndicator(),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text("Loading today's routine…"),
                                ],
                              ),
                            ),
                          )
                        else if (snapshot.hasError)
                          _RoutineErrorState(onRetry: _retry)
                        else if (isRestDay)
                          const _RestDayState()
                        else if (sessionSummary != null &&
                            !_showCompletedSession)
                          _SessionCompleteDashboard(
                            summary: sessionSummary,
                            onViewSession: () =>
                                setState(() => _showCompletedSession = true),
                          )
                        else ...[
                          if (_showCompletedSession) ...[
                            TextButton.icon(
                              onPressed: () => setState(
                                () => _showCompletedSession = false,
                              ),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                              ),
                              label: const Text('Back to Summary'),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (routine.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.fitness_center,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${routine.length} exercises · '
                                  '${totalDuration.inMinutes} min · '
                                  '${routineService.difficulty.label}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'One continuous session — exercises and rest '
                              'breaks advance automatically once started.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: PrimaryButton(
                                    label: 'Start Routine',
                                    icon: Icons.play_arrow_rounded,
                                    onPressed: () => _startRoutine(routine),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton.filledTonal(
                                  onPressed: () =>
                                      _adjustDifficulty(routineService),
                                  icon: const Icon(Icons.tune_rounded),
                                  tooltip: 'Adjust Difficulty',
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                          ..._buildExerciseList(routineService, routine),
                        ],
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Resolves today's exercise ids (read live from [routineService])
  /// against the loaded [_catalog]. Reading the ids directly in
  /// [build] — rather than caching the routine in local state — means
  /// remove/replace actions, which call `notifyListeners()` on the
  /// service, are reflected immediately via [DailyRoutineScope]'s
  /// rebuild.
  List<Exercise> _resolveRoutine(DailyRoutineService routineService) {
    final catalogById = {for (final e in _catalog) e.id: e};
    return [
      for (final id in routineService.todayExerciseIds)
        if (catalogById.containsKey(id)) catalogById[id]!,
    ];
  }

  /// Renders [routine] as one flat, numbered, ordered list — the
  /// session's actual running order — rather than grouped into a
  /// section per [ExerciseCategory]. The number badge in front of
  /// each card is the one visual cue carrying the "this is a single
  /// sequential session" framing in this static overview; the actual
  /// rest breaks between exercises only appear once the guided
  /// session itself is running (see [WorkoutSessionScreen]), not
  /// duplicated here as static placeholders.
  List<Widget> _buildExerciseList(
    DailyRoutineService routineService,
    List<Exercise> routine,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = <Widget>[];
    for (var i = 0; i < routine.length; i++) {
      final exercise = routine[i];
      items.add(
        StaggeredEntrance(
          index: i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ExerciseCard(
                    key: ValueKey(exercise.id),
                    exercise: exercise,
                    onTap: () => _openDetails(exercise),
                    trailing: RoutineExerciseOptionsMenu(
                      onSelected: (action) {
                        switch (action) {
                          case RoutineExerciseAction.replace:
                            _replaceExercise(routineService, exercise);
                          case RoutineExerciseAction.remove:
                            _removeExercise(routineService, exercise);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return items;
  }
}

/// Icon/color helpers used only for the Routine screen's per-category
/// Shown instead of any exercise content — no category sections, no
/// "Start Routine" — whenever today matches a rest day scheduled via
/// [RestDaySheet] (either a specific date or a recurring weekday like
/// every Sunday). Reuses the exact explanatory copy
/// [RestDaySheet] itself already uses, so the "why" reads identically
/// wherever a user encounters it.
///
/// Deliberately doesn't hide the app bar's "My Routines" action: a
/// rest day pauses today's *auto-generated* routine specifically, not
/// exercise entirely — [CustomRoutinesScreen] stays reachable for
/// anyone who wants to run one of their own routines anyway.
class _RestDayState extends StatelessWidget {
  const _RestDayState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.self_improvement,
              size: 36,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Rest Day',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'On a rest day your workout streak is paused, not broken. '
              'Hydration and skincare still count as usual.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the category sections if loading the catalog or
/// generating today's routine fails, with a retry action — mirrors
/// the tone of other error states in the app rather than a bare
/// exception message.
class _RoutineErrorState extends StatelessWidget {
  const _RoutineErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 40,
            color: colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            "Couldn't generate today's routine",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Check your connection or storage and try again.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Replaces the exercise list entirely once today's routine has been
/// fully run — see [DailyRoutineService.todaySessionSummary] — rather
/// than continuing to show a list of now-all-checked cards. Reads
/// only from the persisted [RoutineSessionSummary], not any live
/// [WorkoutSessionManager], so this looks the same whether it's shown
/// the instant a session finishes or hours later after the app was
/// closed and reopened.
class _SessionCompleteDashboard extends StatelessWidget {
  const _SessionCompleteDashboard({
    required this.summary,
    required this.onViewSession,
  });

  final RoutineSessionSummary summary;
  final VoidCallback onViewSession;

  String _formatMinutes(Duration d) {
    final minutes = (d.inSeconds / 60).ceil();
    return minutes <= 1 ? '1 min' : '$minutes min';
  }

  String _formatTime(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  String _motivationalMessage(int streakDays) {
    if (streakDays >= 7) {
      return "Incredible consistency — you're building something real.";
    }
    if (streakDays >= 3) {
      return "You're on a roll. Keep this momentum going.";
    }
    return 'Nice work today. Every session adds up.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final workoutStreak = StreakScope.of(context).infoFor(StreakKind.workout);
    // A rough, generic estimate for gentle mobility/stretching work —
    // not derived from any real activity tracking, matching the same
    // caveat WorkoutSessionScreen's own completion screen already
    // carries for the identical figure.
    final estimatedCalories = (summary.duration.inMinutes * 4).clamp(1, 999);

    return Column(
      children: [
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.3, end: 1.0),
          duration: const Duration(milliseconds: 550),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: const CoachAvatar(
            size: 100,
            imageAsset: 'assets/images/coach/workout_complete.png',
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Today's Session Completed \u{1F389}",
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CoachAvatar(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _motivationalMessage(workoutStreak.currentStreak),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _StatTile(
              icon: Icons.timer_outlined,
              value: _formatMinutes(summary.duration),
              label: 'Duration',
            ),
            _StatTile(
              icon: Icons.check_circle_outline,
              value: '${summary.exerciseCount}',
              label: 'Exercises',
            ),
            _StatTile(
              icon: Icons.local_fire_department_outlined,
              value: '~$estimatedCalories',
              label: 'Est. Calories',
            ),
            _StatTile(
              icon: Icons.favorite_outline,
              value: '${summary.wellnessScore}',
              label: 'Wellness Score',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(Icons.local_fire_department, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  workoutStreak.currentStreak <= 1
                      ? 'Workout streak started — day 1'
                      : '${workoutStreak.currentStreak}-day workout streak',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Completed ${_formatTime(summary.completedAt)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'See Progress',
          icon: Icons.trending_up_rounded,
          onPressed: () => NavigationTabScope.of(
            context,
            listen: false,
          ).switchTo(AppTab.progress),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: onViewSession,
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text("View Today's Session"),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: colorScheme.primary, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
