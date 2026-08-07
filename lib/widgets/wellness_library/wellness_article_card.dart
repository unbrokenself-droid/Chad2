import 'package:flutter/material.dart';

import '../../models/wellness_article.dart';
import '../../services/library_bookmarks_scope.dart';
import '../../utils/app_haptics.dart';
import 'bookmark_button.dart';

/// A single article's card in the Wellness Library.
///
/// Collapsed, it shows the topic, title, summary, and read time.
/// Tapping anywhere on the card (or the chevron) expands it in place
/// to reveal the full body, broken into short headed [ArticleSection]s
/// — no navigation to a separate screen, so browsing the list and
/// reading an article stay on the same scroll position.
///
/// Bookmark state is read from [LibraryBookmarksScope] and toggled
/// via [LibraryBookmarksService.toggle]; all content is bundled with
/// the app, so both collapsed and expanded states render fully
/// offline.
class WellnessArticleCard extends StatefulWidget {
  const WellnessArticleCard({
    super.key,
    required this.article,
    this.initiallyExpanded = false,
  });

  final WellnessArticle article;

  /// Whether the card starts expanded, e.g. when it's the only result
  /// left after a specific search.
  final bool initiallyExpanded;

  @override
  State<WellnessArticleCard> createState() => _WellnessArticleCardState();
}

class _WellnessArticleCardState extends State<WellnessArticleCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded = widget.initiallyExpanded;

  void _toggleExpanded() {
    AppHaptics.selection();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final article = widget.article;
    final bookmarks = LibraryBookmarksScope.of(context);
    final isBookmarked = bookmarks.isBookmarked(article.id);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 280);

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggleExpanded,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      article.topic.icon,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.topic.label.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          article.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  BookmarkButton(
                    isBookmarked: isBookmarked,
                    onToggle: () => bookmarks.toggle(article.id),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.expand_more,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 46),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        article.summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: _expanded ? null : 2,
                        overflow: _expanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 46, top: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 13,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${article.readMinutes} min read',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: duration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(left: 46, top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(
                              height: 1,
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (var i = 0; i < article.sections.length; i++) ...[
                              if (i != 0) const SizedBox(height: 14),
                              Text(
                                article.sections[i].heading,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                article.sections[i].body,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.85,
                                  ),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
