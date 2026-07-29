import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// 성별 편집 화면. '내 정보' 에서 push 로 열고, 선택 결과를 [GenderChoice] 로 pop 한다.
///
/// **다이얼로그가 아니라 화면인 이유**: '내 정보' 의 항목은 *내 속성*을 편집하는 설정형 드릴다운이라
/// 원래 화면을 떠나도 맥락이 끊기지 않는다. 반대로 폼 입력 중에 값 하나만 고르는 자리는 바텀시트다
/// — 기준은 [CLAUDE.md] "모달 사용 기준".
///
/// 선택 항목이므로 ① 수집 목적을 그 자리에서 고지하고 ② '입력 안 함'(수집 철회)을
/// 값들과 **동등한 칸**으로 노출한다. 이 둘은 정책 요건이라 빼지 말 것.
class GenderEditScreen extends StatefulWidget {
  const GenderEditScreen({super.key, required this.initial});

  /// 현재 값. `null` 이면 미입력.
  final String? initial;

  @override
  State<GenderEditScreen> createState() => _GenderEditScreenState();
}

/// 성별 선택 결과. `null` pop(=뒤로 가기)과 "입력 안 함으로 되돌리기"(`value == null`)를
/// 구분해야 해서 한 겹 감싼다.
@immutable
class GenderChoice {
  const GenderChoice(this.value);

  final String? value;
}

class _GenderEditScreenState extends State<GenderEditScreen> {
  /// '입력 안 함' 칸의 sentinel. `SegmentedButton` 의 선택 집합에 null 을 넣을 수 없어서
  /// 화면 안에서만 이 값을 쓰고, pop 직전에 null 로 되돌린다.
  static const _none = 'NONE';

  /// **가운데가 '입력 안 함'** 인 것은 요청된 배치다 (2026-07-29). 세그먼트가 3칸이라
  /// 좌우가 값, 가운데가 비움이 된다 — 순서를 바꾸면 익숙한 좌/우 대칭이 깨진다.
  static const _segments = <(String, String)>[
    ('MALE', '남성'),
    (_none, '입력 안 함'),
    ('FEMALE', '여성'),
  ];

  late String _selected = widget.initial ?? _none;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('성별')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            const Text('성별을 알려주실 수 있나요?', style: AppTypo.title),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              // 목적 고지 + 선택임을 같은 자리에서 밝힌다 (개인정보 최소수집 고지).
              '이용자 통계 목적으로만 사용해요. 입력하지 않아도 모든 기능을 그대로 이용할 수 있고, '
              '입력한 뒤에도 언제든 다시 바꾸거나 지울 수 있어요.',
              style: AppTypo.body,
            ),
            const SizedBox(height: AppSpacing.xxl),
            SegmentedButton<String>(
              segments: [
                for (final (code, label) in _segments)
                  ButtonSegment<String>(value: code, label: Text(label)),
              ],
              selected: {_selected},
              showSelectedIcon: false,
              onSelectionChanged: (next) =>
                  setState(() => _selected = next.first),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                GenderChoice(_selected == _none ? null : _selected),
              ),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}
