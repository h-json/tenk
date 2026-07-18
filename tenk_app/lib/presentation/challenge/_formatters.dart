/// 챌린지 화면들이 공유하는 작은 포맷 헬퍼. intl 의존성 회피용.
library;

/// 천 단위 콤마만 넣은 숫자 (단위 "원" 없음). 금액 히어로에서 "원"을 별도 스타일로
/// 붙일 때 사용.
String formatNumber(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '${negative ? '-' : ''}${buf.toString()}';
}

String formatWon(int amount) => '${formatNumber(amount)}원';

String formatDate(DateTime dt) {
  final d = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

String formatPeriod(DateTime start, DateTime end) =>
    '${formatDate(start)} ~ ${formatDate(end)}';

String formatDateTime(DateTime dt) {
  final d = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

const _koreanWeekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 챌린지 상세의 날짜별 그룹 헤더용. 예: "5월 21일 (수)".
String formatDayHeader(DateTime dt) {
  final d = dt.toLocal();
  final weekday = _koreanWeekdays[(d.weekday - 1) % 7];
  return '${d.month}월 ${d.day}일 ($weekday)';
}

/// 시각 부분 0 으로 자른 같은 날짜 비교용 키. amounts 를 day 별로 그룹화할 때 사용.
DateTime dateOnly(DateTime dt) {
  final d = dt.toLocal();
  return DateTime(d.year, d.month, d.day);
}

/// 진행 중 챌린지의 D-day 라벨. 종료일 당일까지 진행이므로 종료일 포함.
/// 예: "D-3", 종료일 당일이면 "오늘 마감".
String formatDday(DateTime endDate, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final end = dateOnly(endDate);
  final diff = end.difference(today).inDays;
  if (diff <= 0) return '오늘 마감';
  return 'D-$diff';
}

/// 시작 전 챌린지의 시작일 라벨. 예: "8/1 시작".
String formatStartsOn(DateTime startDate) {
  final d = startDate.toLocal();
  return '${d.month}/${d.day} 시작';
}

/// 짧은 기간 표기 (완료 카드 등 좁은 곳). 예: "6/1 ~ 6/30".
String formatShortPeriod(DateTime start, DateTime end) {
  final s = start.toLocal();
  final e = end.toLocal();
  return '${s.month}/${s.day} ~ ${e.month}/${e.day}';
}
