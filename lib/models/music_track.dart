/// A single bundled background-music track available during a workout
/// session.
class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.duration,
  });

  /// Stable identifier, persisted as the user's last-selected track —
  /// see [BackgroundMusicService]. Kept separate from [assetPath] so
  /// the bundled file could be moved/renamed without invalidating
  /// anyone's saved selection, the same reasoning [Exercise.id] is
  /// kept separate from its own asset paths.
  final String id;

  /// Shown in [MusicVoiceSheet] and [MusicPlaylistScreen].
  final String title;

  /// Bundled asset path, e.g. `'assets/music/balanced_breath.mp3'`.
  final String assetPath;

  /// The track's own length — every bundled track is under a minute,
  /// meant to be looped continuously for the length of a workout
  /// rather than played once, not trimmed or extended to match any
  /// particular session's length.
  final Duration duration;
}

/// Every background-music track bundled with the app.
///
/// A plain const list rather than a JSON catalog like
/// `assets/exercises.json` — deliberately: four tracks with three
/// plain fields each doesn't carry its weight as a separate data
/// file the way fifty exercises with instructions/precautions/etc.
/// does. If this list grows substantially, moving it to JSON the same
/// way would be a reasonable follow-up.
const List<MusicTrack> bundledMusicTracks = [
  MusicTrack(
    id: 'balanced-breath',
    title: 'Balanced Breath',
    assetPath: 'assets/music/balanced_breath.mp3',
    duration: Duration(seconds: 55),
  ),
  MusicTrack(
    id: 'measured-breath',
    title: 'Measured Breath',
    assetPath: 'assets/music/measured_breath.mp3',
    duration: Duration(seconds: 55),
  ),
  MusicTrack(
    id: 'open-window-morning',
    title: 'Open Window Morning',
    assetPath: 'assets/music/open_window_morning.mp3',
    duration: Duration(seconds: 58),
  ),
  MusicTrack(
    id: 'sunlight-on-water',
    title: 'Sunlight on Water',
    assetPath: 'assets/music/sunlight_on_water.mp3',
    duration: Duration(seconds: 56),
  ),
];
