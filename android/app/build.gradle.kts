// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("kotlin-android")
    // يجب أن يُطبَّق Flutter Gradle Plugin بعد Android و Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.pharmacy_manager"

    // استخدام compileSdk من Flutter، لكنّنا نجبر NDK على الإصدار المطلوب
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8

        // هذا يفعِّل Core Library Desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.pharmacy_manager"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.8.10")

    // ترقية إصدار desugar_jdk_libs إلى 2.1.4
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
