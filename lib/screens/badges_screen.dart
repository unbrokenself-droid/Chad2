import 'package:flutter/material.dart';

import '../services/badge_scope.dart';
import '../widgets/badges/badge_tile.dart';
import '../widgets/shared/section_header.dart';
import '../widgets/shared/staggered_entrance.dart';

/// Width at which the badge grid switches from 2 to 3 columns.
const double _wideBreakpoint = 700;

/// Full-page grid of every achievement badge, locked and unlocked,
/// with live progress toward each one.
///
/// Reads through [BadgeScope], so unlocking a badge anywhere in the
/// app (a workout completed, a streak extended) updates this screen
/// immediately if it happens to be open.
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final badges = BadgeScope.of(context);
    final progress = badges.allProgress();
    final (unlocked, total) = badges.unlockedCount();

    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _wideBreakpoint;
            final columns = isWide ? 3 : 2;
            final horizontalPadding = isWide ? 32.0 : 20.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: CustomScrollView(
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
                          subtitle: '$unlocked of $total unlocked',
                          title: 'Achievements 🏅',
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        20,
                        horizontalPadding,
                        32,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.82,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return StaggeredEntrance(
                              index: index,
                              child: BadgeTile(progress: progress[index]),
                            );
                          },
                          childCount: progress.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
