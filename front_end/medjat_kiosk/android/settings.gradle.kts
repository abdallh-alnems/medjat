// Toolchain pinned to match medjat_app, which already ships the same
// TensorFlow Lite dependency to production.
//
// `flutter create` generated this project on AGP 9.0.1 / Gradle 9.1, and AGP 9
// rejects libraries that share a namespace. TensorFlow Lite 2.11.0 does exactly
// that across its -lite, -lite-gpu and -lite-api artifacts, so the manifest
// merge fails outright and the app cannot be built at all. Until tflite_flutter
// ships artifacts with distinct namespaces, this is the working combination.
pluginManagement {
    val flutterSdkPath =
        run {
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
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // Versions match medjat_admin, the other Android-only app in this repo.
    id("com.google.gms.google-services") version "4.3.15" apply false
    id("com.google.firebase.crashlytics") version "2.8.1" apply false
}

include(":app")
