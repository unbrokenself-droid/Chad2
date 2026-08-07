import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/premium_scope.dart';
// Re-exports ProductKind and PurchaseException.
import '../services/premium_service.dart';
import '../utils/app_haptics.dart';
import '../widgets/shared/primary_button.dart';

/// Shows the user's current plan and gives them the two things Play
/// policy requires an app selling subscriptions to provide: a way to
/// reach cancellation, and a way to restore an existing purchase.
///
/// **On the two-tap cancellation requirement.** Play requires
/// cancellation to be reachable within two taps of a subscription
/// management screen. This screen is tap one (Settings → Manage
/// Subscription); the "Cancel subscription" button here is tap two,
/// which opens Play's own subscription page. The actual cancellation
/// has to happen on Play's side — an app cannot cancel a Play
/// subscription itself, and shouldn't pretend to. What matters for
/// the policy is that the path is short and obvious, which it is.
class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  /// Must match `applicationId` in android/app/build.gradle.kts —
  /// Play's subscription deep link needs the package name to resolve
  /// which app's subscription to show.
  static const String _packageName = 'com.unbrokenself.chadmate';

  Future<void> _openPlaySubscriptions(String? productId) async {
    AppHaptics.selection();
    // Play's canonical deep link. Including the product ID opens
    // directly on that subscription rather than the full list.
    final uri = Uri.parse(
      productId == null
          ? 'https://play.google.com/store/account/subscriptions'
          : 'https://play.google.com/store/account/subscriptions'
                '?sku=$productId&package=$_packageName',
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open Google Play. You can manage your '
              'subscription in the Play Store app under Menu → '
              'Subscriptions.',
            ),
          ),
        );
    }
  }

  Future<void> _restore(PremiumService premium) async {
    AppHaptics.selection();
    final wasPremium = premium.isPremium;

    try {
      await premium.restorePurchases();
    } on PurchaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }

    if (!mounted) return;
    // Three genuinely different outcomes, each worth saying plainly —
    // "restore complete" alone would leave someone who just lost
    // access with no idea why.
    final String message;
    if (premium.isPremium && !wasPremium) {
      message = 'Your Premium purchase has been restored.';
    } else if (premium.isPremium) {
      message = 'Your Premium purchase is active.';
    } else if (wasPremium) {
      message =
          'Google Play no longer reports an active purchase, so '
          'Premium has been turned off on this device.';
    } else {
      message = 'No previous purchase was found for this Google account.';
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _planLabel(PremiumService premium) {
    switch (premium.productKind) {
      case ProductKind.monthlySubscription:
        return 'Premium — Monthly';
      case ProductKind.yearlySubscription:
        return 'Premium — Yearly';
      case ProductKind.lifetime:
        return 'Premium — Lifetime';
      case null:
        return premium.isPremium ? 'Premium' : 'Free';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final premium = PremiumScope.of(context);
    final isSubscription = premium.productKind?.isSubscription ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Subscription')),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 700 ? 32.0 : 20.0;

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
                    _StatusCard(
                      planLabel: _planLabel(premium),
                      isPremium: premium.isPremium,
                    ),
                    if (premium.hasPendingPurchase) ...[
                      const SizedBox(height: 12),
                      _InfoNote(
                        icon: Icons.hourglass_top,
                        text:
                            'A purchase is pending approval. Premium '
                            'unlocks automatically once it completes.',
                      ),
                    ],
                    const SizedBox(height: 20),

                    if (premium.isPremium) ...[
                      Text(
                        'BILLING',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Deliberately does NOT display a renewal date.
                      // Nothing in this app knows one: EntitlementManager
                      // persists the tier, product ID and kind, and
                      // nothing else, because a renewal date can only be
                      // obtained reliably from the Google Play Developer
                      // API server-side — which this app has no backend
                      // for. Showing an invented or guessed date on a
                      // billing screen would be worse than showing none,
                      // so this points at the one place that always has
                      // the authoritative answer instead.
                      _InfoNote(
                        icon: Icons.info_outline,
                        text: isSubscription
                            ? 'Your renewal date and payment method are '
                                  'held by Google Play. Open Google Play '
                                  'below to see exactly when your '
                                  'subscription renews.'
                            : 'Lifetime access is a one-time purchase — '
                                  'there is nothing to renew or cancel.',
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (isSubscription) ...[
                      PrimaryButton(
                        label: 'Cancel subscription',
                        icon: Icons.open_in_new,
                        onPressed: () =>
                            _openPlaySubscriptions(premium.productId),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Opens Google Play, where subscriptions are '
                        'cancelled. Your Premium features stay active '
                        'until the end of the period you have already '
                        'paid for.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    Text(
                      'ALREADY PURCHASED?',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If you bought Premium before — on this device or '
                      'another one signed in to the same Google account '
                      '— restore it here.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: premium.isRestoring
                          ? null
                          : () => _restore(premium),
                      icon: premium.isRestoring
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restore),
                      label: Text(
                        premium.isRestoring
                            ? 'Restoring…'
                            : 'Restore purchases',
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => _openPlaySubscriptions(null),
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('View all Google Play subscriptions'),
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.planLabel, required this.isPremium});

  final String planLabel;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const goldEnd = Color(0xFFDC8A1E);
    final accent = isPremium ? goldEnd : colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPremium ? Icons.workspace_premium : Icons.person_outline,
              color: accent,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT PLAN',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  planLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 10),
          child: Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        ),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
