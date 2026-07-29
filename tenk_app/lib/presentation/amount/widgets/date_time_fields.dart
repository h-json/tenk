import 'package:flutter/material.dart';

import '../../challenge/_formatters.dart';
import '../../common/date_time_picker.dart';
import '../../common/tap_field_box.dart';

/// 기록 화면·수정 화면이 공유하는 `날짜 | 시간` 2칸 행.
///
/// 두 칸을 나눠 둔 이유: 예전 기록 화면은 한 칸을 탭하면 **날짜 → 시간 다이얼로그가
/// 연달아** 떠서, 시간만 고치고 싶어도 날짜를 한 번 통과해야 했다.
///
/// [onDateTap] 이 null 이면 날짜 칸은 읽기 전용으로 그린다 — 수정 화면은 도메인
/// 규칙상 **날짜를 바꿀 수 없다**(바꾸려면 삭제 후 재등록).
class DateTimeFields extends StatelessWidget {
  const DateTimeFields({
    super.key,
    required this.date,
    required this.time,
    required this.onTimeTap,
    this.onDateTap,
  });

  final DateTime date;
  final TimeOfDay time;
  final VoidCallback onTimeTap;

  /// null = 날짜 고정(읽기 전용).
  final VoidCallback? onDateTap;

  @override
  Widget build(BuildContext context) {
    final dateTap = onDateTap;
    return Row(
      children: [
        Expanded(
          child: dateTap == null
              ? TapFieldBox(
                  icon: Icons.event_busy_outlined,
                  text: formatDate(date),
                  muted: true,
                )
              : TapFieldBox(
                  icon: Icons.event_outlined,
                  text: formatDate(date),
                  onTap: dateTap,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TapFieldBox(
            icon: Icons.schedule_outlined,
            text: formatTimeOfDay(context, time),
            onTap: onTimeTap,
          ),
        ),
      ],
    );
  }
}
