import '../badge/badge.dart';
import '../challenge/challenge.dart';
import 'notification_kind.dart';
import 'notification_prefs.dart';

/// 며칠 앞까지 리마인더를 미리 걸어둘지.
///
/// 매일 반복(`DateTimeComponents.time`)을 안 쓰는 이유는 **날마다 문구가 다르고 "오늘은 건너뛰기"
/// 가 필요하기 때문**이다. 반복 알림은 하루만 빼는 게 불가능하다. 대신 날짜별로 따로 걸고
/// 앱을 열 때마다 전량 다시 건다.
///
/// 14일인 건 iOS 의 **대기 알림 64건 상한** 때문 — 리마인더 14 + 마감 N + 확정 2N 이 그 안에
/// 넉넉히 들어간다. 2주 넘게 앱을 안 연 사용자는 알림이 아니라 다른 게 필요하다.
const int kReminderHorizonDays = 14;

/// 알림 id. 전량 취소 후 재예약이라 충돌만 없으면 되지만, 고정값이어야 로그에서 바로 읽힌다.
const int _reminderIdBase = 1000;
const int _finalizeIdBase = 2000;

/// 챌린지 목록과 설정으로 **예약 계획**을 세운다. 부수효과 없는 순수 함수 —
/// 실제 예약은 [NotificationService] 가 한다.
///
/// 규칙 (CLAUDE.md "알림"):
/// - 같은 시각에 겹치면 **발신 1개 + 문구 우선순위** (마지막 날 > 배지 근접 > 평소)
/// - 같은 종류가 여러 챌린지에 걸리면 **묶어서 1개**
/// - 진행 중 챌린지가 0개면 리마인더를 **예약조차 안 한다**
/// - 오늘 이미 기록했으면 **오늘 것만 건너뛴다**
List<ScheduledNotification> buildNotificationPlan({
  required List<Challenge> challenges,
  required NotificationPrefs prefs,
  required DateTime now,
  DateTime? lastRecordedDate,
}) {
  if (!prefs.enabled) return const [];

  final today = _dateOnly(now);
  final recordedToday =
      lastRecordedDate != null && _dateOnly(lastRecordedDate) == today;
  final plan = <ScheduledNotification>[];

  // ── 리마인더 + 종료 임박 (같은 시각이라 한 루프에서 병합) ─────────────────
  if (prefs.reminderEnabled || prefs.deadlineEnabled) {
    for (var offset = 0; offset < kReminderHorizonDays; offset++) {
      final day = today.add(Duration(days: offset));
      final at = DateTime(
        day.year,
        day.month,
        day.day,
        prefs.reminderHour,
        prefs.reminderMinute,
      );
      if (!at.isAfter(now)) continue; // 오늘 그 시각이 이미 지났다

      final active = challenges
          .where((c) => _isActiveOn(c, day))
          .toList(growable: false);
      if (active.isEmpty) continue; // 그 날 기록할 챌린지가 없으면 보낼 이유가 없다
      if (offset == 0 && recordedToday) continue; // 오늘은 이미 기록했다

      final lastDayOnes = active
          .where((c) => _dateOnly(c.endDate) == day)
          .toList(growable: false);

      // 문구 우선순위 — 마지막 날 > 배지 근접 > 평소.
      if (prefs.deadlineEnabled && lastDayOnes.isNotEmpty) {
        plan.add(
          ScheduledNotification(
            id: _reminderIdBase + offset,
            kind: NotificationKind.deadline,
            at: at,
            title: '오늘이 마지막 날이에요',
            body: lastDayOnes.length == 1
                ? '\'${lastDayOnes.single.name}\' 의 마지막 날이에요. 오늘 기록을 남겨주세요.'
                : '마지막 날인 챌린지가 ${lastDayOnes.length}개 있어요. 오늘 기록을 남겨주세요.',
          ),
        );
        continue;
      }
      if (!prefs.reminderEnabled) continue;

      // 배지 근접은 **오늘만** 정확히 판정한다. 내일 이후는 오늘 기록했는지에 따라 값이
      // 달라져 추측이 되는데, 앱을 열면 어차피 다시 계산되므로 평소 문구로 둔다.
      final nearBadge = offset == 0 ? _nearestBadge(active) : null;
      plan.add(
        ScheduledNotification(
          id: _reminderIdBase + offset,
          kind: NotificationKind.reminder,
          at: at,
          title: nearBadge != null ? '배지가 하루 남았어요' : '오늘 기록하셨나요?',
          body: nearBadge ?? '오늘 기록이 아직 없어요. 지출이든 무지출이든 남겨보세요.',
        ),
      );
    }
  }

  // ── 확정 대기 ────────────────────────────────────────────────────────────
  // 아직 확정하지 않은 챌린지는 **종료 다음 날 + 3일 뒤** 오전에 알린다. 확정을 안 누르면
  // 배지·결과 카드 페이오프가 영영 묻히는 구조라 한 번은 약하고, 그 이상은 잔소리다.
  if (prefs.finalizeEnabled) {
    final byDay = <DateTime, int>{};
    for (final c in challenges) {
      if (c.result != null) continue;
      final end = _dateOnly(c.endDate);
      for (final gap in const [1, 4]) {
        final day = end.add(Duration(days: gap));
        final at = DateTime(
          day.year,
          day.month,
          day.day,
          NotificationPrefs.finalizeHour,
          0,
        );
        if (!at.isAfter(now)) continue;
        byDay.update(at, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final days = byDay.keys.toList()..sort();
    for (var i = 0; i < days.length; i++) {
      final count = byDay[days[i]]!;
      plan.add(
        ScheduledNotification(
          id: _finalizeIdBase + i,
          kind: NotificationKind.finalizePending,
          at: days[i],
          title: '결과를 확인해 보세요',
          body: count == 1
              ? '기간이 끝난 챌린지가 있어요. 확정하고 결과를 확인해 보세요.'
              : '기간이 끝난 챌린지가 $count개 있어요. 확정하고 결과를 확인해 보세요.',
        ),
      );
    }
  }

  return plan;
}

/// 그 날 기록을 남길 수 있는 챌린지인가 (기간 안 + 아직 확정 전).
bool _isActiveOn(Challenge challenge, DateTime day) {
  if (challenge.result != null) return false;
  final start = _dateOnly(challenge.startDate);
  final end = _dateOnly(challenge.endDate);
  return !day.isBefore(start) && !day.isAfter(end);
}

/// "오늘 기록하면 배지" 가 성립하는 챌린지가 있으면 그 문구. 없으면 null.
///
/// 현재값은 **서버가 준 값**([Challenge.currentStreak] / [Challenge.noSpendDays])을 쓴다 —
/// 배지 지급과 같은 계산기라 여기가 약속한 것과 실제 지급이 어긋나지 않는다.
/// 연속이 무지출보다 강한 동기라 STREAK 을 먼저 본다.
String? _nearestBadge(List<Challenge> active) {
  for (final c in active) {
    if (kBadgeLadder.contains(c.currentStreak + 1)) {
      return '오늘 기록하면 ${c.currentStreak + 1}일 연속 배지를 받아요.';
    }
  }
  for (final c in active) {
    if (kBadgeLadder.contains(c.noSpendDays + 1)) {
      return '오늘 무지출을 기록하면 무지출 ${c.noSpendDays + 1}일 배지를 받아요.';
    }
  }
  return null;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
