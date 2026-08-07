import 'package:flutter/material.dart';

import '../../services/narration_settings_scope.dart';

/// Opens the narration settings bottom sheet.
///
/// Convenience wrapper around [showModalBottomSheet], matching how
/// [showUnitsSheet] and [showThemeModeSheet] are exposed, so Settings
/// doesn't need to know the sheet's shape/styling details.
Future<void> showNarrationSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const NarrationSettingsSheet(),
  );
}

/// Bottom sheet offering speech rate, pitch, and volume sliders for
/// [ExerciseNarrationControls]'s spoken instructions.
///
/// Reads and writes through [NarrationSettingsScope], so a change here
/// applies from the *next* narrated segment onward — including one
/// already in progress elsewhere in the app — and persists across
/// restarts. Purely a settings surface: it has no player of its own,
/// so there's no way to preview a change without leaving this sheet
/// and starting narration on an exercise.
class NarrationSettingsSheet extends StatelessWidget {
  const NarrationSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = NarrationSettingsScope.of(context);

    return SafeArea(
      child: Container(
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
                    Icons.record_voice_over_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice & Narration',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'How exercise instructions are read aloud',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: settings.resetToDefaults,
                  icon: const Icon(Icons.restart_alt),
                  tooltip: 'Reset to defaults',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _VoiceGuideToggle(
              enabled: settings.narrationEnabled,
              onChanged: settings.setNarrationEnabled,
            ),
            const SizedBox(height: 4),
            _NarrationSlider(
              label: 'Speech rate',
              icon: Icons.speed_outlined,
              value: settings.speechRate,
              min: 0.0,
              max: 1.0,
              valueLabel: _percentLabel(settings.speechRate),
              onChanged: settings.setSpeechRate,
            ),
            _NarrationSlider(
              label: 'Pitch',
              icon: Icons.graphic_eq,
              value: settings.pitch,
              min: 0.5,
              max: 2.0,
              valueLabel: settings.pitch.toStringAsFixed(2),
              onChanged: settings.setPitch,
            ),
            _NarrationSlider(
              label: 'Volume',
              icon: Icons.volume_up_outlined,
              value: settings.volume,
              min: 0.0,
              max: 1.0,
              valueLabel: _percentLabel(settings.volume),
              onChanged: settings.setVolume,
            ),
          ],
        ),
      ),
    );
  }

  static String _percentLabel(double value) => '${(value * 100).round()}%';
}

/// The "Voice Guide" on/off row — separate from the three sliders
/// below it, since rate/pitch/volume stay adjustable even while
/// narration itself is off, so a preferred setup is already dialed
/// in whenever it's switched back on.
class _VoiceGuideToggle extends StatelessWidget {
  const _VoiceGuideToggle({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          Icons.hearing_outlined,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Voice Guide',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Switch(value: enabled, onChanged: onChanged),
      ],
    );
  }
}

/// A single labeled slider row, styled to match [NarrationSettingsSheet]'s
/// other rows rather than a bare default [Slider].
class _NarrationSlider extends StatelessWidget {
  const _NarrationSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                valueLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 4),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
