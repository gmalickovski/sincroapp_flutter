plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.sincro_app_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Atualizado para Java 17 para evitar avisos de source/target 8 obsoletos
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Habilita core library desugaring (necessário para flutter_local_notifications)
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.sincro_app_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// ✅ ADIÇÃO CRÍTICA (A CORREÇÃO PRINCIPAL)
// Este bloco implementa o "Bill of Materials" (BoM) do Firebase.
// Ele força todas as dependências nativas do Firebase (auth, firestore, ai, etc.)
// a usarem versões compatíveis entre si, resolvendo o conflito nativo.
dependencies {
    // Importa o BoM do Firebase (usando a versão estável mais recente)
    implementation(platform("com.google.firebase:firebase-bom:33.2.0"))

    // Core library desugaring (necessário para flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")

    // Você não precisa adicionar mais nada aqui (ex: firebase-auth, firebase-ai).
    // Os plugins do Flutter farão isso automaticamente, e o BoM acima
    // garantirá que as versões sejam compatíveis.
}