import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must come after the Android and Kotlin
    // Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing configuration. Checks, for each of the four values
// a signing config needs, an environment variable first (the path CI
// uses — see .github/workflows/flutter-android.yml, which decodes the
// ANDROID_KEYSTORE_BASE64 secret to a file and sets these four before
// invoking Gradle), then falls back to a local android/key.properties
// file (gitignored; copy key.properties.example to create one) for a
// developer producing a signed release build on their own machine.
//
// If neither source has all four values, hasReleaseSigningConfig is
// false and the release build type further down falls back to the
// debug keystore — the same graceful degradation this project already
// had (so `flutter build apk` still works with zero setup), just
// logged loudly now instead of silently producing something that
// looks like a release build but that Google Play will reject.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun releaseSigningValue(envVar: String, propertyKey: String): String? =
    System.getenv(envVar) ?: keystoreProperties.getProperty(propertyKey)

val releaseStoreFilePath = releaseSigningValue("ANDROID_KEYSTORE_PATH", "storeFile")
val releaseStorePassword = releaseSigningValue("ANDROID_KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias = releaseSigningValue("ANDROID_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = releaseSigningValue("ANDROID_KEY_PASSWORD", "keyPassword")

val hasReleaseSigningConfig = listOf(
    releaseStoreFilePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

if (!hasReleaseSigningConfig) {
    logger.warn(
        "No release signing config found (need ANDROID_KEYSTORE_PATH, " +
            "ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, and " +
            "ANDROID_KEY_PASSWORD, either as environment variables or in " +
            "android/key.properties). This release build will be signed " +
            "with the debug keystore instead — it will install fine, but " +
            "Google Play will reject it. See android/key.properties.example."
    )
}

android {
    namespace = "com.unbrokenself.chadmate"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications requires this — it uses java.time
        // APIs internally that need backporting (desugaring) to run on
        // API levels below 26. Pairs with the coreLibraryDesugaring
        // dependency below; enabling one without the other doesn't
        // work either direction.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Permanent once the app's first Play Store release ships —
        // Google Play identifies the app by this value and it cannot
        // be changed afterward. Kept identical to `namespace` above
        // (the conventional pairing, though AGP allows them to
        // differ); change both together if it ever needs to change
        // before that first upload.
        applicationId = "com.unbrokenself.chadmate"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigningConfig) {
            create("release") {
                storeFile = file(releaseStoreFilePath!!)
                storePassword = releaseStorePassword!!
                keyAlias = releaseKeyAlias!!
                keyPassword = releaseKeyPassword!!
            }
        }
    }

    buildTypes {
        release {
            // Real signing when hasReleaseSigningConfig is true (see
            // above); falls back to the debug keystore otherwise, with
            // the warning already logged during configuration.
            signingConfig = if (hasReleaseSigningConfig) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Backs isCoreLibraryDesugaringEnabled above. Version taken from
    // flutter_local_notifications' own current docs
    // (pub.dev/packages/flutter_local_notifications), not guessed.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // flutter_local_notifications' own docs report that enabling
    // desugaring alone can cause crashes on Android 12L+ — a Flutter
    // engine issue, not the plugin's — with these two as the
    // documented workaround. Added preemptively alongside desugaring
    // rather than waiting to hit it: 12L+ covers most real devices at
    // this point, and finding this out from a production crash report
    // instead of a doc comment would be a much worse way to learn it.
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
}

