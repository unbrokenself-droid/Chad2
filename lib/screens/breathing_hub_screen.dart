import 'package:flutter/material.dart';

import '../models/breathing_pattern.dart';
import '../services/breathing_settings_scope.dart';
import '../utils/app_haptics.dart';
import '../widgets/shared/min_tap_target.dart';
import '../widgets/shared/section_header.dart';
import '../widgets/shared/staggered_entrance.dart';
import 'breathing_session_screen.dart';

/// Available session lengths offered on the breathing hub, in
/// minutes.
const List<int> _durationOptionsMinutes = [1, 3, 5, 10];

/// Entry point for guided breathing: pick one of the four bundled
/// [BreathingPatterns], a session length, and start a
/// [BreathingSessionScreen].
///
/// Defaults the pattern and duration selection to whatever
/// [BreathingSettingsService] last recorded, so a returning user sees
/// their usual choice pre-selected rather than starting over each
/// time.
class BreathingHubScreen extends StatefulWidget {
  const BreathingHubScreen({super.key});

  @override
  State<BreathingHubScreen> createState() => _BreathingHubScreenState();
}

class _BreathingHubScreenState extends State<BreathingHubScreen> {
  late BreathingPattern _selectedPattern;
  late int _selectedMinutes;
  bool _initializedFromSettings = false;

  @override
  void initState() {
    super.initState();
    _selectedPattern = BreathingPatterns.boxBreathing;
    _selectedMinutes = _durationOptionsMinutes[1];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromSettings) return;
    final settings = BreathingSettingsScope.of(context);
    if (!settings.isLoaded) return;
    _initializedFromSettings = true;
    final lastPattern = settings.lastPatternId == null
        ? null
        : BreathingPatterns.byId(settings.lastPatternId!);
    setState(() {
      if (lastPattern != null) _selectedPattern = lastPattern;
      if (_durationOptionsMinutes.contains(settings.lastDurationMinutes)) {
        _selectedMinutes = settings.lastDurationMinutes;
      }
    });
  }

  void _selectPattern(BreathingPattern pattern) {
    AppHaptics.selection();
    setState(() => _selectedPattern = pattern);
  }

  void _selectMinutes(int minutes) {
    AppHaptics.selection();
    setState(() => _selectedMinutes = minutes);
  }

  Future<void> _startSession(BuildContext context) async {
    AppHaptics.medium();
    final settings = BreathingSettingsScope.of(context);
    await settings.recordLastSession(
      patternId: _selectedPattern.id,
      durationMinutes: _selectedMinutes,
    );
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BreathingSessionScreen(
          pattern: _selectedPattern,
          totalDuration: Duration(minutes: _selectedMinutes),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = BreathingSettingsScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Guided Breathing')),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.3],
            colors: [
              Color.lerp(colorScheme.surface, _selectedPattern.color, 0.06)!,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              final horizontalPadding = isWide ? 32.0 : 20.0;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      16,
                      horizontalPadding,
                      32,
                    ),
                    children: [
                      const SectionHeader(
                        subtitle: 'A few slow breaths, whenever you need them',
                        title: 'Find your calm 🌬️',
                      ),
                      const SizedBox(height: 20),
                      SectionHeader(
                        title: 'Choose a pattern',
                        size: SectionHeaderSize.medium,
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < BreathingPatterns.all.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: StaggeredEntrance(
                            index: i,
                            child: _PatternCard(
                              pattern: BreathingPatterns.all[i],
                              selected:
                                  _selectedPattern == BreathingPatterns.all[i],
                              onTap: () =>
                                  _selectPattern(BreathingPatterns.all[i]),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      SectionHeader(
                        title: 'Session length',
                        size: SectionHeaderSize.medium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final minutes in _durationOptionsMinutes)
                            _DurationChip(
                              minutes: minutes,
                              selected: minutes == _selectedMinutes,
                              color: _selectedPattern.color,
                              onTap: () => _selectMinutes(minutes),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _VibrationToggleRow(
                        enabled: settings.vibrationEnabled,
                        onChanged: settings.isLoaded
                            ? (value) {
                                AppHaptics.selection();
                                settings.setVibrationEnabled(value);
                              }
                            : null,
                      ),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: () => _startSession(context),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          'Start ${_selectedPattern.title}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _selectedPattern.color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({
    required this.pattern,
    required this.selected,
    required this.onTap,
  });

  final BreathingPattern pattern;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: selected
          ? pattern.color.withValues(alpha: 0.12)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? pattern.color
                  : colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: pattern.color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(pattern.icon, color: pattern.color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pattern.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pattern.tagline,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? pattern.color : colorScheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.minutes,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Unlike CategoryFilterChips/TopicFilterChips, this chip has no
    // visualDensity or explicit height to adjust directly — it just
    // uses Material's own default chip sizing — so MinTapTarget's
    // external wrap is the right approach here, not a fallback.
    return MinTapTarget(
      child: ChoiceChip(
        label: Text('$minutes min'),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: color.withValues(alpha: 0.18),
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: selected ? color : colorScheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide(
          color: selected
              ? color
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _VibrationToggleRow extends StatelessWidget {
  const _VibrationToggleRow({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.vibration, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Vibration cues',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'A gentle pulse each time you switch phases',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}
