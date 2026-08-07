import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/legal_documents.dart';
import '../widgets/settings/settings_nav_tile.dart';
import 'legal_document_screen.dart';

/// Real "About" content — app version/build number, a short
/// description, and links to the (equally real, as of Phase 0)
/// Privacy Policy and Terms — replacing what used to be a "Coming
/// soon" snackbar.
///
/// Version info comes from [PackageInfo], which reads it live from
/// the platform rather than needing a hardcoded string kept in sync
/// with `pubspec.yaml` by hand. [PackageInfo.fromPlatform] can only
/// be called after `runApp()` — calling it from `main()` before that
/// throws — so this loads it via [FutureBuilder] instead of trying to
/// have it ready any earlier.
///
/// Stateful specifically so that future is created exactly once in
/// [initState], not on every rebuild — a `StatelessWidget` calling
/// `PackageInfo.fromPlatform()` directly inside `build()` would
/// re-trigger the fetch (and the `FutureBuilder`'s brief loading
/// flicker) on anything that causes this screen to rebuild while
/// visible, e.g. a theme change.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 700
                ? 32.0
                : 20.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    32,
                  ),
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.self_improvement,
                          color: colorScheme.primary,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'ChadMate',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: FutureBuilder<PackageInfo>(
                        future: _packageInfo,
                        builder: (context, snapshot) {
                          final info = snapshot.data;
                          final label = info == null
                              ? ' '
                              : 'Version ${info.version} '
                                    '(${info.buildNumber})';
                          return Text(
                            label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'ChadMate is a facial fitness and wellness '
                      'companion: guided exercises, breathing sessions, '
                      'hydration and skincare tracking, all working '
                      'fully offline on your device.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
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
