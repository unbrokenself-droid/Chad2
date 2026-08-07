import 'package:flutter/material.dart';

import '../../models/premium_feature.dart';
import '../../widgets/premium/premium_feature_row.dart';
import '../../widgets/shared/primary_button.dart';
import '../upgrade_screen.dart';

/// A one-time, skippable preview of Premium shown immediately after
/// onboarding finishes, before the user reaches [MainNavigationScreen].
///
/// Pushed (not swapped in) from [OnboardingFlowScreen]'s `_finish`,
/// specifically *before* `completeOnboarding` is called — see that
/// method's comments for why the order matters: `completeOnboarding`
/// is what flips `hasCompletedOnboarding`, which is what makes
/// `_AppEntryPoint` swap away from the onboarding flow entirely.
/// Pushing this screen first, and only calling `completeOnboarding`
/// after it's dismissed, keeps `OnboardingFlowScreen` safely mounted
/// underneath for the whole time this is showing.
///
/// Every feature shown here comes directly from [PremiumFeature] —
/// nothing is duplicated or hardcoded — so this can never list a
/// feature that doesn't exist or fall out of sync with the real
/// paywall.
///
/// **Non-blocking, deliberately.** Every path out of this screen —
/// the close button, "Not now", or backing out of [UpgradeScreen]
/// after tapping "See Premium" — leads to the same place: onboarding
/// completes and the main app opens. There is no path from here that
/// requires buying anything, and nothing about reaching the main app
/// is gated on what happens on this screen.
class PremiumIntroScreen extends StatelessWidget {
  const PremiumIntroScreen({super.key});

  static const _goldEnd = Color(0xFFDC8A1E);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 700
                ? 32.0
                : 20.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        4,
                        horizontalPadding,
                        0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            // Matches UpgradeScreen's own close button
                            // — same icon, same corner — so this reads
                            // as part of the same premium experience,
                            // not a different pattern the user has to
                            // learn once for this screen only.
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            tooltip: 'Continue to ChadMate',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          0,
                          horizontalPadding,
                          12,
                        ),
                        children: [
                          Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: _goldEnd.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.workspace_premium,
                                color: _goldEnd,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'One more thing before you dive in',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            // Deliberately explicit that everything
                            // they just set up is free — the whole
                            // point of putting this here is to make
                            // the offer known, not to make free feel
                            // like a downgrade from what they expected.
                            'Everything you just set up is free, always. '
                            'Premium adds a few extra tools on top, if '
                            "you ever want them — here's what's in it.",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          for (final feature in PremiumFeature.values)
                            PremiumFeatureRow(feature: feature),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        0,
                        horizontalPadding,
                        20,
                      ),
                      child: Column(
                        children: [
                          PrimaryButton(
                            label: 'See Premium',
                            icon: Icons.workspace_premium,
                            backgroundColor: _goldEnd,
                            foregroundColor: Colors.white,
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const UpgradeScreen(
                                    source: 'post_onboarding',
                                  ),
                                ),
                              );
                              // Whether they bought, or just looked and
                              // backed out, the natural next step is
                              // the same: get them into the app rather
                              // than leaving them back on this preview
                              // needing a second dismissal.
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Not now'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
