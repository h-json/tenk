import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// 본문 + **하단 액션**을 하나의 스크롤 안에 담는 레이아웃.
///
/// 공간이 남으면 [actions] 를 바닥에 붙여 *하단 고정처럼* 보이게 하고, 모자라면 본문과 함께
/// 스크롤된다. 키보드가 없을 때의 모습은 `Column(Expanded(스크롤) + 고정 버튼)` 과 픽셀 단위로
/// 같고, 키보드가 떠도 입력칸이 버튼에 잘리지 않는다.
///
/// ⚠️ **키보드가 뜨는 화면에서 하단 CTA 를 `Column` 의 고정 자식으로 두지 말 것.** 키보드가 먹은
/// 높이를 스크롤 영역 혼자 떠안아 짜부라지고, 결국 입력칸이 버튼 밑으로 잘린다 — 2026-08-03 실측:
/// 560dp 화면 + 키보드 300 에서 연령 확인 화면의 스크롤 영역이 **38px** 로 줄어 입력칸(56px)이
/// 버튼에 덮였다. 회귀 가드는 `test/keyboard_layout_test.dart`.
///
/// 본문이 `ListView` 이고 버튼이 그 마지막 항목인 화면(기록·챌린지 생성·닉네임 변경)은 이미 같은
/// 성질을 갖는다 — 이 위젯은 **버튼을 바닥에 붙여야 하는** 게이트/온보딩 화면용이다.
class BottomActionScrollView extends StatelessWidget {
  const BottomActionScrollView({
    super.key,
    required this.body,
    required this.actions,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 24),
    this.minActionGap = AppSpacing.xxl,
    this.spacerFlex = 1,
  });

  /// 위쪽 본문. 세로로 넘치면 스크롤된다.
  ///
  /// (`children` 이 아니라 `body` 인 건 `sort_child_properties_last` 린트 때문 — 이 위젯은
  /// 본문이 먼저, 액션이 나중이어야 읽힌다.)
  final List<Widget> body;

  /// 바닥에 붙는 액션들 (주 CTA + 보조 버튼 등).
  final List<Widget> actions;

  final EdgeInsets padding;

  /// 본문과 액션 사이에 **항상** 남는 최소 여백.
  ///
  /// [Spacer] 는 내용이 넘치는 순간 0 으로 접히므로, 그것만으로는 좁은 화면·키보드 상태에서
  /// 본문 마지막 줄과 버튼이 맞붙는다(2026-08-03 실기기 확인 — 연령 확인 화면의 안내문과
  /// 확인 버튼 사이가 11dp 까지 좁아졌다). 그래서 접히지 않는 고정 여백을 따로 둔다.
  final double minActionGap;

  /// 본문과 액션 사이 [Spacer] 의 flex. 본문 위쪽에도 `Spacer` 를 두는 화면(알림 권유)에서
  /// 위:아래 비율을 맞추는 용도 — 그 외에는 기본값 그대로 두면 된다.
  final int spacerFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 뷰포트만큼을 최소 높이로 주면 내용이 짧을 때 Spacer 가 액션을 바닥까지 밀어낸다.
        // 내용이 길면 minHeight 를 넘겨 자라고 그만큼 스크롤된다.
        final minHeight =
            (constraints.maxHeight - padding.vertical).clamp(0.0, double.infinity);
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            // Spacer(=Expanded)는 높이가 정해져야 하는데 스크롤 안은 unbounded 라
            // IntrinsicHeight 로 한 번 확정시킨다 (Flutter 공식 recipe).
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...body,
                  // 이 둘의 역할이 다르다: SizedBox 는 **접히지 않는 최소 여백**,
                  // Spacer 는 남는 공간을 먹어 액션을 바닥까지 미는 역할.
                  SizedBox(height: minActionGap),
                  Spacer(flex: spacerFlex),
                  ...actions,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
