import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../../services/exercise_repository.dart';
import '../../widgets/ads/adaptive_banner_ad.dart';
import '../../widgets/shared/fade_through_page_route.dart';
import '../calendar_screen.dart';
import 'tabs/history_tab.dart';
import 'tabs/insights_tab.dart';
import 'tabs/this_week_tab.dart';

/// Progress tab: the app's single "how am I doing" destination.
///
/// Presents three tabs sharing one [AppBar] and background, rather
/// than three separately-navigated screens that read the same
/// underlying data:
///
///  * [ThisWeekTab] — a live snapshot: current streaks, this week's
///    totals, the weekly activity calendar, and this week's
///    day-by-day exercise/hydration charts.
///  * [HistoryTab] — the longer view: wellness score history, active
///    days per week, and monthly consistency, each over a window
///    longer than a single week.
///  * [InsightsTab] — plain-language findings derived from the same
///    history, distinct in kind (interpretation, not more numbers)
///    from the other two tabs.
///
/// Before this, `ProgressScreen` was a bottom-nav tab with
/// `StatisticsScreen` and `InsightsScreen` each pushed as separate
/// full-screen routes from icon buttons in its header (icon-only on
/// narrow layouts, labeled on wide ones) — three peer-level pages
/// with overlapping content and no obvious first stop. Most visibly,
/// the old Progress and Statistics screens each independently showed
/// this week's exercise-minutes chart and the hydration/skincare/
/// overall streak figures. Folding all three into one tabbed
/// destination removes that duplication (each figure now has exactly
/// one home) and gives a first-time user one obvious place to check
/// on their progress. The Calendar screen — a different task, "look
/// up a specific day," rather than "how am I doing" — stays a
/// separate destination, now reached from an [AppBar] action instead
/// of a same-row icon button.
///
/// The exercise catalog is loaded once here — mirroring how the
/// Exercises tab owns its own load — and handed down to the two tabs
/// that need it ([ThisWeekTab], [InsightsTab]; [HistoryTab] doesn't,
/// since none of its figures depend on exercise details, only on
/// which days had *any* completion). The three original screens each
/// loaded the catalog independently, so this also means it's now
/// parsed from disk once per app session rather than up to three
/// times.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  static const ExerciseRepository _repository = ExerciseRepository();

  late final TabController _tabController;
  List<Exercise> _allExercises = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadExercises();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    try {
      final exercises = await _repository.loadExercises();
      if (!mounted) return;
      setState(() => _allExercises = exercises);
    } catch (_) {
      // Swallow load errors here: the Exercises tab already surfaces
      // a proper error state with retry, so the tabs below just stay
      // at zero/empty rather than duplicating that handling.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      bottomNavigationBar: const AdaptiveBannerAd(),
      appBar: AppBar(
        title: const Text('Progress'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              FadeThroughPageRoute<void>(
                builder: (_) => const CalendarScreen(),
              ),
            ),
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Calendar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'This Week'),
            Tab(text: 'History'),
            Tab(text: 'Insights'),
          ],
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.4],
            colors: [
              Color.lerp(colorScheme.surface, colorScheme.primary, 0.05)!,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: TabBarView(
            controller: _tabController,
            children: [
              ThisWeekTab(allExercises: _allExercises),
              const HistoryTab(),
              InsightsTab(allExercises: _allExercises),
            ],
          ),
        ),
      ),
    );
  }
}
