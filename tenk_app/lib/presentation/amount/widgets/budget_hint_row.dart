import 'package:flutter/material.dart';

import '../../challenge/_formatters.dart';

/// 금액 입력칸 하단 보조 표시. 좌: 입력한 금액 에코(없으면 빈칸) / 우: "잔액 ○원".
/// 우측 잔액이 음수(예산 초과)면 error 색으로 강조.
///
/// `remaining` 은 호출자가 계산해 넘긴다:
/// - record 화면: `balance - 입력값` (입력 전엔 balance 그대로)
/// - edit 화면: `balance + 기존금액 - 입력값` (balance 가 이 기록을 이미 포함하므로 되더함)
class BudgetHintRow extends StatelessWidget {
  const BudgetHintRow({
    super.key,
    required this.entered,
    required this.remaining,
  });

  /// 입력된 금액. null = 입력 없음 → 좌측 비움.
  final int? entered;

  /// 우측에 "잔액 ○원" 으로 표시할 금액.
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = remaining < 0;
    final baseStyle = theme.textTheme.bodySmall;
    return Row(
      children: [
        Expanded(
          child: Text(
            entered == null ? '' : formatWon(entered!),
            style: baseStyle,
          ),
        ),
        Text(
          '잔액 ${formatWon(remaining)}',
          style: baseStyle?.copyWith(
            fontWeight: FontWeight.w600,
            color: over ? theme.colorScheme.error : null,
          ),
        ),
      ],
    );
  }
}
