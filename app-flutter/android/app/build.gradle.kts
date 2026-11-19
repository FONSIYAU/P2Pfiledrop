import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
var releaseStoreFile: java.io.File? = null
var releaseStorePassword: String? = null
var releaseKeyAlias: String? = null
var releaseKeyPassword: String? = null

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
    val storePath = keystoreProperties.getProperty("storeFile")?.trim().orEmpty()
    val sPass = keystoreProperties.getProperty("storePassword")?.trim().orEmpty()
    val kAlias = keystoreProperties.getProperty("keyAlias")?.trim().orEmpty()
    val kPass = keystoreProperties.getProperty("keyPassword")?.trim().orEmpty()
    val candidate = if (storePath.isNotEmpty()) {
        rootProject.file(storePath).takeIf { it.exists() }
            ?: file(storePath).takeIf { it.exists() }
    } else {
        null
    }
    if (candidate != null && sPass.isNotEmpty() && kAlias.isNotEmpty() && kPass.isNotEmpty()) {
        releaseStoreFile = candidate
        releaseStorePassword = sPass
        releaseKeyAlias = kAlias
        releaseKeyPassword = kPass
    }
}

val hasReleaseSigning = releaseStoreFile != null
if (!hasReleaseSigning) {
    println("WARNING: Android release key.properties not configured; falling back to debug signing.")
}

android {
    namespace = "dev.p2pchat.p2p_chat_app"
    compileSdk = 36
    ndkVersion = "27.2.12479018"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.p2pchat.p2p_chat_app"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = 35
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
