import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import 'selection_sheet.dart';
import 'tap_field_box.dart';

/// 탭하면 [showSelectionSheet] 가 뜨는 **폼 필드**.
///
/// `DropdownButtonFormField` 를 대체한다. 드롭다운을 걷어내면서 **`validator` 를 잃지 않으려고**
/// [FormField] 로 감쌌다 — 그래서 `Form.validate()` 흐름(기록/수정 화면의 '저장' 검증)이 그대로 돈다.
///
/// ⚠️ 표시값은 부모가 준 [value] 를 쓰고, 검증값은 FormField 내부 상태를 쓴다. 둘은 이 위젯을
/// 통한 변경으로만 동기화되므로 **부모가 다른 경로로 [value] 를 바꾸면 검증값이 어긋난다**
/// (현재 호출부는 전부 이 위젯으로만 바꾼다).
class SelectionField<T> extends StatelessWidget {
  const SelectionField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.sheetTitle,
    required this.icon,
    this.hintText = '선택',
    this.sheetDescription,
    this.validator,
    this.enabled = true,
  });

  final T? value;
  final List<SelectionOption<T>> options;
  final ValueChanged<T> onChanged;

  /// 바텀시트 상단 제목.
  final String sheetTitle;
  final String? sheetDescription;

  /// 닫힌 상태의 칸 왼쪽 아이콘.
  final IconData icon;

  /// 값이 없을 때 보일 문구.
  final String hintText;

  final String? Function(T? value)? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: value,
      validator: validator,
      builder: (state) {
        final selected = _selectedOption();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TapFieldBox(
              icon: selected?.icon ?? icon,
              text: selected?.label ?? hintText,
              muted: selected == null,
              hasError: state.hasError,
              onTap: !enabled
                  ? null
                  : () async {
                      final picked = await showSelectionSheet<T>(
                        context: context,
                        title: sheetTitle,
                        description: sheetDescription,
                        options: options,
                        selected: value,
                      );
                      if (picked == null) return; // 취소
                      state.didChange(picked);
                      onChanged(picked);
                    },
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 0, 0),
                child: Text(
                  state.errorText!,
                  style: AppTypo.caption.copyWith(color: AppColors.danger),
                ),
              ),
          ],
        );
      },
    );
  }

  SelectionOption<T>? _selectedOption() {
    for (final option in options) {
      if (option.value == value) return option;
    }
    return null;
  }
}
