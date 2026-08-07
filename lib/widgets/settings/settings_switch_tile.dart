import 'package:flutter/material.dart';

import '../../services/accessibility_scope.dart';
import '../../utils/app_haptics.dart';
import '../shared/min_tap_target.dart' show kLargeTouchTargetSize;

/// A settings row with a trailing [Switch], for on/off preferences
/// that toggle in place rather than opening another screen.
///
/// Visually and structurally a sibling of [SettingsNavTile] — same
/// leading tinted icon circle, same title/subtitle column, same
/// minimum-height/padding handling (including respecting
/// `AccessibilityService.largeTouchTargets` the same way) — so the
/// two can be mixed inside one [SettingsSection] without the rows
/// looking inconsistent. The difference is the trailing control and
/// that the whole row toggles on tap, not just the switch.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  /// Icon shown in the leading tinted circle.
  final IconData icon;

  /// The row's label, e.g. 'Usage analytics'.
  final String title;

  /// Optional small line under [title] explaining what the toggle
  /// does. Worth filling in for anything privacy-related, where "what
  /// exactly am I agreeing to" is the whole question.
  final String? subtitle;

  final bool value;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtitleText = subtitle;
    final semanticParts = [title, if (subtitleText != null) subtitleText];
    final largeTargets = AccessibilityScope.of(context).largeTouchTargets;
    final verticalPadding = largeTargets ? 16.0 : 12.0;
    final minHeight = largeTargets ? 68.0 : kLargeTouchTargetSize;

    return Semantics(
      toggled: value,
      label: semanticParts.join('. '),
      child: InkWell(
        onTap: () {
          AppHaptics.selection();
          onChanged(!value);
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
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: value,
                    onChanged: (next) {
                      AppHaptics.selection();
                      onChanged(next);
                    },
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
