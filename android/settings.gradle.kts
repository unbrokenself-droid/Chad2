pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Both bumped together from 8.7.3 / 2.1.0 — the previous versions
    // were below what several dependencies now require outright (see
    // android/app/build.gradle.kts's dependencies block comment).
    // 8.11.1 specifically isn't an arbitrary "newer is better" choice:
    // it's the exact floor Flutter's own build-time warning named for
    // AGP, and it's independently the version flutter_local_notifications'
    // own docs (pub.dev/packages/flutter_local_notifications) say their
    // desugaring support is built against — using less than that on a
    // plugin that explicitly documents needing that AGP version is how
    // "the desugaring config is technically present but the plugin's
    // build assumptions still don't hold" bugs happen.
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
