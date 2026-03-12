plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun keystoreProp(name: String): String? = keystoreProperties.getProperty(name)?.trim()?.takeIf { it.isNotEmpty() }

val hasReleaseKeystore: Boolean = run {
    val storeFileValue = keystoreProp("storeFile") ?: return@run false
    val storeFileResolved = rootProject.file(storeFileValue)
    keystorePropertiesFile.exists() &&
        listOf("keyAlias", "keyPassword", "storeFile", "storePassword").all { keystoreProp(it) != null } &&
        storeFileResolved.exists()
}

android {
    namespace = "com.catuc.cloud"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProp("keyAlias")!!
                keyPassword = keystoreProp("keyPassword")!!
                storeFile = rootProject.file(keystoreProp("storeFile")!!)
                storePassword = keystoreProp("storePassword")!!
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.catuc.cloud"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (!hasReleaseKeystore) {
                throw GradleException(
                    "Release signing is not configured. Create android/key.properties and a keystore " +
                        "(e.g. android/upload-keystore.jks), then rebuild.\n" +
                        "Tip: see Flutter docs for 'Create an upload keystore'."
                )
            }
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
