import 'package:flutter/material.dart';

/// The type scale a [SectionHeader] renders at.
enum SectionHeaderSize {
  /// A large, page-level header: a muted [SectionHeader.subtitle] line
  /// above a bold headline [SectionHeader.title]. Suited to things
  /// like a greeting banner at the top of a screen.
  large,

  /// A compact header for labelling a section of content within a
  /// page, e.g. "Daily Reminders" above a list of cards.
  medium,
}

/// A reusable title block used to head a screen or a section of a
/// screen.
///
/// Purely presentational: text and an optional [trailing] widget (for
/// example a "See all" action) are supplied by the caller.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.size = SectionHeaderSize.medium,
  });

  /// The main heading text.
  final String title;

  /// Optional small, muted line shown above [title].
  final String? subtitle;

  /// Optional widget shown at the end of the row (e.g. a "See all"
  /// button), vertically centered against the text.
  final Widget? trailing;

  /// Controls the type scale used for [title] and [subtitle].
  final SectionHeaderSize size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLarge = size == SectionHeaderSize.large;
    final subtitleText = subtitle;
    final trailingWidget = trailing;

    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (subtitleText != null) ...[
          Text(
            subtitleText,
            style:
                (isLarge
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodySmall)
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
        ],
        Text(
          title,
          style:
              (isLarge
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleMedium)
                  ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );

    if (trailingWidget == null) return textColumn;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: textColumn),
        const SizedBox(width: 12),
        trailingWidget,
      ],
    );
  }
}
