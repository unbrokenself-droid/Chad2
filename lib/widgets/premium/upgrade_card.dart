import 'package:flutter/material.dart';

import '../../models/premium_feature.dart';
import '../../screens/upgrade_screen.dart';
import '../../utils/app_haptics.dart';

/// An attractive, gradient-backed card advertising a single locked
/// [PremiumFeature], shown in place of the real feature content.
///
/// Tapping anywhere on the card (or the explicit button) opens
/// [UpgradeScreen]. Purely presentational and self-contained — no
/// caller needs to wire up navigation, so this can be dropped in
/// wherever a feature is gated with nothing more than the feature
/// itself.
///
/// Two layouts are supported: [UpgradeCardStyle.full] for a
/// prominent, standalone placement (e.g. filling a locked screen), and
/// [UpgradeCardStyle.compact] for a smaller inline teaser (e.g. atop a
/// list that's otherwise still visible).
enum UpgradeCardStyle { full, compact }

class UpgradeCard extends StatelessWidget {
  const UpgradeCard({
    super.key,
    required this.feature,
    this.style = UpgradeCardStyle.full,
    this.title,
    this.message,
  });

  /// The locked feature this card is advertising.
  final PremiumFeature feature;

  /// Controls the card's size and prominence.
  final UpgradeCardStyle style;

  /// Overrides [feature]'s default title, e.g. to phrase it in
  /// context ("Unlock unlimited routines" rather than the feature's
  /// generic "Custom Routines").
  final String? title;

  /// Overrides [feature]'s default description.
  final String? message;

  void _openPaywall(BuildContext context) {
    AppHaptics.light();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UpgradeScreen(
          highlightFeature: feature,
          // Which locked feature the user actually ran into, so
          // conversion can be compared per gate.
          source: 'gate_${feature.name}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCompact = style == UpgradeCardStyle.compact;

    // A warm amber/gold gradient rather than the app's blue accent,
    // so a locked-feature card always reads as visually distinct from
    // ordinary content — the same reason app stores and subscription
    // UIs converge on gold for "premium" treatments.
    const goldStart = Color(0xFFF7B733);
    const goldEnd = Color(0xFFDC8A1E);

    final cardTitle = title ?? feature.title;
    final cardMessage = message ?? feature.description;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(isCompact ? 20 : 26),
      child: InkWell(
        borderRadius: BorderRadius.circular(isCompact ? 20 : 26),
        onTap: () => _openPaywall(context),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isCompact ? 16 : 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [goldStart, goldEnd],
            ),
            borderRadius: BorderRadius.circular(isCompact ? 20 : 26),
            boxShadow: [
              BoxShadow(
                color: goldEnd.withValues(alpha: isDark ? 0.28 : 0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: isCompact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 8 : 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  color: Colors.white,
                  size: isCompact ? 18 : 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'PREMIUM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 6 : 10),
                    Text(
                      cardTitle,
                      style:
                          (isCompact
                                  ? theme.textTheme.titleSmall
                                  : theme.textTheme.titleLarge)
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cardMessage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      maxLines: isCompact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isCompact) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Unlock with Premium',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: goldEnd,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: goldEnd,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isCompact) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
