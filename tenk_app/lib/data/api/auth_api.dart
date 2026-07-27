import 'package:dio/dio.dart';

import '../auth/auth_tokens.dart';
import 'api_response.dart';

/// 백엔드 `/api/auth/*` 엔드포인트 호출.
///
/// - `kakaoLogin`: 카카오 access token을 자체 JWT로 교환. 인증 불필요 → [_rawDio] 사용.
/// - `logout`: 현재 사용자의 모든 RT를 무효화. 인증 필요 → [_authDio] 사용.
///
/// `/api/auth/refresh`는 [AuthInterceptor] 내부에서만 직접 호출하므로 여기엔 노출 안 함.
class AuthApi {
  AuthApi({required Dio rawDio, required Dio authDio})
      : _rawDio = rawDio,
        _authDio = authDio;

  final Dio _rawDio;
  final Dio _authDio;

  Future<AuthTokens> kakaoLogin(String kakaoAccessToken) async {
    final res = await _rawDio.post(
      '/api/auth/kakao/login',
      data: {'accessToken': kakaoAccessToken},
    );
    return AuthTokens.fromJson(unwrapData(res.data));
  }

  /// 유예 기간이라 아직 남아 있는 탈퇴 계정을 되살리고 토큰을 받는다 (기록 유지).
  /// 카카오 로그인이 `U0007` 로 거부됐을 때, 사용자 확인을 받은 뒤에만 호출한다.
  Future<AuthTokens> kakaoRestore(String kakaoAccessToken) async {
    final res = await _rawDio.post(
      '/api/auth/kakao/restore',
      data: {'accessToken': kakaoAccessToken},
    );
    return AuthTokens.fromJson(unwrapData(res.data));
  }

  /// 탈퇴 계정을 즉시 파기하고 같은 카카오 계정으로 새로 가입한다 (기록 삭제).
  /// **되돌릴 수 없으므로** 반드시 2차 확인을 받은 뒤 호출할 것.
  Future<AuthTokens> kakaoRejoin(String kakaoAccessToken) async {
    final res = await _rawDio.post(
      '/api/auth/kakao/rejoin',
      data: {'accessToken': kakaoAccessToken},
    );
    return AuthTokens.fromJson(unwrapData(res.data));
  }

  Future<void> logout() async {
    await _authDio.post('/api/auth/logout');
  }
}
