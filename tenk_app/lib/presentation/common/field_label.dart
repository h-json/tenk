import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// 폼 필드 위에 붙는 라벨. 필수 항목은 빨간 별표(*), 선택 항목은 " (선택)" 를 붙여
/// 전 폼이 일관되게 필수/선택을 표시하도록 한다.
class FieldLabel extends StatelessWidget {
  const FieldLabel(
    this.text, {
    super.key,
    this.required = false,
    this.optional = false,
  });

  final String text;

  /// 필수 항목 → 빨간 별표.
  final bool required;

  /// 선택 항목 → 회색 "(선택)".
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: AppTypo.title.copyWith(fontSize: 15),
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (optional)
            TextSpan(text: '  (선택)', style: AppTypo.caption),
        ],
      ),
    );
  }
}
