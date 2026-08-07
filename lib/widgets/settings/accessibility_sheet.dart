import 'package:flutter/material.dart';

import '../../services/accessibility_scope.dart';
import '../../services/accessibility_service.dart';
import '../shared/min_tap_target.dart' show kLargeTouchTargetSize;

/// Opens the accessibility preferences bottom sheet.
///
/// Convenience wrapper around [showModalBottomSheet], matching how
/// [showThemeModeSheet] and [showReminderSheet] are exposed, so
/// Settings doesn't need to know the sheet's shape/styling details.
Future<void> showAccessibilitySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const AccessibilitySheet(),
  );
}

/// Bottom sheet offering every accessibility preference: text size,
/// high contrast, reduce motion, and larger touch targets.
///
/// Reads and writes through [AccessibilityScope], so every change
/// here takes effect immediately and everywhere — the whole app
/// rebuilds under the new [MediaQuery]/[ThemeData], and the choice is
/// persisted so it survives a restart. The sheet's own rows already
/// use full-width 48dp-minimum touch targets and screen-reader
/// labels, so it reflects the settings it controls.
class AccessibilitySheet extends StatelessWidget {
  const AccessibilitySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accessibility = AccessibilityScope.of(context);

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.accessibility_new,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accessibility',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Make ChadMate easier to see and use',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TEXT SIZE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final scale in AppTextScale.values) ...[
                      _TextScaleOption(
                        scale: scale,
                        selected: scale == accessibility.textScale,
                        onTap: () => accessibility.setTextScale(scale),
                      ),
                      if (scale != AppTextScale.values.last)
                        const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'DISPLAY & MOTION',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AccessibilitySwitchRow(
                      icon: Icons.contrast,
                      title: 'High Contrast',
                      subtitle:
                          'Stronger borders and pure black/white text',
                      value: accessibility.highContrast,
                      onChanged: accessibility.setHighContrast,
                    ),
                    const SizedBox(height: 10),
                    _AccessibilitySwitchRow(
                      icon: Icons.motion_photos_off_outlined,
                      title: 'Reduce Motion',
                      subtitle:
                          'Minimize animations and screen transitions',
                      value: accessibility.reduceMotion,
                      onChanged: accessibility.setReduceMotion,
                    ),
                    const SizedBox(height: 10),
                    _AccessibilitySwitchRow(
                      icon: Icons.touch_app_outlined,
                      title: 'Larger Touch Targets',
                      subtitle:
                          'Increase the minimum size of buttons and controls',
                      value: accessibility.largeTouchTargets,
                      onChanged: accessibility.setLargeTouchTargets,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single selectable text-scale option, matching the swatch-card
/// style of [ThemeModeSheet]'s `_ThemeModeOption`, with a live
/// "Aa" preview sized proportionally to the option's multiplier.
class _TextScaleOption extends StatelessWidget {
  const _TextScaleOption({
    required this.scale,
    required this.selected,
    required this.onTap,
  });

  final AppTextScale scale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final largeTargets = AccessibilityScope.of(context).largeTouchTargets;
    final verticalPadding = largeTargets ? 16.0 : 12.0;

    return Semantics(
      button: true,
      selected: selected,
      label: '${scale.label}. ${scale.description}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: kLargeTouchTargetSize),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? colorScheme.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Text(
                      'Aa',
                      style: TextStyle(
                        fontSize: 16 * scale.multiplier,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scale.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scale.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: selected ? 1 : 0,
                  child: Icon(Icons.check_circle, color: colorScheme.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-width switch row for a single accessibility toggle.
///
/// Wired directly to a real, persisted [AccessibilityService] value,
/// always uses a 48dp-minimum tap target regardless of the "Larger
/// Touch Targets" setting itself, and exposes a merged [Semantics]
/// label so screen readers announce the whole row as one control.
class _AccessibilitySwitchRow extends StatelessWidget {
  const _AccessibilitySwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final largeTargets = AccessibilityScope.of(context).largeTouchTargets;
    final verticalPadding = largeTargets ? 16.0 : 8.0;

    return Semantics(
      toggled: value,
      label: '$title. $subtitle',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: kLargeTouchTargetSize),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: verticalPadding),
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
                  const SizedBox(width: 14),
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
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(value: value, onChanged: onChanged),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
