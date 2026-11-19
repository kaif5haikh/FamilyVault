import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localSigning = rootProject.file("key.properties").takeIf { it.isFile }?.let { config ->
    Properties().apply { config.inputStream().use { load(it) } }
}

fun Properties.releaseValue(key: String): String =
    requireNotNull(getProperty(key)?.takeIf { it.isNotBlank() }) {
        "Set $key in the local android/key.properties file."
    }

android {
    namespace = "app.familyvault.familyvault"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.familyvault.familyvault"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val releaseSigning = localSigning?.let { config ->
        signingConfigs.create("release") {
            storeFile = rootProject.file(config.releaseValue("storeFile"))
            storeType = config.getProperty("storeType", "PKCS12")
            storePassword = config.releaseValue("storePassword")
            keyAlias = config.releaseValue("keyAlias")
            keyPassword = config.releaseValue("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = releaseSigning
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
