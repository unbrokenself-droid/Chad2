import 'package:flutter/material.dart';

/// A rounded card that groups related settings rows under one
/// heading, with a thin divider drawn between consecutive [children].
///
/// Purely presentational — layout only. Each item in [children] is
/// typically a `SettingsNavTile`, but any widget works.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  /// The section's heading, e.g. 'Preferences' or 'About'.
  final String title;

  /// The rows shown inside the card, separated by dividers.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Material(
          color: colorScheme.surfaceContainerHighest,
          elevation: 2,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.35),
          surfaceTintColor: colorScheme.surfaceTint,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 68,
                    color: theme.dividerColor,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
