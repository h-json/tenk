/// 챌린지 화면들이 공유하는 작은 포맷 헬퍼. intl 의존성 회피용.
library;

String formatWon(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '${negative ? '-' : ''}${buf.toString()}원';
}

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
