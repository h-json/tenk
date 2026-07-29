import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../common/field_label.dart';

/// 닉네임 변경 화면. '내 정보' 에서 push 로 열고 확정된 닉네임을 pop 한다 (취소면 null).
///
/// **신규 가입용 [NicknameSetupScreen] 과 별개다** — 저쪽은 온보딩 단계라 back 이 막혀 있고
/// 여기는 언제든 되돌아갈 수 있다. 둘을 합치지 말 것.
///
/// 다이얼로그가 아니라 화면인 이유는 [GenderEditScreen] 과 같다 — '내 정보' 의 항목은
/// *내 속성* 편집이라 화면으로 뺀다 ([CLAUDE.md] "모달 사용 기준").
class NicknameEditScreen extends StatefulWidget {
  const NicknameEditScreen({super.key, required this.initial});

  final String initial;

  @override
  State<NicknameEditScreen> createState() => _NicknameEditScreenState();
}

class _NicknameEditScreenState extends State<NicknameEditScreen> {
  // 서버 UserService.NICKNAME_FORBIDDEN_CHARS 와 같은 패턴 (1차 검증). 진실의 원천은 서버.
  static final RegExp _forbiddenChars = RegExp(r'[\p{Cc}\p{Cf}]', unicode: true);
  static const int _maxLength = 50;

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
    return Scaffold(
      appBar: AppBar(title: const Text('닉네임 변경')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              const FieldLabel('닉네임', required: true),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _controller,
                // 값이 이미 채워져 있지만 이 화면은 '닉네임을 고치는' 단일 목적이라 autofocus 가 맞다.
                autofocus: true,
                maxLength: _maxLength,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(hintText: '새 닉네임'),
                validator: (raw) {
                  final v = (raw ?? '').trim();
                  if (v.isEmpty) return '닉네임을 입력해주세요.';
                  if (v.length > _maxLength) {
                    return '$_maxLength자 이하로 입력해주세요.';
                  }
                  if (_forbiddenChars.hasMatch(v)) {
                    return '사용할 수 없는 문자가 포함돼 있어요.';
                  }
                  return null;
                },
              ),
              const Text(
                '변경 후 24시간 동안은 다시 변경할 수 없어요.',
                style: TextStyle(fontSize: 12, color: AppColors.inkSub),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FilledButton(onPressed: _submit, child: const Text('변경')),
            ],
          ),
        ),
      ),
    );
  }
}
