import '../models/legal_document.dart';

/// Values that appear inside [LegalDocuments]' text but can't be
/// known from the code alone — fill these in before shipping.
///
/// **This in-app content is necessary but not sufficient for Play
/// Store submission.** Google Play's own store listing requires a
/// Privacy Policy URL as a separate, publicly-hosted webpage — a
/// field in Play Console, independent of what's shown inside the app.
/// An in-app-only policy with no public URL will not satisfy that
/// listing requirement. The text in [LegalDocuments] is written to be
/// portable (plain paragraphs and bullet lists, no Flutter-specific
/// formatting) specifically so it can be copied onto a real hosted
/// page — a simple static page (e.g. alongside the existing
/// RuntimeLabs site's hosting, or a new GitHub Pages / Cloudflare
/// Pages page) is enough; it doesn't need to be fancy, just
/// stable and public.
abstract final class LegalDocumentConfig {
  /// Shown at the bottom of both documents as the contact point for
  /// privacy and terms questions. Play Console's own privacy policy
  /// requirements specifically call for a real point of contact —
  /// this can't be a placeholder in the shipped app.
  static const String supportEmail = 'TODO_SET_SUPPORT_EMAIL@example.com';

  /// The legal name these documents refer to as "we"/"us" — an
  /// individual developer's name or a registered business name,
  /// whichever is actually accurate.
  static const String developerName = 'TODO: developer or company name';

  /// The jurisdiction whose law governs the Terms of Service (used in
  /// the Governing Law section). Deliberately left unset rather than
  /// guessed — this is worth deciding with a lawyer, not defaulting
  /// to whatever's convenient.
  static const String governingLaw = 'TODO: governing law / jurisdiction';

  /// Shown as "Last updated" on both documents. Update this — and
  /// actually re-review both documents — any time their content
  /// changes materially, not just on first publish.
  static const String publishDate = 'TODO: set to the actual publish date';
}

/// The Privacy Policy and Terms of Service bundled with the app.
///
/// Both are written to accurately describe what this codebase
/// actually does as of when this file was written, not aspirational
/// behavior — see the `FLAG:` comments throughout for specific
/// sentences that are only true today and need to be revisited if the
/// underlying feature changes. Search this file for `FLAG:` before
/// shipping any change to notifications, purchases, backend/network
/// behavior, or analytics.
abstract final class LegalDocuments {
  static const LegalDocument privacyPolicy = LegalDocument(
    title: 'Privacy Policy',
    lastUpdated: LegalDocumentConfig.publishDate,
    intro:
        'ChadMate ("the app", "we", "us") is developed by '
        '${LegalDocumentConfig.developerName}. This policy explains '
        "what information the app collects, how it's used, and the "
        'choices you have. ChadMate is designed to work on your '
        'device: it has no account system and does not require you '
        'to sign in, and your profile and activity data are stored '
        'locally rather than on a server we operate. The one '
        'exception is optional usage analytics and crash reporting, '
        'which you can turn off in Settings → Privacy — see '
        '"Analytics and crash reporting" below for exactly what '
        'those cover.',
    sections: [
      LegalDocumentSection(
        heading: 'Information we collect',
        body:
            'ChadMate stores the following locally on your '
            "device, using Android's standard app storage:",
        bullets: [
          'Onboarding information you choose to provide: your name '
              '(optional — you can skip it), the wellness goals you '
              'select, and your self-reported experience level.',
          "Activity you log in the app: which exercises you've "
              'completed and when, your daily water intake, your '
              'skincare checklist completions, bookmarked articles, '
              'favorited exercises, and any custom routines you '
              'create.',
          'App preferences: your chosen appearance mode, '
              'accessibility settings, and your reminder schedule.',
          'Reminder history: when scheduled reminders have fired, so '
              'the app can show you a history and related progress '
              '(for example, posture-check counts).',
          'Subscription status: if you purchase ChadMate '
              'Premium, we store which plan you have locally so the '
              "app can unlock the corresponding features — see "
              '"Purchases and Subscriptions" below for how the '
              'purchase itself is handled.',
        ],
      ),
      LegalDocumentSection(
        heading: "What we don't collect",
        body:
            'We do not collect your email address, phone number, '
            'physical address, or any government-issued identifier '
            'through the app. We do not ask for or access your '
            'camera, microphone, contacts, or location.',
      ),
      LegalDocumentSection(
        heading: 'How your information is used',
        body:
            'Everything listed above is used to run the app\'s own '
            'features on your device: generating and personalizing '
            'your daily routine, tracking your streaks and progress, '
            'showing your reminder history, and remembering your '
            'preferences between sessions. None of it is used for '
            'advertising, and none of it is sold.',
      ),
      LegalDocumentSection(
        heading: 'Where your information is stored',
        body:
            "All of the information above stays on your device, in "
            "the app's local storage. If your device's built-in "
            'Android backup feature is turned on, some of this data '
            "may be included in your device's standard backup to "
            'your Google Account, the same way it would be for most '
            'apps — that setting is controlled by your device and '
            'Google Account, not chosen by ChadMate specifically.',
        // FLAG: the app doesn't currently set android:allowBackup
        // explicitly either way, so this paragraph is written to be
        // accurate regardless of the platform default. If that's
        // ever set deliberately (see AndroidManifest.xml), re-check
        // this paragraph still matches reality.
      ),
      LegalDocumentSection(
        heading: 'Notifications',
        body:
            'If you enable reminders (for hydration, skincare, your '
            'daily routine, or posture checks), ChadMate '
            "schedules local notifications directly on your device "
            'using Android\'s own notification system. These are not '
            'push notifications — no message is sent to or through '
            'any server, ours or otherwise, to trigger them. You can '
            'turn any reminder off at any time in Settings, and you '
            "can revoke the app's notification permission at any "
            "time in your device's system settings.",
      ),
      LegalDocumentSection(
        heading: 'Purchases and subscriptions',
        body:
            'ChadMate offers optional Premium features via '
            'monthly subscription, yearly subscription, and a '
            'one-time lifetime purchase, processed through Google '
            'Play Billing. When you make a purchase, Google — not '
            'ChadMate — processes your payment and collects your '
            'payment details; we never see or store your card number '
            'or other payment information. Google shares with us '
            'only what\'s needed to unlock the purchase on your '
            'device (which product you bought and a purchase '
            'identifier), which we store locally the same way as '
            'everything else described in this policy.',
        // FLAG: this section describes the shipped-intended billing
        // behavior (SubscriptionManager.production / real Play
        // Billing), not the simulated repository currently active by
        // default during development. Confirm real billing is live
        // before this policy goes out, or adjust the wording if it's
        // published ahead of that.
      ),
      LegalDocumentSection(
        heading: 'Your choices',
        body:
            'ChadMate has no account, and your profile and activity '
            "data are kept locally, so you're in control of them at "
            'all times:',
        bullets: [
          'You can turn usage analytics and crash reporting off at '
              'any time in Settings → Privacy.',
          "You can turn off any reminder's notifications in Settings "
              'at any time.',
          'You can reset your onboarding profile at any time via '
              'Settings → Redo Onboarding.',
          'Uninstalling the app removes all of the locally-stored '
              'information described above from your device.',
        ],
      ),
      LegalDocumentSection(
        heading: "Exporting your data",
        body:
            'We don\'t currently offer an in-app way to export a copy '
            'of your data before deleting it. If that changes, this '
            'section will be updated to explain how.',
        // FLAG: matches PremiumFeature.dataExport being promised on
        // the paywall but not yet implemented anywhere in the
        // codebase. Do not remove this caveat, and do not describe
        // export as available, until that feature actually exists.
      ),
      LegalDocumentSection(
        heading: 'Analytics and crash reporting',
        body:
            'ChadMate includes optional usage analytics and crash '
            'reporting, both of which you can turn off at any time in '
            'Settings → Privacy. When enabled, these record:',
        bullets: [
          'Which features you use and when — for example that '
              'onboarding was completed, that an exercise session was '
              'started or finished, that the upgrade screen was '
              'viewed, or that a reminder was turned on or off.',
          'Diagnostic details when the app crashes or hits an error, '
              'including the error itself and where in the app it '
              'happened.',
        ],
        // FLAG: keep these bullets matching AnalyticsEvent's named
        // constructors in lib/services/analytics_service.dart — that
        // class is the complete list of what the app can send, so
        // adding an event there without updating this section makes
        // this policy inaccurate.
      ),
      LegalDocumentSection(
        heading: 'What analytics never includes',
        body:
            'Analytics events describe what happened in the app, not '
            'who you are. They never include the name you entered '
            'during onboarding, the names of any custom routines you '
            'create, or any other text you type. We do not build an '
            'advertising profile, and we do not sell any of this.',
      ),
      LegalDocumentSection(
        heading: 'Where analytics data currently goes',
        body:
            'No third-party analytics or crash-reporting provider is '
            'connected in this version of the app. The events '
            'described above are written only to a local development '
            'log and are not transmitted anywhere. If a provider is '
            'connected in a future version, this policy will be '
            'updated before or alongside that change, and the '
            "Settings → Privacy toggles will continue to control "
            'whether anything is collected at all.',
        // FLAG: THE most important sentence in this file to keep
        // honest. It is accurate only while DebugAnalyticsService /
        // DebugCrashReporter remain the defaults in main.dart. The
        // moment a real provider (see
        // lib/services/firebase_telemetry.dart.template) is
        // activated, this paragraph becomes false and must be
        // rewritten to name the provider, what it collects
        // automatically beyond the events listed above (device model,
        // OS version, app instance identifier, coarse location
        // derived from IP address), and where that data is
        // processed. Shipping a real provider with this paragraph
        // unchanged is exactly the kind of misstatement Play's
        // Deceptive Behavior policy and most data-protection law
        // prohibit.
      ),
      LegalDocumentSection(
        heading: "Children's privacy",
        body:
            'ChadMate is not directed at children under 13 (or '
            'the relevant minimum age where you live), and we do not '
            'knowingly collect information from children. If you '
            'believe a child has provided us information, contact us '
            "below and we'll address it.",
      ),
      LegalDocumentSection(
        heading: 'Changes to this policy',
        body:
            'We may update this policy as the app changes — for '
            'example, if a third-party analytics provider or any '
            'server-side feature is added in the future, this policy '
            'will be updated to reflect that before or alongside the '
            'change, not after.',
      ),
      LegalDocumentSection(
        heading: 'Contact us',
        body:
            'Questions about this policy or how ChadMate handles '
            'information? Contact us at: '
            '${LegalDocumentConfig.supportEmail}',
      ),
    ],
  );

  static const LegalDocument termsOfService = LegalDocument(
    title: 'Terms of Service',
    lastUpdated: LegalDocumentConfig.publishDate,
    intro:
        'By downloading, installing, or using ChadMate ("the '
        "app\"), you agree to these Terms of Service. If you don't "
        "agree, please don't use the app.",
    sections: [
      LegalDocumentSection(
        heading: 'What ChadMate is',
        body:
            'ChadMate provides guided facial fitness exercises, '
            'breathing sessions, hydration and skincare tracking, and '
            'related wellness content, for general wellness and '
            'habit-building purposes.',
      ),
      LegalDocumentSection(
        heading: 'Not medical advice',
        body:
            'ChadMate is not a medical device, and nothing in the '
            'app is medical advice. The exercises, routines, and '
            'wellness content are general, educational, and '
            'habit-focused. They are not intended to diagnose, treat, '
            'cure, or prevent any medical condition, and they do not '
            'replace advice from a qualified doctor, dermatologist, '
            'physical therapist, or other healthcare professional. '
            'Read any safety precaution listed with an exercise '
            'before starting it, and stop any exercise that causes '
            'pain. If you have a jaw, neck, or other relevant medical '
            'condition, talk to a healthcare professional before '
            'starting a new routine. Results — including any change '
            'in how your face or skin looks or feels — are not '
            'guaranteed and will vary from person to person.',
      ),
      LegalDocumentSection(
        heading: 'Who can use ChadMate',
        body:
            'You must be at least 13 years old (or the minimum age '
            'of digital consent where you live, if higher) to use '
            'ChadMate.',
      ),
      LegalDocumentSection(
        heading: 'Your data',
        body:
            'ChadMate does not require an account. Your '
            'progress, preferences, and any custom routines you '
            'create are stored locally on your device, as described '
            "in our Privacy Policy. You're responsible for your "
            'device and for anyone else who has access to it.',
      ),
      LegalDocumentSection(
        heading: 'Premium subscriptions and purchases',
        body:
            'ChadMate offers optional paid features ("Premium") '
            'via monthly subscription, yearly subscription, or a '
            'one-time lifetime purchase.',
        bullets: [
          "Billing. All purchases are processed through Google Play "
              "Billing and are subject to Google Play's own Terms of "
              'Service and Payments policies, in addition to these '
              'Terms.',
          'Auto-renewal. Subscriptions renew automatically at the '
              'end of each billing period unless cancelled before '
              'the renewal date. You will be charged through your '
              'Google Play account.',
          'Price and terms. The price, billing frequency, and '
              'renewal terms for each plan are shown before you '
              'complete a purchase.',
          'Cancelling. You can cancel a subscription at any time from '
              'Settings → Manage Subscription in the app, which opens '
              "Google Play's subscription management where the "
              'cancellation is completed. You can also reach it '
              'directly in the Play Store app under Menu → '
              'Subscriptions. Cancelling stops future renewals; '
              'access continues until the end of the period already '
              'paid for.',
          'Refunds. Refunds are handled by Google Play under its own '
              'refund policy; ChadMate does not independently '
              'process or guarantee refunds.',
          'What Premium unlocks. Premium features are described in '
              'the app at the time of purchase and may expand over '
              "time; we won't remove a feature you're already paying "
              'for without a reasonable alternative or notice.',
        ],
        // Resolved: the in-app cancellation path Play requires now
        // exists (Settings → Manage Subscription →
        // SubscriptionManagementScreen → "Cancel subscription", which
        // is two taps from that screen). Keep the "Cancelling" bullet
        // in sync if that route ever moves.
      ),
      LegalDocumentSection(
        heading: 'Acceptable use',
        body:
            "Don't use ChadMate to do anything illegal, to try "
            'to disrupt or reverse-engineer the app beyond what\'s '
            'permitted by applicable law, or to interfere with other '
            'users if any social or shared features are added in the '
            'future.',
      ),
      LegalDocumentSection(
        heading: 'Your content',
        body:
            'If you create custom routines or other content within '
            'the app, you retain ownership of it. Because Face '
            "Fitness stores this locally on your device, we don't "
            'keep a copy of it and cannot recover it if you delete '
            'the app or lose your device.',
      ),
      LegalDocumentSection(
        heading: 'Disclaimers',
        body:
            'ChadMate is provided "as is", without warranties of '
            'any kind, to the fullest extent permitted by law. We do '
            'not guarantee the app will be uninterrupted or '
            'error-free, or that any exercise or feature will '
            'produce particular results.',
      ),
      LegalDocumentSection(
        heading: 'Limitation of liability',
        body:
            'To the fullest extent permitted by law, '
            '${LegalDocumentConfig.developerName} is not liable for '
            'any indirect, incidental, or consequential damages '
            'arising from your use of the app. Nothing in these '
            "Terms limits liability that can't be limited under "
            'applicable law.',
      ),
      LegalDocumentSection(
        heading: 'Changes to the app or these terms',
        body:
            'We may update the app and these Terms over time. If we '
            'make material changes to these Terms, we\'ll update the '
            '"Last updated" date above and, where required, notify '
            'you in the app.',
      ),
      LegalDocumentSection(
        heading: 'Termination',
        body:
            'You can stop using ChadMate at any time by '
            'uninstalling it. We may suspend or discontinue the app '
            'or particular features with reasonable notice where '
            'required by law.',
      ),
      LegalDocumentSection(
        heading: 'Governing law',
        body: LegalDocumentConfig.governingLaw,
        // FLAG: deliberately left as a TODO in LegalDocumentConfig
        // rather than guessed — this should be decided (ideally with
        // a lawyer), not defaulted.
      ),
      LegalDocumentSection(
        heading: 'Contact us',
        body:
            'Questions about these Terms? Contact us at: '
            '${LegalDocumentConfig.supportEmail}',
      ),
    ],
  );
}
