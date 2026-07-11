import 'package:flutter/foundation.dart';

/// 백엔드 `UserResponse` 매핑. 결과 카드의 닉네임 표시, '내 정보' 화면 등에 사용.
@immutable
class User {
  const User({
    required this.userId,
    required this.provider,
    required this.email,
    required this.nickname,
    required this.nicknameChangeAvailableFrom,
  });

  final int userId;

  /// 로그인 공급자 (`KAKAO` / `TEST` 등). 테스트 데이터 시딩 버튼을 `TEST` 계정에만 노출하는 데 사용.
  final String? provider;
  final String? email;
  final String? nickname;

  /// 다음 닉네임 변경이 가능해지는 시각. null = 지금 바로 변경 가능.
  /// 백엔드가 `nicknameChangedDt.toLocalDate().plusDays(1).atStartOfDay()` 로 계산해 내려준다.
  final DateTime? nicknameChangeAvailableFrom;

  factory User.fromJson(Map<String, dynamic> json) {
    final raw = json['nicknameChangeAvailableFrom'] as String?;
    return User(
      userId: (json['userId'] as num).toInt(),
      provider: json['provider'] as String?,
      email: json['email'] as String?,
      nickname: json['nickname'] as String?,
      nicknameChangeAvailableFrom: raw == null ? null : DateTime.parse(raw),
    );
  }

  bool get canChangeNicknameNow {
    final from = nicknameChangeAvailableFrom;
    if (from == null) return true;
    return !DateTime.now().isBefore(from);
  }
}
