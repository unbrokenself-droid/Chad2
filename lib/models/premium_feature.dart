import 'package:flutter/material.dart';

/// Every feature in the app that can be gated behind Premium.
///
/// Adding a new gated feature is a two-step process: add a case here
/// (with its display copy), then check `PremiumScope.of(context)
/// .isUnlocked(PremiumFeature.yourCase)` — or wrap the widget in a
/// [PremiumGate] — at the point the feature is used. Nothing else in
/// the app needs to change; [PremiumService] and the upgrade UI are
/// both driven entirely off this enum.
enum PremiumFeature {
  customRoutines,
  advancedInsights,
  unlimitedReminders,
  dataExport,
  premiumThemes;

  /// Short, user-facing name shown on upgrade cards and the paywall
  /// list, e.g. 'Custom Routines'.
  String get title {
    switch (this) {
      case PremiumFeature.customRoutines:
        return 'Custom Routines';
      case PremiumFeature.advancedInsights:
        return 'Advanced Insights';
      case PremiumFeature.unlimitedReminders:
        return 'Unlimited Reminders';
      case PremiumFeature.dataExport:
        return 'Data Export';
      case PremiumFeature.premiumThemes:
        return 'Premium Themes';
    }
  }

  /// One-line description of what unlocking this feature gives the
  /// user, shown under [title] on upgrade cards and the paywall.
  String get description {
    switch (this) {
      case PremiumFeature.customRoutines:
        return 'Build and save your own exercise routines';
      case PremiumFeature.advancedInsights:
        return 'Deeper trends across streaks, wellness, and progress';
      case PremiumFeature.unlimitedReminders:
        return 'Set as many reminder times as you like, for every kind';
      case PremiumFeature.dataExport:
        return 'Export your full history as a CSV file';
      case PremiumFeature.premiumThemes:
        return 'Unlock the AMOLED Black appearance mode';
    }
  }

  /// Icon representing this feature on upgrade cards and the paywall.
  IconData get icon {
    switch (this) {
      case PremiumFeature.customRoutines:
        return Icons.playlist_add_check_circle_outlined;
      case PremiumFeature.advancedInsights:
        return Icons.insights_outlined;
      case PremiumFeature.unlimitedReminders:
        return Icons.notifications_active_outlined;
      case PremiumFeature.dataExport:
        return Icons.file_download_outlined;
      case PremiumFeature.premiumThemes:
        return Icons.palette_outlined;
    }
  }
}
