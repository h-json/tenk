import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// 채움(surfaceAlt) **탭 필드** — 탭하면 picker·바텀시트가 뜨는 칸의 공용 룩.
///
/// 날짜·시간·카테고리·의견 유형이 모두 이걸 쓴다. 텍스트 입력칸은 app_theme 의
/// `inputDecorationTheme` 을 상속받고, 탭 필드는 이 위젯이 같은 룩을 재현한다
/// ([CLAUDE.md] "폼 규칙" — 탭 필드는 `Material(surfaceAlt)+InkWell` 채움 패턴으로 통일).
class TapFieldBox extends StatelessWidget {
  const TapFieldBox({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
    this.muted = false,
    this.hasError = false,
  });

  final IconData icon;
  final String text;

  /// null 이면 읽기 전용으로 그린다 (잉크 효과·펼침 아이콘 없음).
  final VoidCallback? onTap;

  /// 값이 아직 없거나(placeholder) 읽기 전용일 때 흐리게.
  final bool muted;

  /// 검증 실패 표시 — 채움 위에 danger 보더를 얹는다.
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 15);
    final tap = onTap;
    final borderRadius = BorderRadius.circular(AppRadius.chip);
    final row = Row(
      children: [
        Icon(icon, size: 20, color: AppColors.inkMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: muted
                ? AppTypo.body.copyWith(color: AppColors.inkMuted)
                : AppTypo.body,
          ),
        ),
        if (tap != null)
          const Icon(Icons.expand_more, color: AppColors.inkMuted),
      ],
    );

    final border = hasError
        ? Border.all(color: AppColors.danger, width: 1.5)
        : null;

    if (tap == null) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: borderRadius,
          border: border,
        ),
        child: row,
      );
    }
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: border,
          ),
          child: row,
        ),
      ),
    );
  }
}
