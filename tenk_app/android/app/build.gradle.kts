import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 릴리스 서명 자격증명 로드. android/key.properties 가 있으면 릴리스 키로 서명하고,
// 없으면(예: 클론 직후 자격증명 미배치) debug 서명으로 폴백 → 로컬 `flutter run --release` 는 동작.
// key.properties + tenk-release.keystore 는 private 레포에 git 추적됨 (docs/handoff.md "옮겨야 하는 비-git 자산" 참고).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.hjson.tenk_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.hjson.tenk_app"
        // 카카오 SDK 요구사항: minSdk 21 이상. flutter.minSdkVersion이 21이면 그대로 두고, 더 낮으면 21로 명시.
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 카카오 SDK URL scheme `kakao{NATIVE_APP_KEY}`에 주입됨 (AndroidManifest.xml 참조).
        // 키 갱신 시 이 값 + iOS Info.plist + lib/config/kakao_config.dart 세 곳 모두 교체.
        manifestPlaceholders["kakaoNativeAppKey"] = "589078d3c7daa590c71d9a6e77080b18"
    }

    signingConfigs {
        // key.properties 가 있을 때만 릴리스 서명 설정을 구성한다.
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // key.properties 가 있으면 릴리스 키로, 없으면 debug 서명으로 폴백.
            // ⚠️ 릴리스 keystore 는 debug 와 키해시가 달라 카카오 콘솔에 릴리스 키해시 추가 등록 필수
            // (안 하면 릴리스 빌드에서 카카오 로그인만 실패). docs/handoff.md 남은 일 §0 참고.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // R8 축소/난독화 OFF. 최신 Flutter/AGP 는 release 에서 R8 을 기본 ON 으로 도는데,
            // 카카오 SDK 의 Pigeon 클래스(com.kakao.sdk.flutter.common.CommonHostApi 등)를 제거해
            // "Unable to establish connection on channel ... isKakaoTalkAvailable" 로 릴리스에서만
            // 카카오 로그인이 깨졌다 (usage.txt 로 stripped 확정, 2026-07-02). 이 앱은 kakao +
            // ffmpeg_kit + camera fork 등 네이티브 플러그인이 무거워 keep 규칙을 개별 관리하기보다
            // 테스트 빌드에선 축소를 끄는 게 안전. 크기 최적화가 필요한 Play Store 출시 시점에
            // R8 + 플러그인별 keep 규칙(proguard-rules.pro)으로 다시 켤 것. docs/handoff.md 함정 참고.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
