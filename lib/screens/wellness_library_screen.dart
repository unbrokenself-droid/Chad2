import 'package:flutter/material.dart';

import '../data/wellness_library_content.dart';
import '../models/wellness_article.dart';
import '../services/library_bookmarks_scope.dart';
import '../widgets/exercises/exercise_search_bar.dart';
import '../widgets/shared/section_header.dart';
import '../widgets/shared/staggered_entrance.dart';
import '../widgets/wellness_library/topic_filter_chips.dart';
import '../widgets/wellness_library/wellness_article_card.dart';

/// A searchable, filterable library of short educational articles on
/// jaw relaxation, neck mobility, healthy posture, hydration, basic
/// skincare, and recovery.
///
/// All content is bundled with the app via
/// [WellnessLibraryContent.articles] — nothing is fetched over the
/// network — so the whole library, including expanded article bodies,
/// is readable offline. Articles render as [WellnessArticleCard]s
/// that expand in place when tapped, and can be bookmarked via
/// [LibraryBookmarksScope] for quick access later through the
/// "Bookmarked" filter chip.
///
/// Content throughout is educational and habit-focused rather than
/// medical or cosmetic advice — see the guidelines documented on
/// [WellnessLibraryContent].
class WellnessLibraryScreen extends StatefulWidget {
  const WellnessLibraryScreen({super.key});

  @override
  State<WellnessLibraryScreen> createState() => _WellnessLibraryScreenState();
}

class _WellnessLibraryScreenState extends State<WellnessLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Set<WellnessTopic> _selectedTopics = <WellnessTopic>{};
  bool _bookmarkedOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    setState(() => _query = value);
  }

  void _handleTopicChanged(WellnessTopic topic, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedTopics.add(topic);
      } else {
        _selectedTopics.remove(topic);
      }
    });
  }

  List<WellnessArticle> _filteredArticles(Set<String> bookmarkedIds) {
    return WellnessLibraryContent.articles.where((article) {
      if (_bookmarkedOnly && !bookmarkedIds.contains(article.id)) {
        return false;
      }
      if (_selectedTopics.isNotEmpty &&
          !_selectedTopics.contains(article.topic)) {
        return false;
      }
      return article.matches(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bookmarks = LibraryBookmarksScope.of(context);
    final filtered = _filteredArticles(bookmarks.bookmarkedIds);
    final hasActiveFilter =
        _query.isNotEmpty || _selectedTopics.isNotEmpty || _bookmarkedOnly;

    return Scaffold(
      appBar: AppBar(title: const Text('Wellness Library')),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.3],
            colors: [
              Color.lerp(colorScheme.surface, colorScheme.primary, 0.05)!,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              final horizontalPadding = isWide ? 32.0 : 20.0;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          16,
                          horizontalPadding,
                          12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(
                              subtitle: 'Learn at your own pace',
                              title: 'Short reads, saved for offline 📚',
                            ),
                            const SizedBox(height: 16),
                            ExerciseSearchBar(
                              controller: _searchController,
                              onChanged: _handleSearchChanged,
                              hintText: 'Search articles…',
                            ),
                            const SizedBox(height: 12),
                            TopicFilterChips(
                              selected: _selectedTopics,
                              onChanged: _handleTopicChanged,
                              bookmarkedOnly: _bookmarkedOnly,
                              onBookmarkedOnlyChanged: (value) {
                                setState(() => _bookmarkedOnly = value);
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? _EmptyState(
                                hasActiveFilter: hasActiveFilter,
                                bookmarkedOnly: _bookmarkedOnly,
                              )
                            : ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  4,
                                  horizontalPadding,
                                  32,
                                ),
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  return StaggeredEntrance(
                                    index: index,
                                    child: WellnessArticleCard(
                                      key: ValueKey(filtered[index].id),
                                      article: filtered[index],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
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

/// Shown when no article matches the current search/filter
/// combination, or when the "Bookmarked" filter is on but nothing has
/// been bookmarked yet.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasActiveFilter, required this.bookmarkedOnly});

  final bool hasActiveFilter;
  final bool bookmarkedOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final message = bookmarkedOnly
        ? 'Bookmark an article to find it here later.'
        : hasActiveFilter
        ? 'No articles match your search or filters.'
        : 'No articles available.';
    final icon = bookmarkedOnly ? Icons.bookmark_border : Icons.search_off;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
