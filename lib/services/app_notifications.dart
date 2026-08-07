import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Which daily habit a scheduled reminder notification is for.
///
/// Each kind gets its own fixed notification id, so
/// enabling/disabling/rescheduling one kind never touches another
/// kind's pending notification.
enum ReminderKind {
  hydration('Hydration', 'Time to drink some water 💧'),
  skincare('Skincare', "Don't forget your skincare routine ✨"),
  dailyRoutine('Daily Routine', 'Time for your facial fitness exercises 🧘'),
  posture('Posture Check', 'Sit up straight and relax your jaw');

  const ReminderKind(this.title, this.defaultBody);

  /// Notification title shown for this kind.
  final String title;

  /// Notification body shown for this kind.
  final String defaultBody;
}

/// Thin wrapper around `flutter_local_notifications` shared by every
/// reminder kind (hydration, skincare, daily routine, posture).
///
/// Everything here is purely on-device: no server, no push service,
/// and no account is involved — just the OS's own local notification
/// scheduler. [ReminderSettingsService] is the only caller; it owns
/// the user-facing enabled/schedule state per [ReminderKind] and
/// delegates the actual scheduling/cancelling to this class.
///
/// Two scheduling styles are supported:
/// - [scheduleDailyAt] — fires once a day at a fixed clock time
///   (hydration, skincare, daily routine).
/// - [scheduleRepeatingInterval] — fires every fixed [Duration]
///   (posture), since a "check your posture" reminder is naturally
///   about frequency during the day rather than one specific time.
class AppNotifications {
  AppNotifications._();

  static final AppNotifications instance = AppNotifications._();

  /// Fixed notification id per [ReminderKind]. Reusing one id per kind
  /// makes re-scheduling (e.g. after a time or interval change) a
  /// plain replace-in-place rather than needing to track and cancel a
  /// previous id.
  static const Map<ReminderKind, int> _notificationIds = {
    ReminderKind.hydration: 1001,
    ReminderKind.skincare: 1002,
    ReminderKind.dailyRoutine: 1003,
    ReminderKind.posture: 1004,
  };

  static const String _channelId = 'daily_reminders';
  static const String _channelName = 'Daily Reminders';
  static const String _channelDescription =
      'Hydration, skincare, daily routine, and posture reminders';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _tzDatabaseLoaded = false;

  /// Called whenever any reminder notification is tapped while the
  /// app is running (foreground or backgrounded-but-alive), with the
  /// [ReminderKind] it was for (parsed from the notification's
  /// payload). [ReminderSettingsService] uses this to log a history
  /// entry for "today's reminder history" — set once, before any
  /// reminder is first enabled.
  void Function(ReminderKind kind)? onNotificationTapped;

  /// Sets up the plugin. Safe to call more than once; only does real
  /// work the first time.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final kind = _kindFromPayload(response.payload);
        if (kind != null) onNotificationTapped?.call(kind);
      },
    );
    _initialized = true;
  }

  /// Loads the IANA timezone database [scheduleDailyAt] needs to look
  /// up zones by name. Genuinely one-time — the database itself never
  /// changes during a run, unlike *which* zone the device is
  /// currently in (see [_ensureLocalTimezone]).
  void _ensureTimezoneDatabase() {
    if (_tzDatabaseLoaded) return;
    tz_data.initializeTimeZones();
    _tzDatabaseLoaded = true;
  }

  /// Points `tz.local` at the device's actual IANA timezone (e.g.
  /// `Asia/Kolkata`, `America/New_York`) so [scheduleDailyAt]'s
  /// `TZDateTime(tz.local, ...)` construction reflects the wall-clock
  /// time the user actually picked.
  ///
  /// A previous version of this method hardcoded
  /// `tz.setLocalLocation(tz.getLocation('UTC'))` — meaning every
  /// daily-time reminder (hydration, skincare, daily routine) fired at
  /// the chosen hour/minute *in UTC*, not in the device's real
  /// timezone. For anyone outside UTC+0 that's every reminder, off by
  /// their offset from UTC, silently, every day. `flutter_timezone`
  /// resolves the device's real zone via a native platform call so
  /// that can't happen.
  ///
  /// Re-resolves on every call rather than caching the result forever
  /// — the lookup is a single cheap platform channel round trip, and
  /// this only ever runs when a reminder is (re)scheduled (app
  /// startup for an already-enabled reminder, or a settings change),
  /// never per-notification-firing. That cadence is exactly right for
  /// picking up a device timezone change (e.g. the user traveled)
  /// without needing a full app restart to notice it.
  Future<void> _ensureLocalTimezone() async {
    _ensureTimezoneDatabase();
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimezone));
    } catch (error) {
      // The platform lookup failed, or returned a name this build's
      // bundled TZDB snapshot doesn't recognize (e.g. a very recently
      // renamed zone). Falling back to UTC reproduces this method's
      // old behavior rather than crashing scheduling outright — but
      // unlike before, it's logged loudly rather than silent, so a
      // real-world occurrence shows up in testing instead of just
      // quietly mis-scheduling someone's reminders again.
      debugPrint(
        'AppNotifications: could not resolve the device timezone, '
        'falling back to UTC: $error',
      );
      tz.setLocalLocation(tz.UTC);
    }
  }

  static ReminderKind? _kindFromPayload(String? payload) {
    if (payload == null) return null;
    for (final kind in ReminderKind.values) {
      if (kind.name == payload) return kind;
    }
    return null;
  }

  /// Requests OS-level notification permission. Returns `true` if
  /// permission is granted (or already was). On Android this only
  /// prompts on API 33+, where it's required; earlier versions grant
  /// silently. On iOS this prompts for alert/badge/sound permission.
  ///
  /// Shared across every [ReminderKind] — the OS only has one
  /// permission grant per app, not one per notification type.
  Future<bool> requestPermission() async {
    await _ensureInitialized();

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? true;
    }

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? true;
    }

    // Neither platform plugin resolved (e.g. running on an
    // unsupported platform) — assume permission isn't the blocker.
    return true;
  }

  NotificationDetails _detailsFor(ReminderKind kind) {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Schedules [kind]'s reminder to fire once a day at [timeOfDay],
  /// repeating every day thereafter. Replaces any previously
  /// scheduled reminder for [kind] in place.
  ///
  /// Used for hydration, skincare, and daily-routine reminders, which
  /// are naturally "once a day, at roughly this time" habits rather
  /// than something to repeat every few minutes.
  Future<void> scheduleDailyAt(ReminderKind kind, TimeOfDay timeOfDay) async {
    await _ensureInitialized();
    await _ensureLocalTimezone();

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    try {
      await _plugin.zonedSchedule(
        _notificationIds[kind]!,
        kind.title,
        kind.defaultBody,
        scheduled,
        _detailsFor(kind),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // iOS-only, but required by the plugin's signature. absoluteTime
        // is correct for a daily wall-clock reminder now that
        // _ensureLocalTimezone resolves the device's real zone — the
        // scheduled TZDateTime already encodes the intended local time,
        // so it should not be reinterpreted again on the platform side.
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: kind.name,
      );
    } catch (error) {
      // Scheduling shouldn't normally fail, but a denied permission
      // or an unsupported platform shouldn't crash the app — the
      // toggle just won't take visible effect until retried.
      debugPrint(
        'AppNotifications: scheduleDailyAt(${kind.name}) failed: $error',
      );
    }
  }

  /// Schedules [kind]'s reminder to fire every [interval], starting
  /// one [interval] from now. Replaces any previously scheduled
  /// reminder for [kind] in place.
  ///
  /// Used for posture reminders, which are naturally about frequency
  /// during the day (e.g. every 30 minutes) rather than one fixed
  /// time.
  Future<void> scheduleRepeatingInterval(
    ReminderKind kind,
    Duration interval,
  ) async {
    await _ensureInitialized();

    try {
      await _plugin.periodicallyShowWithDuration(
        _notificationIds[kind]!,
        kind.title,
        kind.defaultBody,
        interval,
        _detailsFor(kind),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: kind.name,
      );
    } catch (error) {
      debugPrint(
        'AppNotifications: scheduleRepeatingInterval(${kind.name}) failed: $error',
      );
    }
  }

  /// Cancels [kind]'s reminder, if one is scheduled. Safe to call even
  /// if none is currently scheduled.
  Future<void> cancel(ReminderKind kind) async {
    await _ensureInitialized();
    await _plugin.cancel(_notificationIds[kind]!);
  }
}
