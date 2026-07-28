import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// 카카오 SDK에도 `AuthApi`/`UserApi`가 있어 우리 쪽과 충돌하므로 가린다.
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'
    hide AuthApi, UserApi;

import 'app/navigator_key.dart';
import 'app/scopes.dart';
import 'app/session_gate.dart';
import 'config/kakao_config.dart';
import 'design/app_theme.dart';
import 'data/amount/amount_api.dart';
import 'data/api/auth_api.dart';
import 'data/api/dio_client.dart';
import 'data/app/app_api.dart';
import 'data/auth/auth_repository.dart';
import 'data/auth/token_storage.dart';
import 'data/challenge/challenge_api.dart';
import 'data/feedback/feedback_api.dart';
import 'data/media/media_api.dart';
import 'data/user/user_api.dart';
import 'presentation/login/login_screen.dart';

/// Composition root.
///
/// 모든 의존성을 여기서 한 번 만들고 InheritedWidget(Scope)으로 트리에 주입한다.
/// 화면이나 서비스는 절대 여기서 직접 import하지 말 것 (Scope를 통해서만 접근).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);

  final storage = TokenStorage();
  final dioClient = DioClient(
    storage: storage,
    onLogout: () async => _goToLogin(),
  );
  final authApi = AuthApi(rawDio: dioClient.rawDio, authDio: dioClient.authDio);
  final authRepository = AuthRepository(api: authApi, storage: storage);
  final challengeApi = ChallengeApi(authDio: dioClient.authDio);
  final amountApi = AmountApi(authDio: dioClient.authDio);
  final mediaApi = MediaApi(authDio: dioClient.authDio);
  final userApi = UserApi(authDio: dioClient.authDio);
  final appApi = AppApi(rawDio: dioClient.rawDio);
  final feedbackApi = FeedbackApi(authDio: dioClient.authDio);

  runApp(TenkApp(
    authRepository: authRepository,
    challengeApi: challengeApi,
    amountApi: amountApi,
    mediaApi: mediaApi,
    userApi: userApi,
    appApi: appApi,
    feedbackApi: feedbackApi,
  ));
}

Future<void> _goToLogin() async {
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;
  await navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}

class TenkApp extends StatelessWidget {
  const TenkApp({
    super.key,
    required this.authRepository,
    required this.challengeApi,
    required this.amountApi,
    required this.mediaApi,
    required this.userApi,
    required this.appApi,
    required this.feedbackApi,
  });

  final AuthRepository authRepository;
  final ChallengeApi challengeApi;
  final AmountApi amountApi;
  final MediaApi mediaApi;
  final UserApi userApi;
  final AppApi appApi;
  final FeedbackApi feedbackApi;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      repository: authRepository,
      child: ChallengeScope(
        api: challengeApi,
        child: AmountScope(
          api: amountApi,
          child: MediaScope(
            api: mediaApi,
            child: UserScope(
              api: userApi,
              child: AppScope(
                api: appApi,
                child: FeedbackScope(
                  api: feedbackApi,
                  child: MaterialApp(
                    title: 'TenK',
                    navigatorKey: navigatorKey,
                    theme: buildTenkTheme(),
                    // 앱의 모든 문자열이 한국어 하드코딩이라 로케일을 ko 로 고정한다.
                    // 시스템 로케일을 따라가게 두면 영어 기기에서 Material 기본 UI
                    // (날짜/시간 picker, 라이선스 화면)만 영어로 튀어 섞인다.
                    locale: const Locale('ko'),
                    supportedLocales: const [Locale('ko')],
                    localizationsDelegates: const [
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    // 빈 곳을 탭하면 키보드를 닫는다. 화면마다 GestureDetector 를 다는 대신
                    // 여기 한 곳에서 전 화면에 적용한다 (입력칸이 있는 화면이 계속 늘어난다).
                    // translucent + onTap 이라 하위 위젯의 탭은 그대로 먹는다 — 제스처 아레나에서
                    // 안쪽 recognizer 가 우선이므로 버튼·칩 동작을 가로채지 않는다.
                    builder: (context, child) => GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                      child: child,
                    ),
                    home: const SessionGate(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
