import 'package:flutter/material.dart';

import '../models/music_track.dart';
import '../services/background_music_scope.dart';
import '../utils/app_haptics.dart';

/// Lists every bundled background-music track ([bundledMusicTracks]),
/// reachable from [MusicVoiceSheet]'s queue icon.
///
/// Tapping a track selects it via
/// [BackgroundMusicService.selectTrack] and, if music is already
/// playing, switches to it immediately — the same service
/// [MusicVoiceSheet] itself reads and writes, so returning to that
/// sheet after picking a track here shows the new selection right
/// away.
///
/// Doesn't offer importing the user's own audio — the bundled four
/// tracks are the whole library for now; see this app's docs/notes on
/// this screen if that's ever added, since local file playback needs
/// real device-storage permissions this app doesn't currently ask
/// for.
class MusicPlaylistScreen extends StatelessWidget {
  const MusicPlaylistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final music = BackgroundMusicScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Playlist')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: bundledMusicTracks.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final track = bundledMusicTracks[index];
            final isSelected = track.id == music.currentTrack.id;
            return _PlaylistTrackTile(
              track: track,
              selected: isSelected,
              playing: isSelected && music.isPlaying,
              onTap: () {
                AppHaptics.selection();
                music.selectTrack(track);
                if (!music.isPlaying) music.play();
              },
            );
          },
        ),
      ),
    );
  }
}

class _PlaylistTrackTile extends StatelessWidget {
  const _PlaylistTrackTile({
    required this.track,
    required this.selected,
    required this.playing,
    required this.onTap,
  });

  final MusicTrack track;
  final bool selected;
  final bool playing;
  final VoidCallback onTap;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.1)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.primary.withValues(alpha: 0.18)
                      : colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  playing ? Icons.equalizer_rounded : Icons.music_note_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  track.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? colorScheme.primary : colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(track.duration),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
