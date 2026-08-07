# ChadMate

A Flutter application scaffold for ChadMate, built with Material 3.

This repository contains the project structure, theme, and navigation
shell — each tab currently shows **placeholder content only**, no real
features have been implemented yet.

## Architecture

The project follows a clean architecture layout under `lib/`:

| Folder       | Purpose                                                                 |
| ------------ | ------------------------------------------------------------------------ |
| `core/`      | Cross-cutting concerns: theming, constants, shared low-level utilities.  |
| `models/`    | Data models / entities.                                                  |
| `screens/`   | Top-level pages (one widget per screen/route).                          |
| `widgets/`   | Reusable UI components shared across screens.                           |
| `services/`  | External integrations: APIs, local storage, device APIs, etc.           |
| `providers/` | State management, exposing data from services/models to the UI.         |
| `utils/`     | Small stateless helper functions and extensions.                        |

## Theme

The Material 3 theme lives in `lib/core/theme/` (`app_colors.dart` +
`app_theme.dart`) and is built from a small, fixed palette:

- **Black** — high-emphasis text, dark surfaces
- **White** — backgrounds, high-contrast text
- **Light gray** — subtle surfaces, dividers
- **Blue accent** — primary actions and interactive elements

Both a light and dark `ThemeData` are provided; the app follows the
system theme mode by default.

## Navigation

`lib/screens/main_navigation_screen.dart` is the app's root navigation
shell. It owns the selected tab index and displays the five tabs behind
a Material 3 bottom `NavigationBar` (defined in
`lib/widgets/app_bottom_navigation_bar.dart`):

1. **Home** — `home_screen.dart`
2. **Exercises** — `exercises_screen.dart`
3. **Routine** — `routine_screen.dart`
4. **Progress** — `progress_screen.dart`
5. **Settings** — `settings_screen.dart`

Each tab is currently a thin wrapper around the shared
`lib/widgets/placeholder_screen.dart` widget, giving every tab its own
themed app bar and body without any real feature content yet. Tabs are
composed with an `IndexedStack`, so switching tabs preserves each tab's
state instead of rebuilding it from scratch.

## Getting started

This repository includes a minimal `android/` runner folder so it can
be built for Android both locally and in CI. Other native runner
folders (`ios/`, `web/`, etc.) aren't included; add them yourself if
you need those platforms:

```bash
flutter create . --platforms=ios,web   # adds any additional platforms you need
flutter pub get
flutter run
```

To verify everything compiles cleanly:

```bash
flutter analyze
flutter test
```

The committed `android/` folder omits the Gradle wrapper binaries
(`gradlew`, `gradlew.bat`, `gradle-wrapper.jar`) since those are
machine-generated, platform-specific files that don't belong in
version control. Generate them locally the first time you build for
Android:

```bash
cd android
gradle wrapper --gradle-version 8.14.5
cd ..
flutter build apk --release
```

CI does this automatically on every run — see below.

The Application ID is set to `com.unbrokenself.chadmate` and release
signing is configured — see **Setting up signed release builds**
below. Note that the Application ID cannot be changed after the app's
first Play Store release, so if it ever needs to differ from this,
that has to happen before the first upload.

## Continuous Integration (Android release build)

`.github/workflows/flutter-android.yml` builds a release APK and a
release App Bundle (AAB) on every push to `main`, and can also be run
manually. The APK is for sideloading/testing on a device; the AAB is
what actually gets uploaded to Play Console for a real submission.

### Triggering the workflow

- **Automatic:** push a commit to `main` (directly or by merging a
  pull request). The workflow starts within a few seconds.
- **Manual:** go to the repository's **Actions** tab → select
  **Flutter Android Release Build** in the left sidebar → click
  **Run workflow** → choose the branch → **Run workflow**.

### Setting up signed release builds

Without any setup, the workflow (and a local `flutter build apk
--release`) still succeeds — it just falls back to signing with the
debug keystore, which installs fine but which Google Play will
reject. To get a real, Play Store–ready signed build:

1. **Generate a release keystore**, if you don't have one yet:
   ```bash
   keytool -genkey -v -keystore release.keystore -alias chadmate \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
   Store the resulting `release.keystore` file and both passwords
   somewhere safe outside this repo (e.g. a password manager). If you
   lose them, you permanently lose the ability to publish updates
   under whatever app was first uploaded to Play Console with this
   key — there's no recovery path.
2. **Base64-encode the keystore file**, so it can be stored as a
   single-line GitHub secret:
   ```bash
   base64 -w 0 release.keystore > release.keystore.base64   # Linux
   base64 -i release.keystore -o release.keystore.base64    # macOS
   ```
3. **Add four repository secrets** (repository **Settings** →
   **Secrets and variables** → **Actions** → **New repository
   secret**):
   | Secret name | Value |
   | --- | --- |
   | `ANDROID_KEYSTORE_BASE64` | The contents of `release.keystore.base64` from step 2 |
   | `ANDROID_KEYSTORE_PASSWORD` | The keystore password you set in step 1 |
   | `ANDROID_KEY_ALIAS` | The `-alias` value from step 1 (`chadmate` if you used the command above as-is) |
   | `ANDROID_KEY_PASSWORD` | The key password you set in step 1 |
4. Delete the local `release.keystore.base64` file — it's no longer
   needed once the secret is set, and it contains the same sensitive
   material as the keystore itself.

The next workflow run picks these up automatically —
`android/app/build.gradle.kts` checks for them (see that file's
comments) and signs for real instead of falling back to debug.

For a **local** signed release build instead of (or in addition to)
CI, copy `android/key.properties.example` to `android/key.properties`
(gitignored) and fill in the same four values directly — no base64
encoding needed there, since it's just a local file, not something
being transmitted through a secrets store.

### Downloading the build artifacts

1. Open the **Actions** tab and click the workflow run you want (a
   green check mark means it succeeded).
2. Scroll to the **Artifacts** section at the bottom of the run's
   **Summary** page.
3. Click **release-apk** for a zip containing `app-release.apk`
   (install on a device with `adb install app-release.apk`, or
   sideload it directly), or **release-aab** for a zip containing
   `app-release.aab` (upload this one to Play Console).

Artifacts are kept for 3 days and then automatically deleted — short on purpose during active iteration, since every push to `main` uploads two new artifacts (APK + AAB) and GitHub Actions artifact storage is a shared, account-wide quota. Raise this back up once pushes are less frequent and you want specific builds to stick around longer.

> **Note:** the workflow does not run `dart format` — formatting isn't
> enforced, so the build will still succeed even if files aren't
> perfectly formatted. This keeps things simple for anyone developing
> without easy access to a formatter (e.g. purely on Android). If you'd
> like to re-enable formatting checks later, add a step running
> `dart format --output=none --set-exit-if-changed .` before `flutter
> analyze`.

### Common build errors and fixes

| Error | Likely cause | Fix |
| --- | --- | --- |
| `flutter analyze` fails | Lint or type errors introduced by a change | Fix the reported issues locally; run `flutter analyze` before pushing |
| `Gradle wrapper` step fails to download the distribution | Network hiccup fetching the pinned Gradle version, or the version was changed inconsistently | Re-run the job; if it persists, confirm `android/gradle/wrapper/gradle-wrapper.properties` and the `--gradle-version` in the workflow both reference the same Gradle version |
| `Your project's Android Gradle Plugin version (...) is lower than Flutter's minimum supported version` | Flutter stable moved forward and now requires a newer Android Gradle Plugin than `android/settings.gradle.kts` currently pins | Bump the `com.android.application` version in `android/settings.gradle.kts` to at least the minimum the error names, then bump the Gradle version in `gradle-wrapper.properties` and the workflow's `--gradle-version` to a version compatible with that AGP release ([AGP/Gradle compatibility table](https://developer.android.com/build/releases/gradle-plugin#updating-gradle)) |
| `checkReleaseAarMetadata` / `checkDebugAarMetadata` fails with `Dependency 'X' requires Android Gradle plugin Y or higher` | A dependency (often a new or updated plugin — `url_launcher_android`'s `androidx.browser` requirement is what triggered this the first time) needs a newer AGP than `android/settings.gradle.kts` currently pins. Different trigger than the row above — this comes from a dependency version, not from Flutter's own minimum | Bump AGP in `android/settings.gradle.kts` to at least the version the error names, and Gradle/wrapper-generation versions to match, the same as the row above |
| `Dependency ':flutter_local_notifications' requires core library desugaring to be enabled for :app` | `flutter_local_notifications` uses `java.time` APIs that need desugaring to run below API 26, and it isn't optional | Confirm `android/app/build.gradle.kts` has both `isCoreLibraryDesugaringEnabled = true` in `compileOptions` *and* `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:...")` in `dependencies` — both are required together; either alone does nothing |
| `Generate Gradle wrapper` step fails with `Plugin 'com.android.internal.application' relies on ... a Gradle internal API that was removed` | The runner's pre-installed ("system") Gradle — used to bootstrap the `gradle wrapper` command itself, since that command has to configure the whole project (and therefore apply AGP) before it can regenerate anything — has moved past a version AGP still depends on. Bumping the *target* Gradle version in `gradle-wrapper.properties` does not fix this: the failure happens during bootstrap, before that target version is ever consulted | Confirm the **Set up Gradle** step (`gradle/actions/setup-gradle`) is pinning a Gradle version still compatible with the AGP version in `android/settings.gradle.kts`, and that its `gradle-version` input matches the `--gradle-version` flag on the step below it. See [Gradle's AGP 8.x compatibility notes](https://docs.gradle.org/current/userguide/upgrading_version_9.html#agp_8x_incompatible) |
| `Execution failed for task ':app:...'` / AGP or Kotlin version errors | `android/settings.gradle.kts` plugin versions are incompatible with the Flutter/Gradle version currently installed | Bump the Android Gradle Plugin / Kotlin plugin versions in `android/settings.gradle.kts` to versions compatible with the Gradle version pinned in `gradle-wrapper.properties` |
| `SDK location not found` / `flutter.sdk not set in local.properties` | `local.properties` is missing (it's gitignored, machine-specific) | The workflow doesn't need this locally, but if building on your own machine, let `flutter pub get` or `flutter create .` regenerate it, or create `android/local.properties` with `flutter.sdk=/path/to/flutter` |
| `Failed to upload artifact` / "no files found" | `flutter build apk --release` failed earlier in the job, so no APK exists at `build/app/outputs/flutter-apk/app-release.apk` | Scroll up in the run's log to the actual build failure — the upload step failing is a symptom, not the root cause |
| `Keystore was tampered with, or password was incorrect` / `Failed to read key ... from store` | One of the four `ANDROID_KEYSTORE_*` / `ANDROID_KEY_*` secrets doesn't match the keystore actually encoded in `ANDROID_KEYSTORE_BASE64` (wrong password, wrong alias, or the base64 secret is stale/truncated) | Re-run steps 1–3 of **Setting up signed release builds** carefully — a mismatch here almost always means one of the secrets was copied wrong, not a code issue |
| Build succeeds locally but fails only in CI | A dependency or plugin needs a config or SDK component not installed on the CI image | Check the specific error in the Gradle log; most Android SDK components are preinstalled on `ubuntu-latest`, but native plugins may need `ndkVersion` or `compileSdk` bumped in `android/app/build.gradle.kts` |
