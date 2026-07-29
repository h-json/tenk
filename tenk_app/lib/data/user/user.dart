import 'package:flutter/foundation.dart';

/// 백엔드 `UserResponse` 매핑. 결과 카드의 닉네임 표시, '내 정보' 화면 등에 사용.
@immutable
class User {
  const User({
    required this.userId,
    required this.provider,
    required this.nickname,
    required this.nicknameChangeAvailableFrom,
    required this.consentRequired,
    required this.ageVerificationRequired,
    required this.gender,
    required this.role,
  });

  final int userId;

  /// 로그인 공급자 (`KAKAO` 등). 표시·감사용.
  final String? provider;

  /// 계정 권한 (`USER` / `TESTER`). 테스트 데이터 시딩 버튼을 `TESTER` 계정에만 노출하는 데 사용.
  final String? role;

  bool get isTester => role == 'TESTER';
  final String? nickname;

  /// 다음 닉네임 변경이 가능해지는 시각. null = 지금 바로 변경 가능.
  /// 백엔드가 `nicknameChangedDt + 24시간` 으로 계산해 내려준다 (날짜/자정 기준 아님 — 시각이 임의 값).
  final DateTime? nicknameChangeAvailableFrom;

  /// 필수 동의(이용약관 + 개인정보 수집·이용) 미완료 여부. true 면 동의 화면으로 게이트.
  final bool consentRequired;

  /// 연령 확인 미완료 여부. true 면 연령 확인 화면으로 게이트 — 동의보다 먼저 통과해야 한다.
  final bool ageVerificationRequired;

  /// 성별 (`MALE`/`FEMALE`). **선택 입력이라 null(미입력)이 정상 상태**이고 기능에 쓰이지 않는다.
  /// '내 정보' → 성별 화면에서만 입력·해제한다 (서버 enum 도 두 값뿐 — '기타'는 없다).
  final String? gender;

  factory User.fromJson(Map<String, dynamic> json) {
    final raw = json['nicknameChangeAvailableFrom'] as String?;
    return User(
      userId: (json['userId'] as num).toInt(),
      provider: json['provider'] as String?,
      nickname: json['nickname'] as String?,
      nicknameChangeAvailableFrom: raw == null ? null : DateTime.parse(raw),
      consentRequired: json['consentRequired'] as bool? ?? false,
      ageVerificationRequired: json['ageVerificationRequired'] as bool? ?? false,
      gender: json['gender'] as String?,
      role: json['role'] as String?,
    );
  }

  bool get canChangeNicknameNow {
    final from = nicknameChangeAvailableFrom;
    if (from == null) return true;
    return !DateTime.now().isBefore(from);
  }
}
