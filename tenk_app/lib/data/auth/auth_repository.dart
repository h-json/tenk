import 'package:flutter/services.dart';
// 카카오 SDK의 `AuthApi`는 우리 [AuthApi]와 이름이 겹치므로 가린다.
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide AuthApi;

import '../api/api_error.dart';
import '../api/auth_api.dart';
import 'auth_tokens.dart';
import 'token_storage.dart';

/// 백엔드가 "탈퇴했지만 아직 되살릴 수 있는 계정" 을 알리는 에러 코드.
const String _withdrawalRestorableCode = 'U0007';

/// 탈퇴한 계정으로 로그인했을 때 던져진다. 실패가 아니라 **사용자에게 물어봐야 하는 분기**다
/// (이전 기록을 이어서 쓸지 = 철회 / 새로 시작할지 = 재가입).
///
/// [restoreTicket] 은 아직 살아 있는 카카오 access token — 어느 쪽을 고르든 카카오 로그인을 한 번 더
/// 태우지 않고 그대로 쓴다. 사용자가 취소하면 [AuthRepository.abandonRestore] 로 폐기할 것.
class WithdrawnAccountException implements Exception {
  const WithdrawnAccountException(this.message, this.restoreTicket);

  final String message;
  final String restoreTicket;

  @override
  String toString() => message;
}

/// 카카오 로그인 결과 — 로그인 직후 화면 분기에 필요한 플래그만 담는다.
class LoginOutcome {
  const LoginOutcome({
    required this.isNewUser,
    required this.consentRequired,
    required this.ageVerificationRequired,
  });

  final bool isNewUser;
  final bool consentRequired;

  /// 연령 확인 미완료. 동의보다 먼저 통과해야 하는 게이트 (미성년 판정 시 계정이 파기된다).
  final bool ageVerificationRequired;
}

/// 카카오 SDK 로그인 → 백엔드 JWT 교환 → secure storage 저장 흐름을 한 곳에 모음.
///
/// 정책:
/// - 카카오톡 설치 여부에 따라 `loginWithKakaoTalk` / `loginWithKakaoAccount` 분기.
/// - 백엔드 교환이 끝나면 카카오 SDK가 들고 있는 토큰은 즉시 폐기. 우리는 자체 JWT만 사용한다.
class AuthRepository {
  AuthRepository({required this.api, required this.storage});

  final AuthApi api;
  final TokenStorage storage;

  Future<bool> hasSession() async => (await storage.read()) != null;

  /// 카카오 로그인 → 백엔드 JWT 교환. 반환값으로 신규 가입 여부와 필수 동의 미완료 여부를 전달한다.
  /// LoginScreen 이 이 값으로 온보딩(신규) / 동의 게이트(기존 미동의) / 홈 을 분기.
  ///
  /// 탈퇴 계정이면 [WithdrawnAccountException] 을 던진다 — 화면이 철회 확인을 받고
  /// [restoreWithdrawnAccount] 또는 [abandonRestore] 로 이어가야 한다.
  Future<LoginOutcome> loginWithKakao() async {
    final OAuthToken kakaoToken = await _kakaoLogin();
    final AuthTokens tokens;
    try {
      tokens = await api.kakaoLogin(kakaoToken.accessToken);
    } catch (e) {
      final error = toApiException(e);
      if (error.code == _withdrawalRestorableCode) {
        // 여기서만 카카오 토큰을 폐기하지 않고 넘긴다. 폐기해버리면 철회를 고른 사용자가
        // 카카오 로그인을 처음부터 한 번 더 타야 한다.
        throw WithdrawnAccountException(error.message, kakaoToken.accessToken);
      }
      await _revokeKakaoSession();
      rethrow;
    }
    await storage.save(tokens);
    await _revokeKakaoSession();
    return _outcomeOf(tokens);
  }

  /// 탈퇴 철회 확정 — 계정을 되살리고 그대로 세션을 연다.
  /// [restoreTicket] 은 [WithdrawnAccountException] 이 넘겨준 카카오 access token.
  Future<LoginOutcome> restoreWithdrawnAccount(String restoreTicket) async {
    try {
      final tokens = await api.kakaoRestore(restoreTicket);
      await storage.save(tokens);
      return _outcomeOf(tokens);
    } finally {
      await _revokeKakaoSession();
    }
  }

  /// 재가입 확정 — 탈퇴 계정을 파기하고 새 계정으로 세션을 연다. **이전 기록은 복구할 수 없다.**
  /// 반환되는 outcome 은 `isNewUser=true` 라 화면은 온보딩(연령→동의→닉네임)으로 이어져야 한다.
  Future<LoginOutcome> rejoinAfterWithdrawal(String restoreTicket) async {
    try {
      final tokens = await api.kakaoRejoin(restoreTicket);
      await storage.save(tokens);
      return _outcomeOf(tokens);
    } finally {
      await _revokeKakaoSession();
    }
  }

  /// 철회·재가입 중 아무것도 고르지 않았을 때 — 남겨뒀던 카카오 세션을 정리한다.
  Future<void> abandonRestore() => _revokeKakaoSession();

  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {
      // 백엔드 호출 실패해도 로컬 토큰은 폐기.
    }
    await storage.clear();
  }

  LoginOutcome _outcomeOf(AuthTokens tokens) => LoginOutcome(
        isNewUser: tokens.isNewUser,
        consentRequired: tokens.consentRequired,
        ageVerificationRequired: tokens.ageVerificationRequired,
      );

  /// best-effort: 카카오 SDK 측 토큰 폐기. 우리는 자체 JWT 만 쓰므로 실패해도 흐름엔 영향 없음.
  Future<void> _revokeKakaoSession() async {
    try {
      await UserApi.instance.logout();
    } catch (_) {}
  }

  Future<OAuthToken> _kakaoLogin() async {
    final installed = await isKakaoTalkInstalled();
    if (installed) {
      try {
        return await UserApi.instance.loginWithKakaoTalk();
      } catch (e) {
        // 카카오톡 로그인 시 사용자가 카카오톡 진입 직후 취소하면 fallback 으로 계정 로그인.
        if (e is PlatformException && e.code == 'CANCELED') {
          rethrow;
        }
        return UserApi.instance.loginWithKakaoAccount();
      }
    }
    return UserApi.instance.loginWithKakaoAccount();
  }
}
