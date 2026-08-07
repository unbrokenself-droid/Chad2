import 'package:flutter/material.dart';

import '../../models/premium_feature.dart';
import '../../screens/upgrade_screen.dart';
import '../../services/premium_scope.dart';
import '../../services/theme_mode_scope.dart';
import '../../services/theme_mode_service.dart';

/// Opens the appearance/theme picker bottom sheet.
///
/// Convenience wrapper around [showModalBottomSheet], matching how
/// [showReminderSheet] and [showRestDaySheet] are exposed, so
/// Settings doesn't need to know the sheet's shape/styling details.
Future<void> showThemeModeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const ThemeModeSheet(),
  );
}

/// Small icon shown for each [AppThemeMode] in the picker and in
/// Settings' summary row.
IconData iconForThemeMode(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return Icons.light_mode;
    case AppThemeMode.dark:
      return Icons.dark_mode;
    case AppThemeMode.amoled:
      return Icons.nightlight;
    case AppThemeMode.system:
      return Icons.brightness_auto;
  }
}

/// Bottom sheet offering all four [AppThemeMode] options as tappable
/// swatch cards.
///
/// Reads and writes through [ThemeModeScope], so choosing a mode here
/// takes effect immediately and everywhere — the whole app rebuilds
/// under the new [ThemeData] with an animated cross-fade (see
/// `main.dart`'s `AnimatedTheme`), and the choice is persisted so it
/// survives a restart.
class ThemeModeSheet extends StatelessWidget {
  const ThemeModeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeService = ThemeModeScope.of(context);
    final currentMode = themeService.mode;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
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
                    Icons.palette_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appearance',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Choose how ChadMate looks',
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
                  children: [
                    for (final mode in AppThemeMode.values) ...[
                      _ThemeModeOption(
                        mode: mode,
                        selected: mode == currentMode,
                        locked: mode == AppThemeMode.amoled &&
                            !PremiumScope.of(
                              context,
                            ).isUnlocked(PremiumFeature.premiumThemes),
                        onTap: () {
                          final isLocked = mode == AppThemeMode.amoled &&
                              !PremiumScope.of(
                                context,
                              ).isUnlocked(PremiumFeature.premiumThemes);
                          if (isLocked) {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const UpgradeScreen(
                                  highlightFeature:
                                      PremiumFeature.premiumThemes,
                                  source: 'theme_gate',
                                ),
                              ),
                            );
                            return;
                          }
                          themeService.setMode(mode);
                        },
                      ),
                      if (mode != AppThemeMode.values.last)
                        const SizedBox(height: 10),
                    ],
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

/// A single selectable appearance option, showing a small live
/// swatch preview of that mode's palette alongside its label.
class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final AppThemeMode mode;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            _ThemeSwatch(mode: mode),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        mode.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (locked) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC8A1E).withValues(
                              alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock,
                                size: 10,
                                color: Color(0xFFDC8A1E),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'PREMIUM',
                                style: TextStyle(
                                  color: Color(0xFFDC8A1E),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.description,
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
    );
  }
}

/// A small rounded preview swatch showing [mode]'s background and
/// accent colors, so the picker doesn't rely on label text alone to
/// communicate what each mode looks like.
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.mode});

  final AppThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (mode == AppThemeMode.system) {
      // Split swatch: half light, half dark, to communicate "follows
      // whichever the system is set to" without needing live OS
      // brightness detection just for a preview icon.
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.wb_sunny,
                    size: 14,
                    color: Color(0xFF2962FF),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.nightlight,
                    size: 14,
                    color: Color(0xFF2962FF),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final (background, accent, border) = switch (mode) {
      AppThemeMode.light => (
          Colors.white,
          const Color(0xFF2962FF),
          const Color(0xFFF2F2F2),
        ),
      AppThemeMode.dark => (
          const Color(0xFF1C1C1C),
          const Color(0xFF2962FF),
          const Color(0xFF2A2A2A),
        ),
      AppThemeMode.amoled => (
          Colors.black,
          const Color(0xFF2962FF),
          const Color(0xFF2A2A2A),
        ),
      // Unreachable: AppThemeMode.system returns early above via its
      // own split-swatch branch. Still handled here (rather than a
      // wildcard `_`) so this switch stays exhaustive and a future
      // AppThemeMode addition fails to compile here instead of
      // silently falling through.
      AppThemeMode.system => (
          colorScheme.surface,
          colorScheme.primary,
          colorScheme.outlineVariant,
        ),
    };

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
      ),
    );
  }
}
