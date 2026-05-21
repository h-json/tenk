import 'package:flutter/foundation.dart';

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

  String get label => switch (this) {
        BadgeType.streak => '연속 기록',
        BadgeType.noSpend => '무지출 연속',
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
