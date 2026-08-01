import 'package:flutter/foundation.dart';

/// 알림 발신 채널 3종.
///
/// **배지 근접은 여기 없다** — 별도 채널이 아니라 [reminder] 의 문구 승격이다. 둘은 같은 시각에
/// 같은 말("오늘 기록해")을 해서, 나눠 두면 근접일에 두 번 울린다
/// (CLAUDE.md "알림", decisions.md "알림 기능" 결정 2).
enum NotificationKind {
  /// 매일 기록 리마인더. 사용자가 시각을 고른다.
  reminder,

  /// 챌린지 마지막 날. [reminder] 와 같은 시각이라 겹치면 하나로 합쳐진다.
  deadline,

  /// 종료됐는데 확정을 안 누른 챌린지. 저녁 리마인더와 시간대를 갈라 오전에 보낸다.
  finalizePending,
}

extension NotificationKindX on NotificationKind {
  /// Android 알림 채널 id. **종류마다 따로 두는 게 핵심** — 시스템 설정과 앱 설정이 1:1 로
  /// 맞아야 사용자가 시스템에서도 종류별로 끌 수 있다.
  String get channelId => switch (this) {
    NotificationKind.reminder => 'tenk_reminder',
    NotificationKind.deadline => 'tenk_deadline',
    NotificationKind.finalizePending => 'tenk_finalize',
  };

  String get channelName => switch (this) {
    NotificationKind.reminder => '기록 리마인더',
    NotificationKind.deadline => '챌린지 종료 임박',
    NotificationKind.finalizePending => '결과 확정 대기',
  };

  String get channelDescription => switch (this) {
    NotificationKind.reminder => '오늘 기록을 남기지 않았을 때 알려줘요.',
    NotificationKind.deadline => '챌린지 마지막 날에 알려줘요.',
    NotificationKind.finalizePending => '기간이 끝난 챌린지의 결과를 확인하라고 알려줘요.',
  };
}

/// 예약 한 건. [NotificationScheduler] 가 계획을 세우고 [NotificationService] 가 실제로 건다.
///
/// **id 는 종류·순번으로 고정한다** — 재예약이 전량 취소 후 다시 걸기라서 충돌만 없으면 되고,
/// 고정이어야 디버깅할 때 어떤 알림인지 바로 읽힌다.
@immutable
class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
  });

  final int id;
  final NotificationKind kind;

  /// 기기 로컬 벽시계 기준 발신 시각.
  final DateTime at;
  final String title;
  final String body;

  @override
  String toString() => 'ScheduledNotification($id, ${kind.name}, $at, "$body")';
}
