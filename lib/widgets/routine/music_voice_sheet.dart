import 'package:flutter/material.dart';

import '../../services/background_music_scope.dart';
import '../../services/background_music_service.dart';
import '../../services/narration_settings_scope.dart';
import '../../services/narration_settings_service.dart';
import '../../screens/music_playlist_screen.dart';

/// Opens the Music & Voice bottom sheet.
///
/// Convenience wrapper around [showModalBottomSheet], matching how
/// [showNarrationSettingsSheet]/[showUnitsSheet] are exposed, so
/// [WorkoutSessionScreen] doesn't need to know this sheet's shape or
/// styling details.
Future<void> showMusicVoiceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const MusicVoiceSheet(),
  );
}

/// Lets the user control background music and spoken instructions
/// without leaving an active workout session — reachable from
/// [WorkoutExerciseView]'s app bar.
///
/// Reads and writes through [BackgroundMusicScope] and
/// [NarrationSettingsScope] directly, the same two services
/// [WorkoutSessionManager] itself was constructed with — so a change
/// made here (pausing music, muting the voice guide, skipping a
/// track) takes effect on the very same session immediately, not on
/// some separate copy of the settings.
class MusicVoiceSheet extends StatelessWidget {
  const MusicVoiceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final music = BackgroundMusicScope.of(context);
    final narration = NarrationSettingsScope.of(context);

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
            Text(
              'Music & Voice',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            _BackgroundMusicSection(music: music),
            const SizedBox(height: 24),
            Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            _VoiceGuideSection(narration: narration),
          ],
        ),
      ),
    );
  }
}

class _BackgroundMusicSection extends StatelessWidget {
  const _BackgroundMusicSection({required this.music});

  final BackgroundMusicService music;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.music_note_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Background Music',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Switch(value: music.enabled, onChanged: music.setEnabled),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      music.currentTrack.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const MusicPlaylistScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.queue_music_rounded),
                    tooltip: 'Playlist',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: music.enabled ? music.skipPrevious : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  IconButton.filled(
                    onPressed: !music.enabled
                        ? null
                        : music.isPlaying
                        ? music.pause
                        : music.resume,
                    icon: Icon(
                      music.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  IconButton(
                    onPressed: music.enabled ? music.skipNext : null,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.volume_down_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  Expanded(
                    child: Slider(
                      value: music.volume,
                      onChanged: music.enabled ? music.setVolume : null,
                    ),
                  ),
                  Icon(
                    Icons.volume_up_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VoiceGuideSection extends StatelessWidget {
  const _VoiceGuideSection({required this.narration});

  final NarrationSettingsService narration;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voice Guide',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Takes effect next session',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: narration.narrationEnabled,
          onChanged: narration.setNarrationEnabled,
        ),
      ],
    );
  }
}
