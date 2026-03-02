plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.alerta_vecinal"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true  // ← Sintaxis Kotlin
    }

    kotlinOptions {
        jvmTarget = "11"  // ← Debe coincidir con compileOptions
    }

    defaultConfig {
        applicationId = "com.example.alerta_vecinal"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
        multiDexEnabled = true  // ← Sintaxis Kotlin (sin punto y coma)
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.0.0"))
    implementation("com.google.firebase:firebase-analytics")
    
    // Desugaring para compatibilidad con APIs modernas
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")  // ← Sintaxis Kotlin
}
