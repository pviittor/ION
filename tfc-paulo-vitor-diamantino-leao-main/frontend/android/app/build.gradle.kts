import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Lê o key.properties (NÃO faça commit dele)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    namespace = "com.ion.app_agente_inteligente"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // opcional, mantenha se precisar

    // Use Java 17 com AGP/Gradle recentes
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.ion.app_agente_inteligente" // deve bater com o da Play
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Configuração de assinatura RELEASE
    signingConfigs {
        create("release") {
            // Se o key.properties não existir, essas linhas podem falhar;
            // garanta que ele existe e contém: storeFile, storePassword, keyAlias, keyPassword
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }

    buildTypes {
        getByName("release") {
            // Use a assinatura de release (NÃO a debug)
            signingConfig = signingConfigs.getByName("release")
            // Opcional: ofuscação/otimização
            // isMinifyEnabled = true
            // isShrinkResources = true
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        // debug permanece como está, assinado pelo debug automaticamente
    }
}

flutter {
    source = "../.."
}
