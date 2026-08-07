import 'package:in_app_review/in_app_review.dart';

/// Requests the platform's native in-app review prompt — Android's
/// Play In-App Review API, iOS's `SKStoreReviewController` — falling
/// back to opening the store listing directly if the native prompt
/// isn't available on this device.
///
/// A plain function rather than a service class: unlike almost
/// everything else in `lib/services/`, this has no state to persist
/// and nothing to notify listeners about — it's a single fire-and-
/// forget action, so a `ChangeNotifier` wrapper would add ceremony
/// without adding anything.
///
/// **Important, and not a bug to work around**: both platforms
/// enforce a strict quota on how often the native prompt can actually
/// appear (iOS: 3 times per 365 days; Android: undocumented but
/// similarly limited), specifically so apps can't nag users into
/// rating. `requestReview()` completing without error does not mean
/// the user saw anything — the platform APIs deliberately don't
/// expose whether the prompt actually displayed or what the user did
/// with it, so there's no way to detect that from here, and no UI in
/// this app should be built assuming it can.
Future<void> requestAppReview() async {
  final inAppReview = InAppReview.instance;
  if (await inAppReview.isAvailable()) {
    await inAppReview.requestReview();
  } else {
    await inAppReview.openStoreListing();
  }
}
