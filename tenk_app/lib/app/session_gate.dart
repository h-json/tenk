import 'package:flutter/material.dart';

import '../presentation/challenge/challenge_list_screen.dart';
import '../presentation/legal/age_gate_screen.dart';
import '../presentation/legal/consent_gate_screen.dart';
import '../presentation/login/login_screen.dart';
import '../presentation/update/update_gate.dart';
import 'scopes.dart';

/// 앱 시작 시 진입 화면을 결정한다.
/// - 강제 업데이트 필요 → 업데이트 화면 (로그인 여부와 무관하게 모든 것을 막음)
/// - 토큰 없음 → 로그인
/// - 토큰 있고 연령 확인 미완료 → 연령 게이트 (→ 이어서 동의 게이트)
/// - 토큰 있고 필수 동의 미완료 → 동의 게이트
/// - 둘 다 완료 → 홈
/// - 권장 업데이트면 위 목적지를 [RecommendedUpdateHost] 로 감싸 첫 프레임에 1회 안내
///
/// 버전 게이트를 가장 먼저 두는 이유: 강제 업데이트는 로그인·동의보다 상위 차단이라 무엇보다 먼저 판정한다.
/// 저장된 세션이 있어도 연령 확인·동의를 마쳤다는 보장은 없다 (게이트 화면에서 이탈했거나 해당 기능
/// 도입 전 가입자일 수 있음). 그래서 세션이 있으면 `/api/users/me` 로 두 상태를 한 번 확인한다.
/// 버전 확인·`/me` 모두 네트워크 실패 시엔 앱을 잠그지 않고 진행하고, 다음 실행 때 다시 확인한다(fail-open).
///
/// 화면 단위 비동기 로딩 패턴(AsyncStateMixin)을 쓰지 않은 이유: 이 게이트는 분기 1회용이라
/// 에러/재시도 UI가 의미 없고, 결과에 따라 트리 자체가 교체된다. 가장 짧은 코드가 정답.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  Future<Widget>? _destination;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // initState에선 InheritedWidget을 못 읽는다. didChangeDependencies에서 1회만 시작.
    _destination ??= _resolve();
  }

  Future<Widget> _resolve() async {
    final appApi = AppScope.of(context);
    final auth = AuthScope.of(context);
    final userApi = UserScope.of(context);

    // 0) 버전 게이트 먼저 — 강제 업데이트는 로그인/동의보다 상위 차단. 확인 실패 시 fail-open.
    final version = await appApi.checkVersion();
    if (version.updateRequired) {
      return ForceUpdateScreen(storeUrl: version.storeUrl);
    }

    // 1) 세션 → (연령 → 동의) → 홈 목적지 결정.
    Widget destination = const ChallengeListScreen();
    if (!await auth.hasSession()) {
      destination = const LoginScreen();
    } else {
      try {
        final me = await userApi.getMe();
        // 게이트를 안쪽부터 감싼다: [연령 확인] → [약관 동의] → 홈. LoginScreen 과 같은 순서.
        if (me.consentRequired) destination = ConsentGateScreen(next: destination);
        if (me.ageVerificationRequired) destination = AgeGateScreen(next: destination);
      } catch (_) {
        // /me 실패(네트워크 등) → 홈으로 진행. 동의·연령은 다음 실행 때 다시 확인 (fail-open).
        // 토큰이 무효라면 authDio 인터셉터의 onLogout 이 로그인 화면으로 보낸다.
        destination = const ChallengeListScreen();
      }
    }

    // 2) 권장 업데이트면 목적지 위에 1회 안내를 얹는다 (계속 사용 가능).
    return version.updateAvailable
        ? RecommendedUpdateHost(storeUrl: version.storeUrl, child: destination)
        : destination;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _destination,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data!;
      },
    );
  }
}
