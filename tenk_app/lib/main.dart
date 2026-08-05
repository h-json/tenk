import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'data/inquiry/inquiry_api.dart';
import 'data/media/media_api.dart';
import 'data/notification/notification_scheduler.dart';
import 'data/notification/notification_service.dart';
import 'data/settings/app_settings.dart';
import 'data/user/user_api.dart';
import 'presentation/login/login_screen.dart';

/// Composition root.
///
/// 모든 의존성을 여기서 한 번 만들고 InheritedWidget(Scope)으로 트리에 주입한다.
/// 화면이나 서비스는 절대 여기서 직접 import하지 말 것 (Scope를 통해서만 접근).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // **세로 고정.** TenK 은 구조적으로 세로 전용이다 — 2초 영상을 세로로 찍고, 결과 카드가
  // 9:16 고정이며, 모든 화면이 단일 컬럼이다. 그런데 막아두지 않아서 가로로 돌리면 앱 영역이
  // 387dp(세로의 42%)로 줄어 **키보드가 없어도** 시각 picker 휠이 눌리고 게이트 화면들이
  // 짜부라졌다 (2026-08-04 실기 확인). 화면마다 대응하는 대신 방향을 잠가 한 번에 닫는다.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);

  // 효과음·햅틱은 재생 직전에 동기로 읽으므로 첫 프레임 전에 로드해 둔다.
  final settings = await AppSettings.load();

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
  final inquiryApi = InquiryApi(authDio: dioClient.authDio);
  // 알림은 로컬 예약만 한다 (FCM 없음). 플러그인 init 은 첫 예약 시점에 lazy 로 돌아 부팅을 안 늦춘다.
  final notificationScheduler = NotificationScheduler(
    service: NotificationService(),
    challengeApi: challengeApi,
    settings: settings,
  );

  runApp(TenkApp(
    authRepository: authRepository,
    challengeApi: challengeApi,
    amountApi: amountApi,
    mediaApi: mediaApi,
    userApi: userApi,
    appApi: appApi,
    feedbackApi: feedbackApi,
    inquiryApi: inquiryApi,
    settings: settings,
    notificationScheduler: notificationScheduler,
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

class TenkApp extends StatefulWidget {
  const TenkApp({
    super.key,
    required this.authRepository,
    required this.challengeApi,
    required this.amountApi,
    required this.mediaApi,
    required this.userApi,
    required this.appApi,
    required this.feedbackApi,
    required this.inquiryApi,
    required this.settings,
    required this.notificationScheduler,
  });

  final AuthRepository authRepository;
  final ChallengeApi challengeApi;
  final AmountApi amountApi;
  final MediaApi mediaApi;
  final UserApi userApi;
  final AppApi appApi;
  final FeedbackApi feedbackApi;
  final InquiryApi inquiryApi;
  final AppSettings settings;
  final NotificationScheduler notificationScheduler;

  @override
  State<TenkApp> createState() => _TenkAppState();
}

/// 앱 셸이 **포그라운드 복귀**를 관찰해 알림을 다시 예약한다.
///
/// 여기에 둔 이유: 복귀 시점에 어떤 화면이 떠 있을지 모르기 때문이다. 홈 화면에만 달면
/// 상세·설정 화면에서 앱을 나갔다 돌아온 경우를 놓친다. 목록 화면도 로드 성공 시 한 번 더
/// 부르는데, 그건 방금 받은 응답을 재사용해 조회를 아끼기 위한 것이다.
class _TenkAppState extends State<TenkApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 실패해도 조용히 넘어간다 (scheduler 내부에서 처리). 로그인 전이면 조회가 실패할 뿐이다.
      widget.notificationScheduler.rescheduleAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepository = widget.authRepository;
    final challengeApi = widget.challengeApi;
    final amountApi = widget.amountApi;
    final mediaApi = widget.mediaApi;
    final userApi = widget.userApi;
    final appApi = widget.appApi;
    final feedbackApi = widget.feedbackApi;
    final inquiryApi = widget.inquiryApi;
    final settings = widget.settings;

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
                  child: InquiryScope(
                    api: inquiryApi,
                    child: SettingsScope(
                      settings: settings,
                      child: NotificationScope(
                        scheduler: widget.notificationScheduler,
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
                          // 빈 곳을 탭하면 키보드를 닫는다. 화면마다 GestureDetector 를 다는
                          // 대신 여기 한 곳에서 전 화면에 적용한다 (입력칸이 있는 화면이 계속
                          // 늘어난다). translucent + onTap 이라 하위 위젯의 탭은 그대로 먹는다
                          // — 제스처 아레나에서 안쪽 recognizer 가 우선이므로 버튼·칩 동작을
                          // 가로채지 않는다.
                          builder: (context, child) => GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () =>
                                FocusManager.instance.primaryFocus?.unfocus(),
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
          ),
        ),
      ),
    );
  }
}
