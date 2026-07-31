import 'package:flutter/foundation.dart';

/// 배지 단계(condition_value) 사다리. 서버 `badge` 테이블의 STREAK / NO_SPEND 4단계와
/// 일치한다 (CHALLENGE_SUCCESS 만 1로 예외).
///
/// **여기가 클라 쪽 단일 출처다** — 무지출 성취감 카드 게이지, 배지 획득 모달의
/// '다음 목표' 가 모두 이걸 쓴다. 사본을 새로 만들지 말 것. 카탈로그를 바꿀 땐
/// CLAUDE.md "배지 카탈로그 변경" 의 네 곳을 같이 갱신한다.
const List<int> kBadgeLadder = [3, 7, 14, 30];

/// 챌린지 단위 배지 타입.
///
/// 유저 단위 누적 "업적" 은 별도 시스템으로 추후 추가 예정.
enum BadgeType {
  streak,
  noSpend,
  challengeSuccess;

  static BadgeType fromServer(String raw) {
    return switch (raw) {
      'STREAK' => BadgeType.streak,
      'NO_SPEND' => BadgeType.noSpend,
      'CHALLENGE_SUCCESS' => BadgeType.challengeSuccess,
      _ => throw ArgumentError('Unknown BadgeType: $raw'),
    };
  }

  /// ⚠️ NO_SPEND 는 **누적**이지 연속이 아니다 — 끊겼다가 다시 무지출해도 합산된다
  /// (CLAUDE.md "배지"). 한때 '무지출 연속' 으로 잘못 적혀 있어 사용자에게 규칙을
  /// 반대로 알려주고 있었다. 되돌리지 말 것.
  String get label => switch (this) {
        BadgeType.streak => '연속 기록',
        BadgeType.noSpend => '무지출 누적',
        BadgeType.challengeSuccess => '챌린지 성공',
      };
}

/// 한 챌린지 안에서 획득한 배지 1건. 챌린지 응답의 `badges` 배열 원소로 인라인됨.
@immutable
class AcquiredBadge {
  const AcquiredBadge({
    required this.challengeBadgeId,
    required this.badgeId,
    required this.type,
    required this.conditionValue,
    required this.iconPath,
    required this.acquiredDt,
  });

  final int challengeBadgeId;
  final int badgeId;
  final BadgeType type;
  final int conditionValue;

  /// 서버가 내려주는 경로 (예: `/badges/streak_3.png`).
  /// 자산 경로로 변환: 앞의 `/` 떼고 `assets/` 붙임 → `assets/badges/streak_3.png`.
  final String iconPath;
  String get assetPath => 'assets/badges/${iconPath.split('/').last}';

  final DateTime acquiredDt;

  /// "3일 연속 기록", "무지출 7일", "챌린지 성공" 같은 짧은 라벨.
  String get label => switch (type) {
        BadgeType.streak => '$conditionValue일 연속',
        BadgeType.noSpend => '무지출 $conditionValue일',
        BadgeType.challengeSuccess => '챌린지 성공',
      };

  factory AcquiredBadge.fromJson(Map<String, dynamic> json) {
    return AcquiredBadge(
      challengeBadgeId: (json['challengeBadgeId'] as num).toInt(),
      badgeId: (json['badgeId'] as num).toInt(),
      type: BadgeType.fromServer(json['type'] as String),
      conditionValue: (json['conditionValue'] as num).toInt(),
      iconPath: json['iconPath'] as String,
      acquiredDt: DateTime.parse(json['acquiredDt'] as String),
    );
  }
}
