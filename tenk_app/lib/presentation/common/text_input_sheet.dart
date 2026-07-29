import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// **원래 화면의 맥락을 유지한 채 한 값만 고쳐 쓰는** 공용 바텀시트.
///
/// 챌린지 이름 변경·export 자막 편집처럼 *뒤 화면을 계속 보면서* 텍스트 하나를 고치는 자리에 쓴다.
/// 반대로 '내 정보' 의 닉네임처럼 **내 속성을 편집하는 건 별도 화면**으로 뺀다 — 기준은
/// [CLAUDE.md] "모달 사용 기준".
///
/// 반환값 `null` 은 취소. 확인을 누르면 **trim 된 문자열**이 돌아온다.
Future<String?> showTextInputSheet({
  required BuildContext context,
  required String title,
  required String initial,
  String? description,
  String? hintText,
  int maxLength = 100,
  int maxLines = 1,
  String confirmLabel = '확인',
  String? resetValue,
  String? Function(String value)? validator,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => _TextInputSheet(
      title: title,
      initial: initial,
      description: description,
      hintText: hintText,
      maxLength: maxLength,
      maxLines: maxLines,
      confirmLabel: confirmLabel,
      resetValue: resetValue,
      validator: validator,
    ),
  );
}

class _TextInputSheet extends StatefulWidget {
  const _TextInputSheet({
    required this.title,
    required this.initial,
    required this.description,
    required this.hintText,
    required this.maxLength,
    required this.maxLines,
    required this.confirmLabel,
    required this.resetValue,
    required this.validator,
  });

  final String title;
  final String initial;
  final String? description;
  final String? hintText;
  final int maxLength;
  final int maxLines;
  final String confirmLabel;

  /// '기본값' 버튼이 되돌릴 값. null 이면 버튼 자체를 그리지 않는다 (자막 편집 전용 기능).
  final String? resetValue;
  final String? Function(String value)? validator;

  @override
  State<_TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<_TextInputSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial)
        ..selection = TextSelection.collapsed(offset: widget.initial.length);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop<String>(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final singleLine = widget.maxLines == 1;
    // 키보드가 올라오면 시트가 그만큼 밀려 올라가야 입력칸이 안 가린다.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: AppTypo.title),
          if (widget.description != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(widget.description!, style: AppTypo.caption),
          ],
          const SizedBox(height: AppSpacing.lg),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _controller,
              autofocus: true,
              maxLength: widget.maxLength,
              maxLines: widget.maxLines,
              minLines: 1,
              // 입력칸 룩은 app_theme 의 inputDecorationTheme 을 상속받는다 (border 를 박지 말 것).
              decoration: InputDecoration(hintText: widget.hintText),
              textInputAction: singleLine ? TextInputAction.done : null,
              onFieldSubmitted: singleLine ? (_) => _submit() : null,
              validator: widget.validator == null
                  ? null
                  : (raw) => widget.validator!(raw ?? ''),
            ),
          ),
          Row(
            children: [
              if (widget.resetValue != null)
                TextButton.icon(
                  onPressed: () => _controller.text = widget.resetValue!,
                  icon: const Icon(Icons.restore),
                  label: const Text('기본값'),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: _submit,
                child: Text(widget.confirmLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
