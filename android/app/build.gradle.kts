import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase Cloud Messaging (admin payment notifications). The plugin reads
    // android/app/google-services.json, which is git-ignored: a build without it
    // fails here rather than shipping an app whose push is silently dead.
    // Google sign-in is unaffected — it passes its own serverClientId
    // (docs/google_oauth_setup.md), it never reads this file's OAuth client.
    id("com.google.gms.google-services")
}

// Release signing.
// Credentials live in android/key.properties, which is git-ignored, and the keystore
// itself is kept outside the repository - so neither ever enters version control.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val releaseStorePassword = keystoreProperties.getProperty("storePassword").orEmpty().trim()
val releaseKeyPassword = keystoreProperties.getProperty("keyPassword").orEmpty().trim()

// storeFile is absolute, or relative to the repository root (the folder holding android/).
val releaseKeystoreFile = keystoreProperties.getProperty("storeFile").orEmpty().trim()
    .replace('\\', '/')
    .let { path ->
        File(path).let { if (it.isAbsolute) it else File(rootProject.projectDir.parentFile, path) }
    }

// A published artifact must never carry debug keys, so a release build refuses to even
// configure until key.properties holds real credentials. Debug and profile builds are
// untouched, which keeps plain `flutter run` working on machines without the key.
if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }) {
    val missing = listOf("storePassword", "keyAlias", "storeFile")
        .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
    if (missing.isNotEmpty()) {
        throw GradleException(
            "Release signing is not configured - fill in " + missing.joinToString(", ") +
                " in android/key.properties (see the comments in that file)."
        )
    }
    if (!releaseKeystoreFile.isFile) {
        throw GradleException(
            "Keystore not found at ${releaseKeystoreFile.absolutePath}; fix storeFile in android/key.properties."
        )
    }
}

android {
    namespace = "com.legalcasediary.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.legalcasediary.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias").orEmpty().trim().ifEmpty { null }
            // A PKCS#12 keystore keeps one password for the store and the key, so a blank
            // keyPassword falls back to storePassword.
            keyPassword = releaseKeyPassword.ifEmpty { releaseStorePassword }.ifEmpty { null }
            storeFile = releaseKeystoreFile.takeIf { it.isFile }
            storePassword = releaseStorePassword.ifEmpty { null }
        }
    }

    buildTypes {
        release {
            // Every release build is signed with the project release keystore.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // The Theme.AppCompat parents in styles.xml resolve against this library.
    // They are required because MainActivity is a FlutterFragmentActivity for
    // local_auth's fingerprint prompt; without them the app can crash on
    // Android 8 and below (local_auth_android README).
    implementation("androidx.appcompat:appcompat:1.7.1")
}

flutter {
    source = "../.."
}
