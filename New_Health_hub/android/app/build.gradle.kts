plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.health"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.health"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        getByName("debug") {
            // Debug signing config
        }
        // Release signing config - using debug for now
        // To use your own keystore, uncomment and configure:
        // create("release") {
        //     storeFile = file("path/to/keystore.jks")
        //     storePassword = "your-store-password"
        //     keyAlias = "your-key-alias"
        //     keyPassword = "your-key-password"
        // }
    }

    buildTypes {
        getByName("release") {
            // Disable code shrinking for release (can enable later with ProGuard)
            isMinifyEnabled = false
            isShrinkResources = false
            // Use debug signing for now (works for testing)
            // For production, use: signingConfig = signingConfigs.getByName("release")
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // Add TensorFlow Lite GPU runtime so the missing classes are available
    implementation("org.tensorflow:tensorflow-lite-gpu:2.9.0")
}
