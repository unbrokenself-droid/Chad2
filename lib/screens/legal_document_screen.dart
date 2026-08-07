import 'package:flutter/material.dart';

import '../models/legal_document.dart';

/// Renders a single [LegalDocument] — used for both the Privacy
/// Policy and Terms of Service, pushed from their respective rows in
/// Settings.
///
/// Content is wrapped in a [SelectionArea] so the whole document
/// (heading, intro, every section) is selectable/copyable — a small
/// but deliberate accommodation for legal text specifically, which
/// people reasonably want to quote, save, or paste elsewhere.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            final horizontalPadding = isWide ? 32.0 : 20.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SelectionArea(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      32,
                    ),
                    children: [
                      Text(
                        'Last updated: ${document.lastUpdated}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        document.intro,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.45,
                        ),
                      ),
                      for (final section in document.sections) ...[
                        const SizedBox(height: 26),
                        Text(
                          section.heading,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (section.body != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            section.body!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ],
                        if (section.bullets.isNotEmpty) ...[
                          SizedBox(height: section.body != null ? 10 : 8),
                          for (final bullet in section.bullets)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 2,
                                      right: 10,
                                    ),
                                    child: Icon(
                                      Icons.circle,
                                      size: 5,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      bullet,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(height: 1.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
