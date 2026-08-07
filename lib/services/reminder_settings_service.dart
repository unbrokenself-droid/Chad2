import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'app_notifications.dart';
import 'telemetry_service.dart';

/// One reminder that has fired (or been logged) today, for display in
/// a "today's reminder history" list.
@immutable
class ReminderEvent {
  const ReminderEvent({required this.time});

  /// When this reminder fired.
  final DateTime time;

  Map<String, dynamic> _toJson() => {'time': time.toIso8601String()};

  static ReminderEvent? _fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final rawTime = json['time'];
    if (rawTime is! String) return null;
    final parsed = DateTime.tryParse(rawTime);
    if (parsed == null) return null;
    return ReminderEvent(time: parsed);
  }
}

/// Preset repeat intervals offered for [ReminderKind.posture], the
/// only kind scheduled by frequency rather than a fixed clock time.
enum PostureReminderInterval {
  everyFifteenMinutes(Duration(minutes: 15), 'Every 15 min'),
  everyThirtyMinutes(Duration(minutes: 30), 'Every 30 min'),
  everyFortyFiveMinutes(Duration(minutes: 45), 'Every 45 min'),
  everyHour(Duration(hours: 1), 'Every hour'),
  everyTwoHours(Duration(hours: 2), 'Every 2 hours');

  const PostureReminderInterval(this.duration, this.label);

  final Duration duration;
  final String label;

  static PostureReminderInterval fromMinutes(int minutes) {
    return PostureReminderInterval.values.firstWhere(
      (interval) => interval.duration.inMinutes == minutes,
      orElse: () => PostureReminderInterval.everyThirtyMinutes,
    );
  }
}

/// Persists and broadcasts every reminder kind's settings (whether
/// it's enabled, and its schedule — a daily clock time for hydration,
/// skincare, and the daily routine, or a repeat interval for posture)
/// plus a same-day fire history per kind, backed by [AppNotifications]
/// for the actual OS-level scheduling.
///
/// A single [ChangeNotifier] covering all four reminder kinds, rather
/// than four separate services, since Settings needs to show and edit
/// them together and the underlying persistence/notification/history
/// logic is identical for each — only the schedule *shape* (time vs.
/// interval) differs, and only for posture.
///
/// Everything here runs entirely on-device via
/// `flutter_local_notifications` — there is no server component and
/// no data ever leaves the device.
class ReminderSettingsService extends ChangeNotifier {
  ReminderSettingsService({
    SharedPreferencesAsync? preferences,
    AppNotifications? notifications,
    TelemetryService? telemetry,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _notifications = notifications ?? AppNotifications.instance,
       _telemetry = telemetry {
    _notifications.onNotificationTapped = _recordFiredNow;
  }

  static const TimeOfDay defaultHydrationTime = TimeOfDay(hour: 9, minute: 0);
  static const TimeOfDay defaultSkincareTime = TimeOfDay(hour: 21, minute: 0);
  static const TimeOfDay defaultRoutineTime = TimeOfDay(hour: 8, minute: 0);
  static const PostureReminderInterval defaultPostureInterval =
      PostureReminderInterval.everyThirtyMinutes;

  static String _enabledKey(ReminderKind kind) => '${kind.name}_reminder_enabled';
  static String _timeMinutesKey(ReminderKind kind) =>
      '${kind.name}_reminder_time_minutes';
  static String _historyKey(ReminderKind kind) =>
      '${kind.name}_reminder_history_by_date';

  final SharedPreferencesAsync _preferences;
  final AppNotifications _notifications;

  /// Optional so existing tests (and any other construction site that
  /// doesn't care about telemetry) can keep calling the unnamed
  /// constructor unchanged — a null here simply means reminder
  /// toggles aren't logged, never an error.
  final TelemetryService? _telemetry;

  final Map<ReminderKind, bool> _enabled = {
    for (final kind in ReminderKind.values) kind: false,
  };

  /// Minutes-since-midnight for the three daily-time kinds, and
  /// minutes-as-interval for posture. Kept as raw minutes internally
  /// so one storage/decoding path covers every kind; [timeOfDayFor]
  /// and [postureIntervalFor] convert to the right public type.
  final Map<ReminderKind, int> _scheduleMinutes = {
    ReminderKind.hydration: defaultHydrationTime.hour * 60 + defaultHydrationTime.minute,
    ReminderKind.skincare: defaultSkincareTime.hour * 60 + defaultSkincareTime.minute,
    ReminderKind.dailyRoutine: defaultRoutineTime.hour * 60 + defaultRoutineTime.minute,
    ReminderKind.posture: defaultPostureInterval.duration.inMinutes,
  };

  final Map<ReminderKind, Map<String, List<ReminderEvent>>> _historyByKind = {
    for (final kind in ReminderKind.values)
      kind: <String, List<ReminderEvent>>{},
  };

  /// Foreground tickers, one per enabled kind, so the in-app history
  /// list updates immediately while the app is open (rather than only
  /// on the next cold start or tap-through). See the class doc on
  /// [_recordFiredNow] callers for why this is needed alongside the
  /// notification-tap hook.
  final Map<ReminderKind, Timer> _foregroundTickers = {};

  /// Whether a posture check is currently awaiting acknowledgment: the
  /// posture interval elapsed while the app was foregrounded, but
  /// nothing has confirmed the user actually checked yet.
  ///
  /// Unlike the other three reminder kinds, posture's fire history
  /// isn't just a display log — [WellnessScoreService] and the
  /// Posture Champion badge both read it as a proxy for "the user did
  /// this," which a silently-firing foreground timer can't honestly
  /// claim. This flag is how that gets fixed: the ticker only ever
  /// sets it (see [_markPostureCheckDue]); only [acknowledgePostureCheck]
  /// — a real UI tap, see `PostureCheckPrompt` — actually logs an
  /// acknowledgment. [dismissPostureCheckPrompt] clears it without
  /// logging, which matters just as much: without an honest way to
  /// say "not right now," the only way to make the prompt go away
  /// would be tapping "I checked" whether or not that's true, which
  /// would just move the false-credit problem from a silent timer to
  /// social pressure instead of actually fixing it.
  ///
  /// Purely in-memory — not persisted, and not meant to be; it
  /// describes "is something waiting on screen right now," which
  /// doesn't outlive the app process in any meaningful sense.
  bool _postureCheckDue = false;

  /// See [_postureCheckDue].
  bool get hasPendingPostureCheck => _postureCheckDue;

  bool _loaded = false;

  /// Whether [load] has completed at least once.
  bool get isLoaded => _loaded;

  /// Whether [kind]'s reminder is currently turned on.
  bool isEnabled(ReminderKind kind) => _enabled[kind] ?? false;

  /// The daily clock time [kind] is scheduled for. Only meaningful for
  /// [ReminderKind.hydration], [ReminderKind.skincare], and
  /// [ReminderKind.dailyRoutine] — asserts otherwise.
  TimeOfDay timeOfDayFor(ReminderKind kind) {
    assert(
      kind != ReminderKind.posture,
      'Posture reminders are scheduled by interval, not time of day',
    );
    final minutes = _scheduleMinutes[kind]!;
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  /// The repeat interval [ReminderKind.posture] is scheduled at. Only
  /// meaningful for posture — asserts otherwise.
  PostureReminderInterval get postureInterval {
    return PostureReminderInterval.fromMinutes(
      _scheduleMinutes[ReminderKind.posture]!,
    );
  }

  /// [kind]'s reminder history for [date] (defaults to today), most
  /// recent first. Reports empty until [load] has completed once, and
  /// naturally reports empty on any day nothing fired — no explicit
  /// per-day reset needed since each date's history is looked up
  /// independently. Generalizes [todayHistoryFor] to any date, e.g.
  /// for a calendar view showing past posture-check activity.
  List<ReminderEvent> historyFor(ReminderKind kind, [DateTime? date]) {
    final key = _dateKeyFor(date ?? DateTime.now());
    final events = _historyByKind[kind]![key] ?? const <ReminderEvent>[];
    return List.unmodifiable(events.reversed);
  }

  /// Today's reminder history for [kind], most recent first. Reports
  /// empty until [load] has completed once, and naturally reports
  /// empty on any day nothing has fired yet — no explicit daily reset
  /// needed since each date's history is looked up independently.
  List<ReminderEvent> todayHistoryFor(ReminderKind kind) =>
      historyFor(kind, DateTime.now());

  /// The total number of times [kind]'s reminder has fired (or been
  /// logged) across every day ever recorded, not just today. Used for
  /// lifetime-count achievements like a posture badge, where what
  /// matters is cumulative acknowledgements rather than any single
  /// day's activity.
  int totalFiredCount(ReminderKind kind) {
    return _historyByKind[kind]!.values.fold(
      0,
      (sum, events) => sum + events.length,
    );
  }

  /// Loads persisted settings and history for every kind from disk,
  /// then restarts the OS-level schedule (and in-app ticker) for any
  /// kind that was left enabled. Safe to call more than once. Callers
  /// should await this once near app startup.
  Future<void> load() async {
    for (final kind in ReminderKind.values) {
      final storedEnabled = await _preferences.getBool(_enabledKey(kind));
      final storedMinutes = await _preferences.getInt(_timeMinutesKey(kind));
      final storedHistory = await _preferences.getString(_historyKey(kind));

      _enabled[kind] = storedEnabled ?? false;
      if (storedMinutes != null) _scheduleMinutes[kind] = storedMinutes;
      _historyByKind[kind] = _decodeHistory(storedHistory);
    }
    _loaded = true;

    for (final kind in ReminderKind.values) {
      if (_enabled[kind] == true) {
        // Re-arm the OS schedule and the in-app ticker after a cold
        // start, since the app process restarting doesn't itself
        // cancel `flutter_local_notifications`' schedule, but the
        // foreground ticker is purely in-memory and needs restarting
        // every launch.
        await _scheduleOnDevice(kind);
        _startForegroundTicker(kind);
      }
    }

    notifyListeners();
  }

  static Map<String, List<ReminderEvent>> _decodeHistory(String? raw) {
    if (raw == null || raw.isEmpty) return <String, List<ReminderEvent>>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, List<ReminderEvent>>{};
      for (final entry in decoded.entries) {
        final rawEvents = entry.value;
        if (rawEvents is! List) continue;
        final events = rawEvents
            .map(ReminderEvent._fromJson)
            .whereType<ReminderEvent>()
            .toList();
        if (events.isNotEmpty) result[entry.key] = events;
      }
      return result;
    } catch (_) {
      // Corrupt or unexpected stored data shouldn't crash the app;
      // treat it as an empty history rather than propagating.
      return <String, List<ReminderEvent>>{};
    }
  }

  String _encodeHistory(ReminderKind kind) {
    final serializable = _historyByKind[kind]!.map(
      (key, events) =>
          MapEntry(key, events.map((event) => event._toJson()).toList()),
    );
    return jsonEncode(serializable);
  }

  /// Formats [date] as the `'yyyy-MM-dd'` key used internally.
  static String _dateKeyFor(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _scheduleOnDevice(ReminderKind kind) async {
    if (kind == ReminderKind.posture) {
      await _notifications.scheduleRepeatingInterval(
        kind,
        postureInterval.duration,
      );
    } else {
      await _notifications.scheduleDailyAt(kind, timeOfDayFor(kind));
    }
  }

  /// Enables [kind]'s reminder: requests notification permission (if
  /// not already granted), schedules it on-device at its current
  /// time/interval, and starts the in-app history ticker. Returns
  /// `false` without enabling anything if permission is denied, so
  /// the caller can surface that to the user.
  Future<bool> enable(ReminderKind kind) async {
    final granted = await _notifications.requestPermission();
    if (!granted) return false;

    _enabled[kind] = true;
    notifyListeners();
    await _preferences.setBool(_enabledKey(kind), true);
    await _scheduleOnDevice(kind);
    _startForegroundTicker(kind);
    // Logged after the permission check, not before — an attempt that
    // was blocked by a denied permission isn't a user turning a
    // reminder on, and counting it as one would make the enable rate
    // look better than it is.
    _telemetry?.logEvent(
      AnalyticsEvent.reminderToggled(kind: kind.name, enabled: true),
    );
    return true;
  }

  /// Disables [kind]'s reminder: cancels its OS-level schedule and
  /// stops its in-app history ticker.
  Future<void> disable(ReminderKind kind) async {
    _enabled[kind] = false;
    _stopForegroundTicker(kind);
    if (kind == ReminderKind.posture) _postureCheckDue = false;
    notifyListeners();
    await _preferences.setBool(_enabledKey(kind), false);
    await _notifications.cancel(kind);
    _telemetry?.logEvent(
      AnalyticsEvent.reminderToggled(kind: kind.name, enabled: false),
    );
  }

  /// Toggles [kind]'s enabled state. Convenience for a settings
  /// switch's `onChanged` callback.
  Future<bool> setEnabled(ReminderKind kind, bool value) async {
    if (value) return enable(kind);
    await disable(kind);
    return true;
  }

  /// Updates the daily clock time [kind] fires at and persists it. If
  /// [kind]'s reminder is currently enabled, immediately reschedules
  /// the OS notification and restarts the in-app ticker. Only valid
  /// for [ReminderKind.hydration], [ReminderKind.skincare], and
  /// [ReminderKind.dailyRoutine] — asserts otherwise.
  Future<void> setTimeOfDay(ReminderKind kind, TimeOfDay time) async {
    assert(
      kind != ReminderKind.posture,
      'Posture reminders are scheduled by interval, not time of day; '
      'use setPostureInterval instead',
    );
    _scheduleMinutes[kind] = time.hour * 60 + time.minute;
    notifyListeners();
    await _preferences.setInt(_timeMinutesKey(kind), _scheduleMinutes[kind]!);
    if (_enabled[kind] == true) {
      await _scheduleOnDevice(kind);
      _startForegroundTicker(kind);
    }
  }

  /// Updates the repeat interval [ReminderKind.posture] fires at and
  /// persists it. If posture reminders are currently enabled,
  /// immediately reschedules and restarts the in-app ticker.
  Future<void> setPostureInterval(PostureReminderInterval interval) async {
    const kind = ReminderKind.posture;
    _scheduleMinutes[kind] = interval.duration.inMinutes;
    notifyListeners();
    await _preferences.setInt(_timeMinutesKey(kind), interval.duration.inMinutes);
    if (_enabled[kind] == true) {
      await _scheduleOnDevice(kind);
      _startForegroundTicker(kind);
    }
  }

  void _startForegroundTicker(ReminderKind kind) {
    _stopForegroundTicker(kind);

    if (kind == ReminderKind.posture) {
      // Deliberately does NOT call _recordFiredNow — see
      // _postureCheckDue's doc comment for why silently crediting an
      // acknowledgment here would be dishonest. A fresh restart of
      // this ticker (re-enabling, or changing the interval) also
      // clears any stale pending prompt from before the restart,
      // rather than carrying it forward against a schedule that no
      // longer applies.
      _postureCheckDue = false;
      _foregroundTickers[kind] = Timer.periodic(
        postureInterval.duration,
        (_) => _markPostureCheckDue(),
      );
      return;
    }

    // Time-based kinds fire once a day at a fixed clock time, so the
    // first in-app tick needs to land on that time specifically
    // (not just "24 hours from whenever enable() happened") for
    // today's history to line up with what the OS notification
    // actually shows. A one-shot [Timer] waits out the remainder of
    // today, logs the fire, then hands off to a 24-hour repeating
    // timer for subsequent days.
    final delay = _durationUntilNext(timeOfDayFor(kind));
    _foregroundTickers[kind] = Timer(delay, () {
      _recordFiredNow(kind);
      _foregroundTickers[kind] = Timer.periodic(
        const Duration(hours: 24),
        (_) => _recordFiredNow(kind),
      );
    });
  }

  /// How long from now until the next occurrence of [timeOfDay],
  /// today if it hasn't passed yet, otherwise tomorrow.
  static Duration _durationUntilNext(TimeOfDay timeOfDay) {
    final now = DateTime.now();
    var next = DateTime(
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next.difference(now);
  }

  void _stopForegroundTicker(ReminderKind kind) {
    _foregroundTickers.remove(kind)?.cancel();
  }

  void _recordFiredNow(ReminderKind kind) {
    final now = DateTime.now();
    final key = _dateKeyFor(now);
    final events = _historyByKind[kind]!.putIfAbsent(
      key,
      () => <ReminderEvent>[],
    );
    events.add(ReminderEvent(time: now));
    // A genuine acknowledgment — whether this call came from a real
    // OS notification tap or from acknowledgePostureCheck() below —
    // clears any outstanding prompt. This is the one place both
    // paths converge, which is what keeps them from needing to agree
    // on this separately.
    if (kind == ReminderKind.posture) _postureCheckDue = false;
    notifyListeners();
    unawaited(_preferences.setString(_historyKey(kind), _encodeHistory(kind)));
  }

  /// Sets [hasPendingPostureCheck], for the posture foreground ticker
  /// to call once an interval elapses. Never logs anything by
  /// itself — see that flag's doc comment for why only a real tap
  /// (through [acknowledgePostureCheck] or a notification) may do
  /// that. A no-op if a prompt is already pending, so a second
  /// interval elapsing before the first is handled doesn't reset
  /// anything or need a queue — there's only ever "one outstanding
  /// check to acknowledge," not a count of missed ones.
  void _markPostureCheckDue() {
    if (_postureCheckDue) return;
    _postureCheckDue = true;
    notifyListeners();
  }

  /// Explicit, in-app confirmation that the user actually checked
  /// their posture — the foreground counterpart to tapping the OS
  /// notification, for exactly the moment the app is already open and
  /// there's nothing to tap. Call this only from a UI control the
  /// user directly interacts with (see `PostureCheckPrompt`'s "I
  /// checked" button); never call it automatically.
  Future<void> acknowledgePostureCheck() async {
    _recordFiredNow(ReminderKind.posture);
  }

  /// Clears a pending posture-check prompt without crediting an
  /// acknowledgment — "not right now," distinct from
  /// [acknowledgePostureCheck]. This exists specifically so declining
  /// doesn't require pretending: without it, the only way to dismiss
  /// an unwanted prompt would be tapping "I checked" regardless of
  /// whether that's true, trading a silent-timer false credit for a
  /// social-pressure one instead of actually fixing anything.
  void dismissPostureCheckPrompt() {
    if (!_postureCheckDue) return;
    _postureCheckDue = false;
    notifyListeners();
  }

  /// Clears today's logged reminder history for [kind]. Exposed for a
  /// "clear history" control; history for other days is left
  /// untouched.
  Future<void> clearTodayHistory(ReminderKind kind) async {
    final key = _dateKeyFor(DateTime.now());
    if (!_historyByKind[kind]!.containsKey(key)) return;
    _historyByKind[kind]!.remove(key);
    notifyListeners();
    await _preferences.setString(_historyKey(kind), _encodeHistory(kind));
  }

  @override
  void dispose() {
    for (final kind in ReminderKind.values) {
      _stopForegroundTicker(kind);
    }
    super.dispose();
  }
}
