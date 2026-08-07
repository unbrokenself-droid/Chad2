import 'package:flutter/material.dart';

/// A compact, tappable list-item card: a leading icon in a tinted
/// circle, a title/subtitle pair, and a trailing widget.
///
/// Originally built for the Home tab's hydration, skincare, and
/// posture reminders, but generic enough to reuse anywhere a tappable
/// row card is needed. Purely presentational — icon, text, and
/// [onTap] are all supplied by the caller. The only state kept here is
/// a transient "pressed" flag used to drive a subtle scale animation
/// on touch.
class ReminderCard extends StatefulWidget {
  const ReminderCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Widget shown at the end of the row. Defaults to a chevron.
  final Widget? trailing;

  @override
  State<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<ReminderCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        elevation: 2,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.35),
        surfaceTintColor: colorScheme.surfaceTint,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (highlighted) {
            setState(() => _pressed = highlighted);
          },
          splashColor: colorScheme.primary.withValues(alpha: 0.10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                ExcludeSemantics(
                  child: widget.trailing ??
                      Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
