import 'package:flutter/material.dart';

import '../../services/premium_products.dart';
import '../../services/purchase_repository.dart' show SubscriptionProduct;
import '../../utils/app_haptics.dart';

/// A single selectable plan on the paywall: title, store-provided
/// price, billing terms, and a radio-style selected state.
///
/// Everything shown here except the billing-period wording comes from
/// the store via [SubscriptionProduct] — price in particular is never
/// composed locally, since only the store knows the user's currency
/// and any regional pricing.
class PlanOptionCard extends StatelessWidget {
  const PlanOptionCard({
    super.key,
    required this.product,
    required this.selected,
    required this.onSelected,
    this.badge,
  });

  final SubscriptionProduct product;
  final bool selected;
  final VoidCallback onSelected;

  /// Optional short label (e.g. 'BEST VALUE') shown beside the title.
  final String? badge;

  /// How this plan bills, in plain words.
  ///
  /// Play policy requires billing frequency and renewal terms to be
  /// visible *before* purchase, not buried in a confirmation sheet,
  /// which is why this sits on the card itself rather than appearing
  /// only after a plan is chosen.
  String get _billingTerms {
    switch (product.kind) {
      case ProductKind.monthlySubscription:
        return 'Billed monthly. Renews automatically until cancelled.';
      case ProductKind.yearlySubscription:
        return 'Billed yearly. Renews automatically until cancelled.';
      case ProductKind.lifetime:
        return 'One-time payment. No subscription, never renews.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const goldEnd = Color(0xFFDC8A1E);

    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: '${product.title}. ${product.formattedPrice}. $_billingTerms',
      child: ExcludeSemantics(
        child: Material(
          color: selected
              ? goldEnd.withValues(alpha: 0.10)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              AppHaptics.selection();
              onSelected();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? goldEnd
                      : colorScheme.outlineVariant.withValues(alpha: 0.6),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected ? goldEnd : colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                product.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: goldEnd,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  badge!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.formattedPrice,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _billingTerms,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
