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

  /// 닉네임 변경. 백엔드가 trim 후 1~50자 / 보안 문자 / 24시간 1회 제한을 검증한다.
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

  /// 성별 설정 (선택 항목). `null` 을 넘기면 미입력으로 되돌린다 — 수집 철회 경로라 막지 말 것.
  Future<User> updateGender(String? gender) async {
    final res = await _dio.patch('/api/users/me/gender', data: {'gender': gender});
    return User.fromJson(unwrapData(res.data));
  }

  /// 연령 확인(생년월일) 기록. 백엔드가 만 14세 이상인지 판정한다.
  /// 미만이면 계정이 즉시 파기되고 `U0006` 으로 거부되므로, 호출부는 그 코드를 반드시 분기할 것.
  Future<User> verifyAge(DateTime birthDate) async {
    final ymd = '${birthDate.year.toString().padLeft(4, '0')}-'
        '${birthDate.month.toString().padLeft(2, '0')}-'
        '${birthDate.day.toString().padLeft(2, '0')}';
    final res = await _dio.post('/api/users/me/birth-date', data: {'birthDate': ymd});
    return User.fromJson(unwrapData(res.data));
  }

  /// 회원 탈퇴 (soft delete + RT 일괄 무효화).
  ///
  /// [reason]·[detail] 은 **선택**이며 계정과 연결되지 않는 익명 통계로만 저장된다.
  /// 사유를 필수로 만들지 말 것 — 탈퇴가 가입보다 어려워진다.
  Future<void> withdraw({String? reason, String? detail}) async {
    await _dio.delete(
      '/api/users/me',
      data: reason == null ? null : {'reason': reason, 'detail': detail},
    );
  }
}
