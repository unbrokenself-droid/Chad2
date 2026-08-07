import 'package:flutter/services.dart';

/// Centralized haptic feedback helpers for interactive widgets.
///
/// Every tappable control in the app (buttons, switches, nav bar,
/// favorite toggles, checkboxes, sliders, drag-to-reorder, etc.)
/// should route through one of these rather than calling
/// [HapticFeedback] directly, so the *meaning* of a given buzz stays
/// consistent app-wide: light taps for routine navigation/selection,
/// medium for a confirmed action, heavy for a milestone or destructive
/// action, and a plain click for toggles.
///
/// [HapticFeedback] calls are inherently fire-and-forget platform
/// channel calls with no failure path worth surfacing to the user, so
/// each helper swallows [MissingPluginException]/platform errors
/// rather than letting a haptics hiccup crash an otherwise successful
/// interaction (this matters most on emulators/CI where the platform
/// side may not implement haptics at all).
abstract final class AppHaptics {
  /// Everyday navigation and selection: switching tabs, selecting a
  /// filter chip, moving a picker, expanding a section.
  static void selection() {
    _run(HapticFeedback.selectionClick);
  }

  /// A light, low-emphasis confirmation: toggling a favorite off,
  /// checking a minor option, a subtle UI acknowledgement.
  static void light() {
    _run(HapticFeedback.lightImpact);
  }

  /// A standard confirmed action: completing an exercise, saving a
  /// setting, submitting a form, favoriting an item.
  static void medium() {
    _run(HapticFeedback.mediumImpact);
  }

  /// A significant milestone or a destructive/high-stakes action:
  /// finishing a full routine, unlocking a badge, deleting a custom
  /// routine.
  static void heavy() {
    _run(HapticFeedback.heavyImpact);
  }

  static void _run(Future<void> Function() feedback) {
    // Fire-and-forget by design; see class doc.
    feedback().catchError((_) {});
  }
}
