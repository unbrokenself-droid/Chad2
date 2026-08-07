import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../models/workout_collection.dart';
import '../services/completion_scope.dart';
import '../services/exercise_repository.dart';
import '../services/favorites_scope.dart';
import '../widgets/ads/adaptive_banner_ad.dart';
import '../widgets/exercises/category_filter_chips.dart';
import '../widgets/exercises/exercise_card.dart';
import '../widgets/exercises/exercise_search_bar.dart';
import '../widgets/exercises/workout_collection_card.dart';
import '../widgets/exercises/workout_unlock_sheet.dart';
import '../widgets/shared/fade_through_page_route.dart';
import '../widgets/shared/primary_button.dart';
import '../widgets/shared/progress_chip.dart';
import '../widgets/shared/section_header.dart';
import '../widgets/shared/staggered_entrance.dart';
import 'exercise_details_screen.dart';
import 'workout_collection_details_screen.dart';
import 'workout_session_screen.dart';

/// Exercises tab.
///
/// Above the exercise library sits a premium discovery layer: a
/// horizontally-scrolling "Workout Collections" rail of nineteen
/// built-in, named programs (see [builtInWorkoutCollections]), each
/// resolved from the same catalog this screen already loads — no
/// separate data source, no hand-picked exercise ids baked in here.
/// A row of filter chips (Featured, the three difficulty tiers, and
/// three duration bands) narrows which collections the rail shows.
/// Tapping a card opens [WorkoutCollectionDetailsScreen]; its "Start"
/// button skips straight to [WorkoutSessionScreen], the same screen
/// [RoutineScreen]'s "Start Routine" uses — see
/// [WorkoutCollection]'s doc comment for why that one reuse is what
/// gives every collection progressive overload, completion tracking,
/// favorites, and statistics for free.
///
/// Below that, the "Exercise Library" is unchanged from before this
/// was added: every exercise from the app's catalog as an
/// [ExerciseCard], laid out responsively — a single-column list on
/// narrow (phone portrait) widths, and a multi-column grid as the
/// available width grows, so the same content reflows sensibly on
/// tablets and in landscape. Tapping a card opens
/// [ExerciseDetailsScreen] for that exercise.
///
/// A search bar filters the catalog in real time by title, body part,
/// or description (case-insensitive, matched anywhere in the text).
/// A row of Material 3 [FilterChip]s lets the user additionally narrow
/// by [ExerciseCategory] (multiple categories can be active at once,
/// combined with OR); search and category filters combine with AND,
/// so e.g. searching "release" while "Jaw" is selected only shows jaw
/// exercises whose text mentions "release". Filtering runs against the
/// already-loaded in-memory list, so it's just a synchronous list scan
/// on every keystroke or chip tap — cheap enough for a catalog this
/// size to stay smooth with no debouncing needed. Neither the search
/// bar nor the category chips affect the Workout Collections rail
/// above — that has its own, separate filter row.
///
/// Just below the filter chips, a horizontally-scrolling "Favorites"
/// rail gives one-tap access to whatever the user has favorited via
/// [FavoriteHeartButton] on an [ExerciseCard] or the details screen.
/// It always reflects the full favorites list — unaffected by the
/// active search/category filters — and simply disappears when there
/// are no favorites yet, so it never demands its own empty state.
///
/// The catalog is read from the bundled `assets/exercises.json` asset
/// via [ExerciseRepository], asynchronously, as soon as this widget is
/// first built (which — because [MainNavigationScreen] keeps every
/// tab alive in an [IndexedStack] — happens right at app startup, not
/// only when the user switches to this tab). While that load is in
/// flight a loading state is shown; if it fails, an error state offers
/// a retry.
class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  static const ExerciseRepository _repository = ExerciseRepository();

  late Future<List<Exercise>> _exercisesFuture;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Set<ExerciseCategory> _selectedCategories = <ExerciseCategory>{};
  bool _favoritesOnly = false;
  WorkoutCollectionFilter? _activeCollectionFilter;

  @override
  void initState() {
    super.initState();
    _exercisesFuture = _repository.loadExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _exercisesFuture = _repository.loadExercises();
    });
  }

  void _handleSearchChanged(String value) {
    // Normalized once here rather than per-exercise inside the filter,
    // and only triggers a rebuild when the *normalized* query actually
    // changes (e.g. trailing whitespace or a caps-lock keystroke won't
    // cause an extra filter pass).
    final normalized = value.trim().toLowerCase();
    if (normalized == _query) return;
    setState(() {
      _query = normalized;
    });
  }

  void _handleCategoryToggled(ExerciseCategory category, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedCategories.add(category);
      } else {
        _selectedCategories.remove(category);
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _query = '';
      _selectedCategories.clear();
      _favoritesOnly = false;
    });
    _searchController.clear();
  }

  void _handleFavoritesOnlyChanged(bool value) {
    setState(() {
      _favoritesOnly = value;
    });
  }

  void _toggleCollectionFilter(WorkoutCollectionFilter filter) {
    setState(() {
      _activeCollectionFilter = _activeCollectionFilter == filter
          ? null
          : filter;
    });
  }

  /// Resolves every [builtInWorkoutCollections] definition against
  /// [catalog] — see [resolveWorkoutCollection] — dropping any that
  /// resolved to nothing (only possible if the catalog is missing
  /// entire categories a definition depends on, not a case that comes
  /// up with the current bundled catalog, but a graceful fallback
  /// costs nothing to keep). Recomputed on every build rather than
  /// cached: resolving nineteen small, fixed-size lists against a
  /// fifty-exercise catalog is cheap enough that caching would just
  /// be complexity for no measurable benefit.
  List<WorkoutCollection> _resolveCollections(List<Exercise> catalog) {
    return [
      for (final definition in builtInWorkoutCollections)
        WorkoutCollection(
          definition: definition,
          exercises: resolveWorkoutCollection(catalog, definition),
        ),
    ].where((collection) => collection.exercises.isNotEmpty).toList();
  }

  bool _matchesCollectionFilter(
    WorkoutCollection collection,
    WorkoutCollectionFilter filter,
  ) {
    final totalMinutes = collection.totalDuration.inMinutes;
    switch (filter) {
      case WorkoutCollectionFilter.featured:
        return collection.featured;
      case WorkoutCollectionFilter.beginner:
        return collection.tier == WorkoutCollectionTier.beginner;
      case WorkoutCollectionFilter.intermediate:
        return collection.tier == WorkoutCollectionTier.intermediate;
      case WorkoutCollectionFilter.advanced:
        return collection.tier == WorkoutCollectionTier.advanced;
      case WorkoutCollectionFilter.quick:
        return totalMinutes < 10;
      case WorkoutCollectionFilter.medium:
        return totalMinutes >= 10 && totalMinutes < 20;
      case WorkoutCollectionFilter.long:
        return totalMinutes >= 20;
    }
  }

  void _openCollectionDetails(WorkoutCollection collection) {
    Navigator.of(context).push(
      FadeThroughPageRoute(
        builder: (context) =>
            WorkoutCollectionDetailsScreen(collection: collection),
      ),
    );
  }

  void _startCollection(WorkoutCollection collection) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            WorkoutSessionScreen(exercises: collection.exercises),
      ),
    );
  }

  /// Returns the subset of [exercises] whose title, body part label,
  /// or description contains the current search query, AND — if any
  /// category chips are selected — whose category is one of them, AND
  /// — if the Favorites chip is active — that are currently favorited.
  ///
  /// Case-insensitive and matches anywhere in the text (not just at
  /// the start), so e.g. searching "jaw" surfaces both an exercise
  /// titled "Jaw Release Drop" and one merely targeting the jawline.
  List<Exercise> _filterExercises(
    List<Exercise> exercises,
    Set<String> favoriteIds,
  ) {
    return exercises.where((exercise) {
      final matchesQuery = _query.isEmpty ||
          exercise.title.toLowerCase().contains(_query) ||
          exercise.bodyPart.label.toLowerCase().contains(_query) ||
          exercise.description.toLowerCase().contains(_query);
      final matchesCategory = _selectedCategories.isEmpty ||
          _selectedCategories.contains(exercise.category);
      final matchesFavorites =
          !_favoritesOnly || favoriteIds.contains(exercise.id);
      return matchesQuery && matchesCategory && matchesFavorites;
    }).toList(growable: false);
  }

  /// Returns [allExercises] filtered down to just the ones in
  /// [favoriteIds], preserving catalog order. Used by the standalone
  /// "Favorites" rail, which — unlike the main list — always shows
  /// favorited exercises regardless of the active search/category
  /// filters, so it stays a reliable quick-access shortcut.
  List<Exercise> _favoritedExercises(
    List<Exercise> allExercises,
    Set<String> favoriteIds,
  ) {
    if (favoriteIds.isEmpty) return const [];
    return allExercises
        .where((exercise) => favoriteIds.contains(exercise.id))
        .toList(growable: false);
  }

  /// Chooses a column count from the available width. Kept as plain
  /// breakpoints (rather than a fixed tile width) so the grid always
  /// resolves to a whole number of columns instead of leaving an
  /// awkward sliver of empty space on the trailing edge.
  int _columnsForWidth(double width) {
    if (width >= 1100) return 3;
    if (width >= 700) return 2;
    return 1;
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Semantics has no const constructor, so this subtree
            // can't be const as a whole — the leaves still are.
            Semantics(
              label: 'Loading exercises',
              child: const CircularProgressIndicator(),
            ),
            const SizedBox(height: 16),
            const Text('Loading exercises…'),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    final theme = Theme.of(context);
    final message = error is ExerciseLoadException
        ? error.message
        : 'Something went wrong loading the exercise library.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              "Couldn't load exercises",
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 160,
              child: PrimaryButton(label: 'Try Again', onPressed: _retry),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown in place of the exercise list/grid when a search query
  /// and/or category filter is active but matches nothing, so an
  /// empty result reads as "no matches" rather than looking like a
  /// loading glitch or a bug.
  Widget _buildNoResults(BuildContext context) {
    final theme = Theme.of(context);
    final message = _favoritesOnly && _query.isEmpty
        ? "You haven't favorited any exercises yet."
        : 'Try a different keyword or category.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _favoritesOnly ? Icons.favorite_border : Icons.search_off,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No exercises found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 160,
              child: PrimaryButton(
                label: 'Clear Filters',
                onPressed: _clearFilters,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Exercise> allExercises) {
    final theme = Theme.of(context);
    final favoriteIds = FavoritesScope.of(context).favoriteIds;
    final completion = CompletionScope.of(context);
    final exercises = _filterExercises(allExercises, favoriteIds);
    final favoritedExercises = _favoritedExercises(allExercises, favoriteIds);
    final allCollections = _resolveCollections(allExercises);
    final activeCollectionFilter = _activeCollectionFilter;
    final visibleCollections = activeCollectionFilter == null
        ? allCollections
        : allCollections
            .where((c) => _matchesCollectionFilter(c, activeCollectionFilter))
            .toList();
    final hasActiveFilters = _query.isNotEmpty ||
        _selectedCategories.isNotEmpty ||
        _favoritesOnly;

    // Each catalog [Exercise] is loaded with `completed: false` — the
    // catalog itself has no notion of "today". This overlays today's
    // real completion state from [CompletionScope] so [ExerciseCard]'s
    // completed ring/badge reflects what the user has actually
    // finished today, and updates instantly wherever it's toggled.
    Exercise withTodaysCompletion(Exercise exercise) {
      return exercise.copyWith(
        completed: completion.isCompletedToday(exercise.id),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = width >= 700;
        final horizontalPadding = isWide ? 32.0 : 20.0;
        final columns = _columnsForWidth(width);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: CustomScrollView(
              // Keying the scroll view to the combined filter state
              // means switching in/out of the "no results" sliver (a
              // very differently-shaped subtree) doesn't try to reuse
              // scroll offset or element state across that swap.
              key: ValueKey(hasActiveFilters && exercises.isEmpty),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    20,
                    horizontalPadding,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(
                      size: SectionHeaderSize.large,
                      subtitle: 'Exercises',
                      title: hasActiveFilters
                          ? '${exercises.length} of ${allExercises.length} match'
                          : '${allExercises.length} in your library',
                      trailing: Icon(
                        Icons.fitness_center_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: ExerciseSearchBar(
                      controller: _searchController,
                      onChanged: _handleSearchChanged,
                    ),
                  ),
                ),
                // Premium discovery layer sitting above the exercise
                // library, not a replacement for it — every card here
                // just points at a curated subset of the same catalog
                // the library below shows in full. See
                // WorkoutCollection's doc comment for why starting one
                // needs no tracking logic of its own: it reuses
                // WorkoutSessionScreen end to end.
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(
                      size: SectionHeaderSize.medium,
                      title: 'Workout Collections',
                      trailing: Icon(
                        Icons.auto_awesome_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 40,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 8,
                      ),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: WorkoutCollectionFilter.values.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final filter = WorkoutCollectionFilter.values[index];
                        final selected = _activeCollectionFilter == filter;
                        return FilterChip(
                          label: Text(filter.label),
                          selected: selected,
                          onSelected: (_) => _toggleCollectionFilter(filter),
                          showCheckmark: false,
                        );
                      },
                    ),
                  ),
                ),
                if (visibleCollections.isEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      12,
                      horizontalPadding,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'No collections match this filter.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 280,
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 12,
                        ),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: visibleCollections.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final collection = visibleCollections[index];
                          return WorkoutCollectionCard(
                            collection: collection,
                            onTap: () => _openCollectionDetails(collection),
                            onStart: () => _startCollection(collection),
                            onUnlockRequested: () =>
                                showWorkoutUnlockSheet(
                                  context,
                                  collection: collection,
                                ),
                          );
                        },
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    28,
                    horizontalPadding,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(
                      size: SectionHeaderSize.medium,
                      title: 'Exercise Library',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: CategoryFilterChips(
                      selected: _selectedCategories,
                      onChanged: _handleCategoryToggled,
                      favoritesOnly: _favoritesOnly,
                      onFavoritesOnlyChanged: _handleFavoritesOnlyChanged,
                    ),
                  ),
                ),
                // Quick-access rail of favorited exercises. Always
                // reflects the full favorites list regardless of the
                // active search/category filters above (favoriting is
                // meant to be a shortcut you can rely on), and simply
                // disappears once there are no favorites rather than
                // showing an empty-state placeholder here — the "no
                // favorites yet" messaging already lives in the
                // Favorites chip's empty state.
                if (favoritedExercises.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: SectionHeader(
                        size: SectionHeaderSize.medium,
                        title: 'Favorites',
                        trailing: ProgressChip(
                          icon: Icons.favorite,
                          label: '${favoritedExercises.length}',
                          foregroundColor: const Color(0xFFE0435B),
                        ),
                      ),
                    ),
                  ),
                if (favoritedExercises.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 148,
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 12,
                        ),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: favoritedExercises.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final exercise = favoritedExercises[index];
                          return SizedBox(
                            width: 280,
                            child: ExerciseCard(
                              exercise: withTodaysCompletion(exercise),
                              onTap: () => Navigator.of(context).push(
                                FadeThroughPageRoute(
                                  builder: (context) =>
                                      ExerciseDetailsScreen(
                                    exercise: exercise,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (exercises.isEmpty)
                  SliverToBoxAdapter(child: _buildNoResults(context))
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      32,
                    ),
                    sliver: columns == 1
                        ? SliverList.separated(
                            itemCount: exercises.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final exercise = exercises[index];
                              return StaggeredEntrance(
                                index: index,
                                child: ExerciseCard(
                                  exercise: withTodaysCompletion(exercise),
                                  onTap: () => Navigator.of(context).push(
                                    FadeThroughPageRoute(
                                      builder: (context) =>
                                          ExerciseDetailsScreen(
                                        exercise: exercise,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              // Wide cards read comfortably at this
                              // aspect ratio without clipping the
                              // difficulty/completed badge row.
                              childAspectRatio: columns == 2 ? 2.4 : 2.0,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final exercise = exercises[index];
                                return StaggeredEntrance(
                                  index: index,
                                  child: ExerciseCard(
                                    exercise: withTodaysCompletion(exercise),
                                    onTap: () => Navigator.of(context).push(
                                      FadeThroughPageRoute(
                                        builder: (context) =>
                                            ExerciseDetailsScreen(
                                          exercise: exercise,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: exercises.length,
                            ),
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AdaptiveBannerAd(),
      body: SafeArea(
        child: FutureBuilder<List<Exercise>>(
          future: _exercisesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _buildLoading(context);
            }
            if (snapshot.hasError) {
              return _buildError(context, snapshot.error!);
            }
            return _buildContent(context, snapshot.data ?? const []);
          },
        ),
      ),
    );
  }
}
