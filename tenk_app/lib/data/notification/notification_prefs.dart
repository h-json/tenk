import 'package:flutter/foundation.dart';

/// 알림 설정 스냅샷. [AppSettings] 가 저장하고, 예약 계획 함수는 이 값만 본다.
///
/// **마스터 1 + 종류별 3 구조** — 리마인더만 끄고 확정 대기는 받고 싶은 사람이 있어서
/// 종류별이 필요하고, 전부 끄는 걸 세 번 탭하게 만들지 않으려고 마스터가 필요하다
/// (CLAUDE.md "알림").
@immutable
class NotificationPrefs {
  const NotificationPrefs({
    required this.enabled,
    required this.reminderEnabled,
    required this.deadlineEnabled,
    required this.finalizeEnabled,
    required this.reminderHour,
    required this.reminderMinute,
  });

  /// 기본 리마인더 시각 = **오후 9시**. 하루 지출이 거의 끝나 기록이 정확하고 무지출 판정도
  /// 확정에 가깝다. 잠들기 전이라 놓칠 확률도 낮다 (decisions.md "알림 기능" 결정 6).
  static const int defaultReminderHour = 21;
  static const int defaultReminderMinute = 0;

  /// 확정 대기 알림 시각 = **오전 10시(고정)**. 저녁 리마인더와 시간대를 갈라야 하루에 두 번
  /// 울려도 덜 피곤하고, "결과를 보러 오세요" 는 "기록하세요" 와 성격이 다르다.
  /// 사용자가 고르게 하지 않는다 — 고를 게 늘수록 설정 화면만 무거워진다.
  static const int finalizeHour = 10;

  /// 마스터. 권한을 승인하면 켜지고, 이게 꺼져 있으면 아무것도 예약하지 않는다.
  final bool enabled;
  final bool reminderEnabled;
  final bool deadlineEnabled;
  final bool finalizeEnabled;
  final int reminderHour;
  final int reminderMinute;

  /// 권한을 승인한 직후의 기본값 — **종류별 3개 모두 켜짐**. 권한을 승인했다는 건
  /// 알림을 원한다는 뜻이라 여기서 다시 고르게 하지 않는다.
  static const NotificationPrefs allOn = NotificationPrefs(
    enabled: true,
    reminderEnabled: true,
    deadlineEnabled: true,
    finalizeEnabled: true,
    reminderHour: defaultReminderHour,
    reminderMinute: defaultReminderMinute,
  );

  static const NotificationPrefs off = NotificationPrefs(
    enabled: false,
    reminderEnabled: true,
    deadlineEnabled: true,
    finalizeEnabled: true,
    reminderHour: defaultReminderHour,
    reminderMinute: defaultReminderMinute,
  );

  NotificationPrefs copyWith({
    bool? enabled,
    bool? reminderEnabled,
    bool? deadlineEnabled,
    bool? finalizeEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) {
    return NotificationPrefs(
      enabled: enabled ?? this.enabled,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      deadlineEnabled: deadlineEnabled ?? this.deadlineEnabled,
      finalizeEnabled: finalizeEnabled ?? this.finalizeEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
    );
  }
}
