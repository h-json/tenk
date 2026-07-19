import 'package:flutter/material.dart';

import '../presentation/challenge/challenge_list_screen.dart';
import '../presentation/legal/consent_gate_screen.dart';
import '../presentation/login/login_screen.dart';
import 'scopes.dart';

/// 앱 시작 시 진입 화면을 결정한다.
/// - 토큰 없음 → 로그인
/// - 토큰 있고 필수 동의 미완료 → 동의 게이트
/// - 토큰 있고 동의 완료 → 홈
///
/// 저장된 세션이 있어도 동의를 마쳤다는 보장은 없다 (동의 화면에서 이탈했거나 동의 기능 도입 전
/// 가입자일 수 있음). 그래서 세션이 있으면 `/api/users/me` 로 동의 상태를 한 번 확인한다.
/// 네트워크 실패 시엔 앱을 잠그지 않고 홈으로 진행하고, 다음 실행 때 다시 확인한다(fail-open).
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
    final auth = AuthScope.of(context);
    final userApi = UserScope.of(context);
    if (!await auth.hasSession()) {
      return const LoginScreen();
    }
    try {
      final me = await userApi.getMe();
      if (me.consentRequired) return const ConsentGateScreen();
    } catch (_) {
      // /me 실패(네트워크 등) → 홈으로 진행. 동의는 다음 실행 때 다시 확인 (fail-open).
      // 토큰이 무효라면 authDio 인터셉터의 onLogout 이 로그인 화면으로 보낸다.
    }
    return const ChallengeListScreen();
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
