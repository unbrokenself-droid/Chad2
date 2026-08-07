import 'package:flutter/material.dart';

/// A single phase within one cycle of a [BreathingPattern], e.g. the
/// "inhale" or "hold" segment of a box-breathing cycle.
///
/// [BreathingSessionScreen] walks through a pattern's [BreathingPattern
/// .phases] in order, holding on each one for [seconds] before moving
/// to the next, and looping back to the first phase once the last one
/// finishes — until the overall session duration runs out.
@immutable
class BreathingPhase {
  const BreathingPhase({
    required this.type,
    required this.seconds,
  });

  /// What kind of phase this is — drives the label, animation target,
  /// and haptic cue used while it's active.
  final BreathingPhaseType type;

  /// How long this phase lasts, in whole seconds.
  final int seconds;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BreathingPhase &&
        other.type == type &&
        other.seconds == seconds;
  }

  @override
  int get hashCode => Object.hash(type, seconds);
}

/// The kind of a [BreathingPhase], driving its display label, the
/// direction the guidance circle animates, and which haptic cue plays
/// when the phase begins.
enum BreathingPhaseType {
  /// Breathing in; the guidance circle expands.
  inhale,

  /// Holding a full breath; the guidance circle stays expanded.
  holdFull,

  /// Breathing out; the guidance circle contracts.
  exhale,

  /// Holding with empty lungs; the guidance circle stays contracted.
  holdEmpty;

  /// Short, user-facing verb shown as the phase's on-screen label,
  /// e.g. `'Breathe In'`.
  String get label {
    switch (this) {
      case BreathingPhaseType.inhale:
        return 'Breathe In';
      case BreathingPhaseType.holdFull:
        return 'Hold';
      case BreathingPhaseType.exhale:
        return 'Breathe Out';
      case BreathingPhaseType.holdEmpty:
        return 'Hold';
    }
  }

  /// The guidance circle's target scale (relative to its resting
  /// size) at the *end* of this phase. [inhale] grows to full size,
  /// [exhale] shrinks to its smallest, and either hold keeps whatever
  /// scale the previous phase reached.
  double get targetScale {
    switch (this) {
      case BreathingPhaseType.inhale:
      case BreathingPhaseType.holdFull:
        return 1.0;
      case BreathingPhaseType.exhale:
      case BreathingPhaseType.holdEmpty:
        return 0.55;
    }
  }

  /// Whether the circle should keep animating smoothly during this
  /// phase ([inhale]/[exhale]) or hold steady ([holdFull]/
  /// [holdEmpty]).
  bool get isMoving =>
      this == BreathingPhaseType.inhale || this == BreathingPhaseType.exhale;
}

/// One of the four guided breathing sessions ChadMate offers:
/// Box Breathing, 4-7-8 Breathing, Calm Breathing, or Deep Belly
/// Breathing.
///
/// Each pattern is just an ordered, looping list of [phases] plus
/// some display metadata — [BreathingSessionScreen] is entirely
/// pattern-agnostic and just plays whichever one it's given for the
/// chosen session length.
@immutable
class BreathingPattern {
  const BreathingPattern({
    required this.id,
    required this.title,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.color,
    required this.phases,
    required this.benefits,
    this.guidance = const [],
  });

  /// Stable unique identifier, e.g. `'box-breathing'`.
  final String id;

  /// Short display name, e.g. `'Box Breathing'`.
  final String title;

  /// One-line summary shown on the pattern's selection card, e.g.
  /// `'4-4-4-4 · calm focus'`.
  final String tagline;

  /// A longer description of the technique and when it helps, shown
  /// before starting a session.
  final String description;

  /// Icon representing this pattern in cards and lists.
  final IconData icon;

  /// The accent color this pattern's animation, gradients, and
  /// buttons are derived from.
  final Color color;

  /// The ordered, looping sequence of phases making up one full
  /// breathing cycle, e.g. inhale-hold-exhale-hold for box breathing.
  final List<BreathingPhase> phases;

  /// Short bullet points on what this pattern is good for, shown on
  /// the pattern detail sheet.
  final List<String> benefits;

  /// Optional short reminders shown during the session's
  /// instructions step, e.g. posture or breathing-through-the-nose
  /// cues specific to this pattern.
  final List<String> guidance;

  /// Total length of one full cycle through [phases], in seconds.
  int get cycleSeconds =>
      phases.fold(0, (total, phase) => total + phase.seconds);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BreathingPattern && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// The bundled catalog of guided breathing patterns ChadMate
/// offers. Purely local, static content — no network or persistence
/// involved, mirroring how [WellnessLibraryContent] bundles its
/// articles.
abstract final class BreathingPatterns {
  static const BreathingPattern boxBreathing = BreathingPattern(
    id: 'box-breathing',
    title: 'Box Breathing',
    tagline: '4-4-4-4 · steady focus',
    description:
        'An even, four-part rhythm — inhale, hold, exhale, hold, each for '
        'the same count of four. Used by everyone from athletes to first '
        'responders to steady the nervous system and sharpen focus before '
        'a demanding moment.',
    icon: Icons.crop_square_rounded,
    color: Color(0xFF2962FF),
    phases: [
      BreathingPhase(type: BreathingPhaseType.inhale, seconds: 4),
      BreathingPhase(type: BreathingPhaseType.holdFull, seconds: 4),
      BreathingPhase(type: BreathingPhaseType.exhale, seconds: 4),
      BreathingPhase(type: BreathingPhaseType.holdEmpty, seconds: 4),
    ],
    benefits: [
      'Steadies a racing heart rate before a stressful moment',
      'Sharpens focus and concentration',
      'Simple 4-count rhythm that\'s easy to remember anywhere',
    ],
    guidance: [
      'Sit tall with your shoulders relaxed away from your ears.',
      'Breathe in and out gently through your nose throughout.',
    ],
  );

  static const BreathingPattern fourSevenEight = BreathingPattern(
    id: 'four-seven-eight',
    title: '4-7-8 Breathing',
    tagline: '4-7-8 · deep wind-down',
    description:
        'A longer, exhale-weighted pattern popularized for sleep and '
        'anxiety relief: inhale for 4, hold for 7, and exhale slowly for '
        '8. The extended exhale encourages the body to shift out of a '
        'stressed state.',
    icon: Icons.nightlight_round,
    color: Color(0xFF6C63FF),
    phases: [
      BreathingPhase(type: BreathingPhaseType.inhale, seconds: 4),
      BreathingPhase(type: BreathingPhaseType.holdFull, seconds: 7),
      BreathingPhase(type: BreathingPhaseType.exhale, seconds: 8),
    ],
    benefits: [
      'Great for winding down before sleep',
      'Long exhale helps ease anxiety and racing thoughts',
      'Works well lying down with eyes closed',
    ],
    guidance: [
      'Inhale quietly through your nose with your mouth closed.',
      'Exhale slowly through your mouth, as if fogging a mirror.',
      'If a 7-count hold feels like a strain, shorten it slightly — '
          'the ratio matters more than the exact count.',
    ],
  );

  static const BreathingPattern calmBreathing = BreathingPattern(
    id: 'calm-breathing',
    title: 'Calm Breathing',
    tagline: '5-2-6 · gentle & easy',
    description:
        'A gentle, low-effort pattern with a brief pause and a slightly '
        'longer exhale than inhale. No demanding holds — just a slow, '
        'even rhythm that\'s easy to sustain for a longer session.',
    icon: Icons.spa_rounded,
    color: Color(0xFF2E9E6C),
    phases: [
      BreathingPhase(type: BreathingPhaseType.inhale, seconds: 5),
      BreathingPhase(type: BreathingPhaseType.holdFull, seconds: 2),
      BreathingPhase(type: BreathingPhaseType.exhale, seconds: 6),
    ],
    benefits: [
      'Gentle enough for beginners or longer sessions',
      'Eases everyday tension without demanding breath holds',
      'A good default for a quick reset between tasks',
    ],
    guidance: [
      'Let your breath stay soft and quiet — there\'s no need to force '
          'a deep breath.',
      'Relax your jaw and let your shoulders drop with each exhale.',
    ],
  );

  static const BreathingPattern deepBellyBreathing = BreathingPattern(
    id: 'deep-belly-breathing',
    title: 'Deep Belly Breathing',
    tagline: '4-0-6 · diaphragmatic',
    description:
        'Also called diaphragmatic breathing: slow belly-driven breaths '
        'with no holds, keeping the chest relatively still while the '
        'belly rises and falls. Activates the body\'s relaxation '
        'response and can ease tension held in the face and jaw.',
    icon: Icons.self_improvement_rounded,
    color: Color(0xFFE07A3F),
    phases: [
      BreathingPhase(type: BreathingPhaseType.inhale, seconds: 4),
      BreathingPhase(type: BreathingPhaseType.exhale, seconds: 6),
    ],
    benefits: [
      'Trains full, diaphragm-driven breathing',
      'Can ease tension held in the jaw and face',
      'No breath holds — comfortable for most people',
    ],
    guidance: [
      'Place one hand on your chest and one on your belly.',
      'Breathe so the hand on your belly rises while the hand on your '
          'chest stays relatively still.',
      'Exhale slowly through pursed lips, feeling your belly fall.',
    ],
  );

  /// Every guided breathing pattern the app offers, in the order
  /// shown on the breathing hub.
  static const List<BreathingPattern> all = [
    boxBreathing,
    fourSevenEight,
    calmBreathing,
    deepBellyBreathing,
  ];

  /// Looks up a pattern by [id]. Returns `null` if no pattern with
  /// that id exists.
  static BreathingPattern? byId(String id) {
    for (final pattern in all) {
      if (pattern.id == id) return pattern;
    }
    return null;
  }
}
