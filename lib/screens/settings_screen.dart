import 'package:flutter/material.dart';

import '../data/legal_documents.dart';
import '../services/accessibility_scope.dart';
import '../services/app_notifications.dart';
import '../services/background_music_scope.dart';
import '../services/hydration_scope.dart';
import '../services/narration_settings_scope.dart';
import '../services/onboarding_scope.dart';
import '../services/premium_scope.dart';
import '../services/reminder_settings_scope.dart';
import '../services/reminder_settings_service.dart';
import '../services/rest_day_scope.dart';
import '../services/telemetry_scope.dart';
import '../services/theme_mode_scope.dart';
import '../utils/app_haptics.dart';
import '../utils/rate_app.dart';
import '../widgets/ads/adaptive_banner_ad.dart';
import '../widgets/home/reminder_sheet.dart';
import '../widgets/home/rest_day_sheet.dart';
import '../widgets/routine/music_voice_sheet.dart';
import '../widgets/settings/accessibility_sheet.dart';
import '../widgets/settings/narration_settings_sheet.dart';
import '../widgets/settings/settings_nav_tile.dart';
import '../widgets/settings/settings_section.dart';
import '../widgets/settings/settings_switch_tile.dart';
import '../widgets/settings/theme_mode_sheet.dart';
import '../widgets/settings/units_sheet.dart';
import '../widgets/shared/section_header.dart';
import '../widgets/shared/staggered_entrance.dart';
import 'about_screen.dart';
import 'legal_document_screen.dart';
import 'subscription_management_screen.dart';
import 'upgrade_screen.dart';
import 'wellness_library_screen.dart';

/// Settings tab.
///
/// Lays out every settings row behind the app's shared list widgets
/// (a nav row, see [SettingsNavTile]) grouped into [SettingsSection]
/// cards. Reminders, Appearance, Rest Days, Accessibility, Voice &
/// Narration, Redo Onboarding, Privacy Policy, and Terms are all real,
/// wired to their respective services (or, for Privacy Policy/Terms,
/// to [LegalDocumentScreen] — see [LegalDocuments] for the bundled
/// content and its own doc comment for what's still a placeholder
/// within it). Units opens [UnitsSheet]; Voice & Narration opens
/// [NarrationSettingsSheet]; Background Music opens [MusicVoiceSheet]
/// — the same sheet reachable mid-workout from
/// [WorkoutExerciseView]'s app bar, so this row is really just a
/// second entry point to it rather than a separate settings surface
/// of its own; About opens [AboutScreen]; Rate App calls
/// [requestAppReview] directly, with no destination screen of its
/// own — see that function's doc comment for why a tap here isn't
/// guaranteed to show anything (both platforms enforce a strict
/// quota on the native prompt).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Confirms with the user, then resets onboarding so it's shown
  /// again the next time the app's entry point rebuilds — which
  /// happens immediately, since [OnboardingService.resetOnboarding]
  /// calls `notifyListeners()`.
  Future<void> _confirmResetOnboarding(BuildContext context) async {
    final onboarding = OnboardingScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Redo onboarding?'),
        content: const Text(
          "You'll be asked about your goals, experience, and reminder "
          'preferences again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Redo'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      AppHaptics.medium();
      await onboarding.resetOnboarding();
    }
  }

  /// A short summary line for [kind]'s current schedule, shown as the
  /// row's subtitle — e.g. `'Daily at 9:00 AM'` or `'Every 30 min'`
  /// when enabled, or `'Off'` otherwise.
  String _scheduleSummary(
    BuildContext context,
    ReminderSettingsService reminders,
    ReminderKind kind,
  ) {
    if (!reminders.isEnabled(kind)) return 'Off';
    if (kind == ReminderKind.posture) {
      return reminders.postureInterval.label;
    }
    final time = reminders.timeOfDayFor(kind);
    return 'Daily at ${time.format(context)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reminders = ReminderSettingsScope.of(context);
    final restDays = RestDayScope.of(context);
    final themeService = ThemeModeScope.of(context);
    final accessibility = AccessibilityScope.of(context);
    final hydration = HydrationScope.of(context);
    final narrationSettings = NarrationSettingsScope.of(context);
    final music = BackgroundMusicScope.of(context);

    final a11yExtras = <String>[
      if (accessibility.highContrast) 'High Contrast',
      if (accessibility.reduceMotion) 'Reduced Motion',
      if (accessibility.largeTouchTargets) 'Larger Targets',
    ];
    final accessibilitySummary = [
      accessibility.textScale.label,
      if (a11yExtras.isNotEmpty) a11yExtras.join(', '),
    ].join(' · ');

    final restDaysCount =
        restDays.recurringWeekdays.length + restDays.scheduledDates.length;
    final restDaysSummary = restDaysCount == 0
        ? 'None scheduled'
        : restDaysCount == 1
        ? '1 rest day scheduled'
        : '$restDaysCount rest days scheduled';

    final premium = PremiumScope.of(context);
    // listen: true — unlike most TelemetryScope reads, these two
    // toggles genuinely need to rebuild when the values change.
    final telemetry = TelemetryScope.of(context, listen: true);

    final sections = <Widget>[
      SettingsSection(
        title: 'Membership',
        children: [
          SettingsNavTile(
            icon: premium.isPremium
                ? Icons.workspace_premium
                : Icons.workspace_premium_outlined,
            title: premium.isPremium ? 'Premium' : 'Upgrade to Premium',
            subtitle: premium.isPremium
                ? 'Every feature is unlocked'
                : 'Unlock custom routines, advanced insights, and more',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    const UpgradeScreen(source: 'settings_row'),
              ),
            ),
          ),
          SettingsNavTile(
            icon: Icons.receipt_long_outlined,
            title: 'Manage Subscription',
            subtitle: premium.isPremium
                ? 'Plan, billing, and cancellation'
                : 'Restore a previous purchase',
            // Shown to free users too, not just subscribers: someone
            // reinstalling or switching devices needs to reach
            // "Restore purchases" precisely when the app doesn't
            // think they're Premium.
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SubscriptionManagementScreen(),
              ),
            ),
          ),
          if (premium.isPremium)
            SettingsNavTile(
              icon: Icons.remove_circle_outline,
              title: 'Switch to Free',
              subtitle: 'Preview the free-tier experience',
              // PRE-LAUNCH ONLY. This bypasses the store entirely —
              // it does not cancel anything on Google Play. Once real
              // billing is live, a subscriber tapping this would just
              // desync the local cache from what they're still being
              // billed for, and the next restore would grant Premium
              // straight back. Remove or gate behind a debug flag
              // before shipping real billing; "Manage Subscription"
              // above is the real cancellation path.
              onTap: () async {
                AppHaptics.selection();
                await premium.downgrade();
              },
            ),
        ],
      ),
      SettingsSection(
        title: 'Reminders',
        children: [
          for (final kind in ReminderKind.values)
            SettingsNavTile(
              icon: iconForReminderKind(kind),
              title: '${kind.title} Reminders',
              subtitle: _scheduleSummary(context, reminders, kind),
              onTap: () => showReminderSheet(context, kind),
            ),
        ],
      ),
      SettingsSection(
        title: 'Preferences',
        children: [
          SettingsNavTile(
            icon: Icons.menu_book_outlined,
            title: 'Wellness Library',
            subtitle: 'Short articles on jaw, neck, posture & more',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const WellnessLibraryScreen(),
              ),
            ),
          ),
          SettingsNavTile(
            icon: iconForThemeMode(themeService.mode),
            title: 'Appearance',
            subtitle: themeService.mode.label,
            onTap: () => showThemeModeSheet(context),
          ),
          SettingsNavTile(
            icon: Icons.self_improvement,
            title: 'Rest Days',
            subtitle: restDaysSummary,
            onTap: () => showRestDaySheet(context),
          ),
          SettingsNavTile(
            icon: Icons.accessibility_new,
            title: 'Accessibility',
            subtitle: accessibilitySummary,
            onTap: () => showAccessibilitySheet(context),
          ),
          SettingsNavTile(
            icon: Icons.record_voice_over_outlined,
            title: 'Voice & Narration',
            subtitle:
                'Speed ${(narrationSettings.speechRate * 100).round()}% · '
                'Exercise instructions read aloud',
            onTap: () => showNarrationSettingsSheet(context),
          ),
          SettingsNavTile(
            icon: Icons.music_note_outlined,
            title: 'Background Music',
            subtitle: music.enabled
                ? 'On · ${music.currentTrack.title}'
                : 'Off',
            onTap: () => showMusicVoiceSheet(context),
          ),
          SettingsNavTile(
            icon: Icons.straighten,
            title: 'Units',
            trailingText: hydration.unit.shortLabel,
            onTap: () => showUnitsSheet(context),
          ),
        ],
      ),
      SettingsSection(
        title: 'Privacy',
        children: [
          SettingsSwitchTile(
            icon: Icons.insights_outlined,
            title: 'Usage analytics',
            subtitle:
                'Share anonymous data about which features get used, to '
                'help improve the app. Never includes your name or '
                'anything you type.',
            value: telemetry.analyticsEnabled,
            onChanged: telemetry.setAnalyticsEnabled,
          ),
          SettingsSwitchTile(
            icon: Icons.bug_report_outlined,
            title: 'Crash reports',
            subtitle:
                'Send diagnostic details when something goes wrong, so '
                'it can be fixed.',
            value: telemetry.crashReportingEnabled,
            onChanged: telemetry.setCrashReportingEnabled,
          ),
        ],
      ),
      SettingsSection(
        title: 'About',
        children: [
          SettingsNavTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App version and information',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AboutScreen()),
            ),
          ),
          SettingsNavTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const LegalDocumentScreen(
                  document: LegalDocuments.privacyPolicy,
                ),
              ),
            ),
          ),
          SettingsNavTile(
            icon: Icons.star_border,
            title: 'Rate App',
            subtitle: 'Enjoying ChadMate? Let us know',
            onTap: () => requestAppReview(),
          ),
          SettingsNavTile(
            icon: Icons.description_outlined,
            title: 'Terms',
            subtitle: 'Terms of use',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const LegalDocumentScreen(
                  document: LegalDocuments.termsOfService,
                ),
              ),
            ),
          ),
          SettingsNavTile(
            icon: Icons.replay,
            title: 'Redo Onboarding',
            subtitle: 'Revisit your goals and preferences',
            onTap: () => _confirmResetOnboarding(context),
          ),
        ],
      ),
    ];

    return Scaffold(
      bottomNavigationBar: const AdaptiveBannerAd(),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.4],
            colors: [
              Color.lerp(colorScheme.surface, colorScheme.primary, 0.05)!,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              final horizontalPadding = isWide ? 32.0 : 20.0;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      32,
                    ),
                    children: [
                      const SectionHeader(
                        size: SectionHeaderSize.large,
                        subtitle: 'Settings',
                        title: 'Make it yours ⚙️',
                      ),
                      const SizedBox(height: 24),
                      for (var i = 0; i < sections.length; i++) ...[
                        StaggeredEntrance(index: i, child: sections[i]),
                        if (i != sections.length - 1)
                          const SizedBox(height: 24),
                      ],
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
