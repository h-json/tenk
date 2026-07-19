/// 백엔드가 발급한 자체 JWT 한 쌍.
///
/// [isNewUser] 는 카카오 로그인 응답에서만 의미 있음 (이번 호출이 신규 가입을 만들었는지).
/// refresh 응답이나 storage 에서 복원한 토큰은 항상 false. 저장되지도 않는다.
class AuthTokens {
  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.isNewUser = false,
    this.consentRequired = false,
  });

  final String accessToken;
  final String refreshToken;
  final bool isNewUser;

  /// 필수 동의 미완료 여부. 로그인 응답에서만 의미 있음 (storage 복원 토큰은 항상 false).
  /// 로그인 직후 동의 게이트 분기에 사용.
  final bool consentRequired;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        isNewUser: json['isNewUser'] as bool? ?? false,
        consentRequired: json['consentRequired'] as bool? ?? false,
      );
}
