/// 날짜·시간 선택 다이얼로그의 단일 진입점.
///
/// 화면에서 `showDatePicker`/`showTimePicker` 를 직접 부르지 말고 이 헬퍼를 쓴다.
/// 호출부가 4곳(챌린지 생성 시작/종료일, 기록 일시, 기록 수정 시간)으로 흩어져
/// 있어 각자 옵션을 박으면 화면마다 다른 picker 가 뜬다.
///
/// 한국어 라벨(확인/취소·오전/오후·요일)은 `MaterialLocalizations` 에서 오고,
/// 로케일은 `main.dart` 의 `MaterialApp` 이 `ko` 로 고정한다.
library;

import 'package:flutter/material.dart';

import 'wheel_time_picker.dart';

/// 날짜 선택. 달력 그리드 모드로 열고(키보드 입력 전환은 그대로 열어둠),
/// [initial] 이 [first]~[last] 밖이면 범위 안으로 당겨서 assert 를 피한다.
Future<DateTime?> pickTenkDate(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String? helpText,
}) async {
  final clamped = initial.isBefore(first)
      ? first
      : (initial.isAfter(last) ? last : initial);
  final picked = await showDatePicker(
    context: context,
    initialDate: clamped,
    firstDate: first,
    lastDate: last,
    helpText: helpText,
  );
  if (picked == null) return null;
  // 시각 성분을 남기지 않는다 — 호출부가 날짜만 쓰거나 별도 시각과 결합한다.
  return DateTime(picked.year, picked.month, picked.day);
}

/// 시각 선택.
///
/// **Material `showTimePicker` 를 쓰지 않는다** — 아날로그 시계(dial)가 분을 맞추기
/// 불편했고, 카카오톡 예약 메시지·갤럭시 알람처럼 익숙한 **휠(드럼)** 로 대체했다.
/// 구현은 [showWheelTimePicker] (오전·오후 / 시 1~12 무한순환 / 분 00~59 무한순환,
/// 가운데 탭하면 직접 입력, 시가 11↔12 경계를 넘으면 오전/오후 자동 전환).
/// **dial 로 되돌리지 말 것.**
Future<TimeOfDay?> pickTenkTime(
  BuildContext context, {
  required TimeOfDay initial,
  String? helpText,
}) {
  return showWheelTimePicker(context, initial: initial, helpText: helpText);
}

/// 폼에 박혀 있는 시각 표기. 기기 설정에 따라 `오후 10:11` 또는 `22:11`.
///
/// 24시간제로 고정한 자체 포맷을 `_formatters.dart` 에 두면 picker·기기 설정과
/// 표기가 갈라지므로(예전 `formatDateTime` 이 그 이유로 제거됐다), **화면에
/// 보이는 시각은 이 헬퍼로 통일**한다.
String formatTimeOfDay(BuildContext context, TimeOfDay time) =>
    time.format(context);

/// 날짜 + 시각을 한 줄로. 예: `2026-07-26 오후 10:11`.
String formatDateWithTime(BuildContext context, DateTime dt) {
  final d = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${d.year}-${two(d.month)}-${two(d.day)}';
  return '$date ${formatTimeOfDay(context, TimeOfDay.fromDateTime(d))}';
}
