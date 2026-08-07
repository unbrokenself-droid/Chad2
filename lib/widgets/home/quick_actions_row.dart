import 'package:flutter/material.dart';

/// One tappable action in [QuickActionsRow].
class QuickAction {
  const QuickAction({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
}

/// A horizontal row of compact, rounded quick-action cards —
/// deliberately generic over its [actions] rather than hard-coding
/// which four appear, so [HomeScreen] stays the one place deciding
/// what's actually offered and where each one leads.
///
/// [HomeScreen] passes Hydration, Skincare, Posture, and Breathing —
/// the exact same actions/destinations the existing reminder cards
/// already use, just surfaced here too as a faster, denser entry
/// point. Not Progress Photo: that isn't a feature this app actually
/// has anywhere, so rather than add a tile with nothing real behind
/// it, Posture Check (a real, already-existing reminder) fills the
/// fourth slot instead — see [HomeScreen]'s own construction of this
/// row for that substitution called out explicitly.
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i != 0) const SizedBox(width: 12),
          Expanded(child: _QuickActionTile(action: actions[i])),
        ],
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(action.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 8),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
