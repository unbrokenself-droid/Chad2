import 'package:flutter/material.dart';

import '../../services/accessibility_scope.dart';
import '../../utils/app_haptics.dart';
import 'min_tap_target.dart' show kLargeTouchTargetSize;

/// The app's standard filled call-to-action button.
///
/// Wraps [FilledButton] with the app's default sizing and shape so
/// every primary action across the app looks consistent. Colors
/// default to the theme's primary/on-primary pair but can be
/// overridden — e.g. by [FeatureCard], which needs a button that
/// stands out against its own colored background.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.expand = true,
  });

  /// The button's label text.
  final String label;

  /// Called when the button is tapped.
  ///
  /// Nullable: passing `null` renders [FilledButton]'s standard
  /// disabled appearance, which is what callers want while an action
  /// is already in flight (e.g. a purchase mid-flight) or while its
  /// preconditions aren't met yet. Every existing caller passes a
  /// non-null callback, so this widened the type without changing any
  /// of them.
  final VoidCallback? onPressed;

  /// Optional leading icon, e.g. [Icons.play_arrow].
  final IconData? icon;

  /// Overrides the button's background. Defaults to
  /// [ColorScheme.primary].
  final Color? backgroundColor;

  /// Overrides the button's text/icon color. Defaults to
  /// [ColorScheme.onPrimary].
  final Color? foregroundColor;

  /// Whether the button should stretch to fill the available width.
  /// Defaults to `true`.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttonIcon = icon;
    final callback = onPressed;
    final largeTargets = AccessibilityScope.of(context).largeTouchTargets;
    // Null propagates through to FilledButton, which is what actually
    // produces the disabled styling — wrapping null in a closure here
    // would give a button that looks enabled but does nothing.
    final VoidCallback? handlePressed = callback == null
        ? null
        : () {
            AppHaptics.light();
            callback();
          };

    final style = FilledButton.styleFrom(
      backgroundColor: backgroundColor ?? colorScheme.primary,
      foregroundColor: foregroundColor ?? colorScheme.onPrimary,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // The vertical padding above already lands this close to the
      // accessible minimum on its own, but not by any actual
      // guarantee — it's an incidental result of padding plus text
      // height, not an enforced floor. minimumSize is FilledButton's
      // own mechanism for that; setting it directly here is the
      // correct fix, not wrapping the button in an external
      // constraint that wouldn't reliably match its actual ink
      // response region. Width uses a plain finite minimum (64,
      // Material's usual button-width floor) rather than
      // double.infinity — infinity is only meaningful as a maximum
      // constraint; passing it as a minimum throws.
      minimumSize: largeTargets
          ? const Size(64, kLargeTouchTargetSize)
          : null,
    );
    final labelText = Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );

    final button = buttonIcon != null
        ? FilledButton.icon(
            onPressed: handlePressed,
            style: style,
            icon: Icon(buttonIcon),
            label: labelText,
          )
        : FilledButton(
            onPressed: handlePressed,
            style: style,
            child: labelText,
          );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
