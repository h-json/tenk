import '../../../data/badge/badge.dart';
import '../../../data/challenge/challenge.dart';

/// 배지 획득 모달에 띄울 "다음 목표" 한 줄. 없으면 null (그 줄을 통째로 생략).
///
/// **사다리를 그대로 읽어 오면 거짓말이 된다** — 챌린지에는 기간이 있어서 5일짜리
/// 챌린지는 7·14·30 단계를 처음부터 못 딴다. 남은 기간이 모자란 경우도 같다
/// (10일짜리라도 8일차에 STREAK 7 은 이미 불가능하다). 그래서 판정은 사다리가 아니라
/// `현재값 + 남은 일수 >= 다음 칸` 이다.
///
/// 도달 불가면 **챌린지 완주로 폴백한다. 이건 위로가 아니라 실제 다음 페이오프다** —
/// 사다리가 막혀도 `CHALLENGE_SUCCESS` 배지는 기간과 무관하게 살아 있다.
///
/// 현재값은 방금 받은 배지의 [AcquiredBadge.conditionValue] 로 본다. 배지는 칸을
/// 넘는 순간 지급되므로 획득 시점의 현재값과 같고, 이렇게 하면 연속/누적 집계를
/// 클라에서 다시 구현하지 않아도 된다 (서버가 진실의 원천).
String? badgeNextGoalText(
  AcquiredBadge badge,
  Challenge challenge,
  DateTime today,
) {
  // 확정된 챌린지는 다음이 없다. 성공 배지 자체도 사다리의 끝이라 표시하지 않는다
  // (finalize 직후엔 결과 카드로 이어진다).
  if (challenge.result != null) return null;
  if (badge.type == BadgeType.challengeSuccess) return null;

  final end = _dateOnly(challenge.endDate);
  final base = _dateOnly(today);
  final remainingDays = end.difference(base).inDays; // 오늘 이후 남은 날
  if (remainingDays < 0) return null; // 이미 종료 — 확정 대기 상태에서 늦게 지급된 경우

  final next = _nextRung(badge.conditionValue);
  if (next != null) {
    final need = next - badge.conditionValue;
    if (remainingDays >= need) {
      return switch (badge.type) {
        BadgeType.streak => '$need일 더 기록하면 $next일 연속 배지예요',
        BadgeType.noSpend => '$need일 더 무지출하면 무지출 $next일 배지예요',
        BadgeType.challengeSuccess => null, // 위에서 걸러짐
      };
    }
  }

  // 사다리가 막혔거나(기간·잔여일) 최고 단계에 도달 → 남은 진짜 목표는 완주다.
  if (remainingDays == 0) return '오늘이 챌린지 마지막 날이에요';
  return '챌린지 종료까지 $remainingDays일 남았어요';
}

/// [current] 바로 위 사다리 칸. 최고 단계면 null.
int? _nextRung(int current) {
  for (final rung in kBadgeLadder) {
    if (rung > current) return rung;
  }
  return null;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
