import 'package:flutter/material.dart';

import '../../services/accessibility_scope.dart';
import '../../utils/app_haptics.dart';
import '../shared/min_tap_target.dart' show kLargeTouchTargetSize;

/// A tappable settings row: a leading icon, title, optional subtitle
/// or value, and a trailing chevron.
///
/// Used for rows that open another screen or sheet (Reminder Times,
/// Appearance, Rest Days, Accessibility) as well as a few rows that
/// don't have a destination yet (Units, About, Privacy Policy, Rate
/// App, Terms), which screens wire to a "Coming soon" [SnackBar]
/// instead. Every tap gives a light selection haptic regardless of
/// which kind of [onTap] it ends up calling.
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingText,
  });

  /// Icon shown in the leading tinted circle.
  final IconData icon;

  /// The row's label, e.g. 'Units'.
  final String title;

  /// Optional small line under [title], e.g. 'Terms of use and license'.
  final String? subtitle;

  /// Optional short value shown before the chevron, e.g. 'Metric'.
  final String? trailingText;

  /// Called when the row is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtitleText = subtitle;
    final trailingLabel = trailingText;
    final semanticParts = [
      title,
      if (subtitleText != null) subtitleText,
      if (trailingLabel != null) trailingLabel,
    ];
    final largeTargets = AccessibilityScope.of(context).largeTouchTargets;
    // The ConstrainedBox minHeight below is close to vestigial for
    // this row in practice — the 36px icon circle plus even the
    // smaller padding already clears it — so what actually needs to
    // grow for this setting to have any real effect is the padding
    // itself, not just the constraint number.
    final verticalPadding = largeTargets ? 16.0 : 12.0;
    final minHeight = largeTargets ? 68.0 : kLargeTouchTargetSize;

    return Semantics(
      button: true,
      label: semanticParts.join('. '),
      child: InkWell(
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: verticalPadding,
            ),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: colorScheme.primary, size: 18),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitleText != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitleText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailingLabel != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      trailingLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
