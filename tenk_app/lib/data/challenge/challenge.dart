import 'package:flutter/foundation.dart';

import '../badge/badge.dart';

enum ChallengeResult {
  success,
  fail;

  static ChallengeResult fromServer(String raw) {
    return switch (raw) {
      'SUCCESS' => ChallengeResult.success,
      'FAIL' => ChallengeResult.fail,
      _ => throw ArgumentError('Unknown ChallengeResult: $raw'),
    };
  }

  String get label => switch (this) {
        ChallengeResult.success => '성공',
        ChallengeResult.fail => '실패',
      };
}

/// 백엔드 챌린지 모델. 시작일/종료일은 모두 **양끝 포함** 날짜 (시각 없음).
///
/// `DateTime.parse("yyyy-MM-dd")`는 로컬 자정의 [DateTime]을 만든다. 시각 정보는 무의미하므로
/// 비교 시 [DateUtils.dateOnly] 등을 거치는 게 안전하다.
@immutable
class Challenge {
  const Challenge({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.targetAmount,
    required this.totalSpent,
    required this.balance,
    required this.result,
    required this.started,
    required this.finished,
    required this.badges,
  });

  final int id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int targetAmount;
  final int totalSpent;
  final int balance;
  final ChallengeResult? result;

  /// 오늘이 시작일에 도달했는지 (시작일 당일 포함).
  final bool started;

  /// 종료일이 지났는지 (종료일 당일은 still 진행 중).
  final bool finished;

  /// 이 챌린지 안에서 획득한 배지 (서버 응답 인라인). 미획득은 포함되지 않음 — 빈 리스트 가능.
  final List<AcquiredBadge> badges;

  bool get isBeforeStart => !started && result == null;
  bool get isInProgress => started && !finished && result == null;
  bool get awaitsFinalize => finished && result == null;

  factory Challenge.fromJson(Map<String, dynamic> json) {
    final resultRaw = json['result'] as String?;
    final badgesRaw = json['badges'] as List?;
    return Challenge(
      id: (json['challengeId'] as num).toInt(),
      name: json['name'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      targetAmount: (json['targetAmount'] as num).toInt(),
      totalSpent: (json['totalSpent'] as num).toInt(),
      balance: (json['balance'] as num).toInt(),
      result: resultRaw == null ? null : ChallengeResult.fromServer(resultRaw),
      started: json['started'] as bool,
      finished: json['finished'] as bool,
      badges: badgesRaw == null
          ? const []
          : badgesRaw
              .cast<Map<String, dynamic>>()
              .map(AcquiredBadge.fromJson)
              .toList(growable: false),
    );
  }
}
