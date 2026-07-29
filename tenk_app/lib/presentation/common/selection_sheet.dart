import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// 바텀시트 선택지 하나. [value] 는 서버에 보낼 코드, [label]·[icon] 은 표시용.
@immutable
class SelectionOption<T> {
  const SelectionOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// **폼·목록 안에서 값 하나를 고르는** 공용 바텀시트.
///
/// 다이얼로그가 아니라 바텀시트인 이유는 엄지 닿는 곳에서 열리고 **뒤 맥락(입력 중인 폼,
/// 진행 중인 챌린지)이 계속 보이기** 때문이다. 파괴적 행동의 확인은 여기가 아니라
/// `AlertDialog` 소관 — 기준은 [CLAUDE.md] "모달 사용 기준" 참고.
///
/// 반환값 `null` 은 **취소**다. 그래서 '선택 안 함' 같은 빈 값을 선택지로 두려면
/// sentinel 을 쓸 것 — null 을 값으로 쓰면 취소와 구분되지 않는다.
Future<T?> showSelectionSheet<T>({
  required BuildContext context,
  required String title,
  required List<SelectionOption<T>> options,
  T? selected,
  String? description,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: ConstrainedBox(
        // 선택지가 많아도(카테고리 9종) 화면을 다 덮지 않게 — 뒤 맥락이 보이는 게 이 UI 의 요점.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypo.title),
                  if (description != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(description, style: AppTypo.caption),
                  ],
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                children: [
                  for (final option in options)
                    ListTile(
                      leading: option.icon == null ? null : Icon(option.icon),
                      title: Text(option.label),
                      trailing: option.value == selected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      selected: option.value == selected,
                      selectedColor: AppColors.primary,
                      onTap: () => Navigator.of(sheetContext).pop(option.value),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
