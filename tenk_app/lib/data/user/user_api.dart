import 'package:dio/dio.dart';

import '../api/api_response.dart';
import 'user.dart';

/// 백엔드 `/api/users/*` 엔드포인트.
class UserApi {
  UserApi({required Dio authDio}) : _dio = authDio;

  final Dio _dio;

  Future<User> getMe() async {
    final res = await _dio.get('/api/users/me');
    return User.fromJson(unwrapData(res.data));
  }

  /// 닉네임 변경. 백엔드가 trim 후 1~50자 / 보안 문자 / 하루 1회 제한을 검증한다.
  /// 성공 시 갱신된 사용자 정보 반환 (nicknameChangeAvailableFrom 도 새 값).
  Future<User> updateNickname(String nickname) async {
    final res = await _dio.patch(
      '/api/users/me/nickname',
      data: {'nickname': nickname},
    );
    return User.fromJson(unwrapData(res.data));
  }

  /// 필수 동의(이용약관 + 개인정보 수집·이용) 기록. 두 항목을 모두 체크한 뒤 호출한다.
  /// 성공 시 갱신된 사용자 정보 반환 (consentRequired=false).
  Future<User> agreeConsents() async {
    final res = await _dio.post('/api/users/me/consent');
    return User.fromJson(unwrapData(res.data));
  }

  /// 회원 탈퇴 (soft delete + RT 일괄 무효화).
  Future<void> withdraw() async {
    await _dio.delete('/api/users/me');
  }
}
