import 'package:flutter/material.dart';

import '../../models/premium_feature.dart';
import '../../screens/upgrade_screen.dart';
import '../../services/app_notifications.dart';
import '../../services/premium_scope.dart';
import '../../services/reminder_settings_scope.dart';
import '../../services/reminder_settings_service.dart';
import '../shared/primary_button.dart';

/// Opens the reminder settings bottom sheet for [kind].
///
/// Convenience wrapper around [showModalBottomSheet] so callers (Home
/// screen reminder cards, the Settings "Reminders" section) don't
/// need to know the sheet's shape/styling details.
Future<void> showReminderSheet(BuildContext context, ReminderKind kind) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ReminderSheet(kind: kind),
  );
}

/// Icon shown for each [ReminderKind] across reminder UI (the sheet
/// header here, and Settings' reminder rows).
IconData iconForReminderKind(ReminderKind kind) {
  switch (kind) {
    case ReminderKind.hydration:
      return Icons.water_drop;
    case ReminderKind.skincare:
      return Icons.spa;
    case ReminderKind.dailyRoutine:
      return Icons.calendar_today;
    case ReminderKind.posture:
      return Icons.accessibility_new;
  }
}

/// Bottom sheet for enabling a single reminder [kind], configuring
/// when it fires — a daily clock time for hydration, skincare, and
/// the daily routine, or a repeat interval for posture — and
/// reviewing today's history of times it fired.
///
/// Reads and writes through [ReminderSettingsScope], so every place
/// showing a given kind's reminder state (Home's reminder cards,
/// Settings' reminder rows) stays in sync automatically. Reminders
/// are delivered entirely on-device via
/// `flutter_local_notifications` — nothing here talks to a server or
/// cloud service.
class ReminderSheet extends StatefulWidget {
  const ReminderSheet({super.key, required this.kind});

  final ReminderKind kind;

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  bool _requestingPermission = false;

  Future<void> _handleEnabledChanged(
    ReminderSettingsService reminders,
    bool value,
  ) async {
    if (!value) {
      await reminders.disable(widget.kind);
      return;
    }

    setState(() => _requestingPermission = true);
    final granted = await reminders.enable(widget.kind);
    if (!mounted) return;
    setState(() => _requestingPermission = false);

    if (!granted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              "Notifications are turned off for ChadMate — enable "
              "them in your device settings to get reminders.",
            ),
          ),
        );
    }
  }

  Future<void> _pickTime(
    ReminderSettingsService reminders,
    TimeOfDay current,
  ) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) {
      await reminders.setTimeOfDay(widget.kind, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reminders = ReminderSettingsScope.of(context);
    final kind = widget.kind;
    final enabled = reminders.isEnabled(kind);
    final history = reminders.todayHistoryFor(kind);
    final isTimeBased = kind != ReminderKind.posture;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
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
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconForReminderKind(kind),
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '${kind.title} Reminders',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
                      _EnableRow(
                        enabled: enabled,
                        busy: _requestingPermission,
                        onChanged: (value) =>
                            _handleEnabledChanged(reminders, value),
                      ),
                      const SizedBox(height: 20),
                      if (isTimeBased) ...[
                        Text(
                          'Remind me at',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _TimeRow(
                          time: reminders.timeOfDayFor(kind),
                          onTap: () =>
                              _pickTime(reminders, reminders.timeOfDayFor(kind)),
                        ),
                      ] else ...[
                        Text(
                          'Remind me',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final option
                                in PostureReminderInterval.values)
                              _IntervalChip(
                                label: option.label,
                                selected: reminders.postureInterval == option,
                                locked:
                                    option.duration.inMinutes <= 30 &&
                                    !PremiumScope.of(context).isUnlocked(
                                      PremiumFeature.unlimitedReminders,
                                    ),
                                onTap: () {
                                  final isLocked =
                                      option.duration.inMinutes <= 30 &&
                                      !PremiumScope.of(context).isUnlocked(
                                        PremiumFeature.unlimitedReminders,
                                      );
                                  if (isLocked) {
                                    Navigator.of(context).pop();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const UpgradeScreen(
                                              highlightFeature:
                                                  PremiumFeature
                                                      .unlimitedReminders,
                                              source: 'reminder_gate',
                                            ),
                                      ),
                                    );
                                    return;
                                  }
                                  reminders.setPostureInterval(option);
                                },
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Text(
                            "Today's reminders",
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          if (history.isNotEmpty)
                            TextButton(
                              onPressed: () =>
                                  reminders.clearTodayHistory(kind),
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (history.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            enabled
                                ? "No reminders yet today — they'll show "
                                      "up here as they fire."
                                : 'Turn on reminders to start tracking '
                                      "today's ${kind.title.toLowerCase()} "
                                      "check-ins.",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        _HistoryList(events: history),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnableRow extends StatelessWidget {
  const _EnableRow({
    required this.enabled,
    required this.busy,
    required this.onChanged,
  });

  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enable reminders',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Local notifications only — nothing leaves your device',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (busy)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Switch(value: enabled, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.time, required this.onTap});

  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.access_time, color: colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              Text(
                time.format(context),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'Change',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntervalChip extends StatelessWidget {
  const _IntervalChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colorScheme.primary
          : colorScheme.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (locked) ...[
                Icon(
                  Icons.lock,
                  size: 12,
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.primary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? colorScheme.onPrimary : colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.events});

  final List<ReminderEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        for (final event in events)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 18, color: colorScheme.primary),
                const SizedBox(width: 10),
                Text(_formatTime(event.time), style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }

  static String _formatTime(DateTime time) {
    final hour24 = time.hour;
    final period = hour24 < 12 ? 'AM' : 'PM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }
}
