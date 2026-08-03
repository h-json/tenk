/// 하단 액션이 **시스템 내비 바나 키보드에 잘리지 않는지** 지키는 회귀 가드.
///
/// 실기기에서 두 번 깨졌던 자리라 규칙(주석·CLAUDE.md) 대신 테스트가 지킨다:
/// - `bottomNavigationBar` 슬롯은 Scaffold 가 inset 을 넣어주지 않는다 → `SafeArea` 필수
/// - 바텀시트도 화면 바닥에 붙으므로 마찬가지
/// - 키보드가 뜨는 화면에서 하단 CTA 를 `Column` 의 **고정 자식**으로 두면 스크롤 영역만
///   짜부라져 입력칸이 버튼 밑으로 잘린다 → [BottomActionScrollView] 를 쓸 것
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenk_app/design/tokens.dart';
import 'package:tenk_app/presentation/common/bottom_action_scroll_view.dart';
import 'package:tenk_app/presentation/common/text_input_sheet.dart';
import 'package:tenk_app/presentation/feedback/feedback_screen.dart';
import 'package:tenk_app/presentation/legal/age_gate_screen.dart';
import 'package:tenk_app/presentation/legal/consent_gate_screen.dart';
import 'package:tenk_app/presentation/notification/notification_priming_screen.dart';
import 'package:tenk_app/presentation/profile/withdraw_screen.dart';

/// 제스처 내비 바 높이(삼성 실기기 기준 근사값).
const double _navBar = 24;

/// 화면 크기 + 키보드 인셋을 강제로 박고 그린다.
///
/// 키보드가 뜨면 `padding.bottom` 이 0 이 되는 실기기 규칙을 그대로 재현한다 —
/// 이게 없으면 `SafeArea` 와 `viewInsets` 가 이중 가산되는 버그를 못 잡는다.
Widget _host(Widget child, {required Size size, double keyboard = 0}) {
  return MediaQuery(
    data: MediaQueryData(
      size: size,
      viewPadding: const EdgeInsets.only(top: 24, bottom: _navBar),
      padding: EdgeInsets.only(top: 24, bottom: keyboard > 0 ? 0 : _navBar),
      viewInsets: EdgeInsets.only(bottom: keyboard),
    ),
    child: MaterialApp(locale: const Locale('ko'), home: child),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(360, 640),
  double keyboard = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(child, size: size, keyboard: keyboard));
  await tester.pumpAndSettle();
}

void main() {
  group('하단 고정 액션 — 제스처 바에 잘리지 않는다', () {
    testWidgets('의견 보내기의 보내기 버튼', (tester) async {
      await _pump(tester, const FeedbackScreen());
      final button = tester.getRect(find.widgetWithText(FilledButton, '보내기'));
      expect(button.bottom, lessThanOrEqualTo(640 - _navBar));
    });

    testWidgets('회원 탈퇴의 탈퇴하기 버튼', (tester) async {
      await _pump(tester, const WithdrawScreen());
      final button = tester.getRect(find.widgetWithText(FilledButton, '탈퇴하기'));
      expect(button.bottom, lessThanOrEqualTo(640 - _navBar));
    });

    testWidgets('텍스트 입력 바텀시트의 확인 버튼', (tester) async {
      late BuildContext ctx;
      await _pump(
        tester,
        Scaffold(body: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        })),
      );
      showTextInputSheet(context: ctx, title: '챌린지 이름 변경', initial: '외식 줄이기');
      await tester.pumpAndSettle();
      final button = tester.getRect(find.widgetWithText(FilledButton, '확인'));
      expect(button.bottom, lessThanOrEqualTo(640 - _navBar));
    });
  });

  group('키보드가 떠도 입력칸이 하단 액션에 잘리지 않는다', () {
    // 이 조합(작은 화면 + 키보드)이 실제 결함 재현 조건이었다. 고치기 전 실측값은 **-14**
    // (= 확인 버튼이 입력칸을 14px 덮음).
    testWidgets('연령 확인 — 560dp 화면 + 키보드 300', (tester) async {
      await _pump(
        tester,
        const AgeGateScreen(),
        size: const Size(360, 560),
        keyboard: 300,
      );
      final field = tester.getRect(find.byType(TextField).first);
      final button = tester.getRect(find.widgetWithText(ElevatedButton, '확인'));
      expect(field.bottom, lessThanOrEqualTo(button.top));
      expect(tester.takeException(), isNull);
    });

    // 잘리지 않는 것만으로는 부족하다 — 본문 마지막 줄과 버튼이 맞붙으면 읽기 나쁘다.
    // 실기기에서 11dp 까지 좁아진 걸 보고 최소 여백을 규칙으로 박았다.
    testWidgets('연령 확인 — 넘치는 상황에서도 본문과 버튼 사이 최소 여백이 남는다', (tester) async {
      await _pump(
        tester,
        const AgeGateScreen(),
        size: const Size(360, 560),
        keyboard: 300,
      );
      final notice = tester.getRect(find.text('입력한 생년월일은 연령 확인 목적으로만 보관돼요.'));
      final button = tester.getRect(find.widgetWithText(ElevatedButton, '확인'));
      expect(button.top - notice.bottom, greaterThanOrEqualTo(AppSpacing.xxl));
    });

    testWidgets('알림 권유 — 560dp 화면에서 터지지 않는다', (tester) async {
      await _pump(
        tester,
        const NotificationPrimingScreen(next: SizedBox()),
        size: const Size(360, 560),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('나중에'), findsOneWidget);
    });

    testWidgets('연령 확인 — 키보드가 없으면 버튼은 바닥에 그대로 붙는다', (tester) async {
      await _pump(tester, const AgeGateScreen());
      final button = tester.getRect(find.widgetWithText(ElevatedButton, '확인'));
      // 로그아웃 버튼(약 48) + 하단 패딩(24) 아래로는 내려가지 않는다.
      expect(button.bottom, greaterThan(640 - 24 - 48 - _navBar - 40));
    });

    testWidgets('약관 동의 — 560dp 화면에서도 터지지 않는다', (tester) async {
      await _pump(tester, const ConsentGateScreen(), size: const Size(360, 560));
      expect(tester.takeException(), isNull);
    });

    testWidgets('자막 편집 시트 — 560dp 화면 + 키보드 300 (예전엔 overflow)', (tester) async {
      late BuildContext ctx;
      await _pump(
        tester,
        Scaffold(body: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        })),
        size: const Size(360, 560),
        keyboard: 300,
      );
      showTextInputSheet(
        context: ctx,
        title: '자막 편집',
        description: '영상이 재생될 때 자막으로 표시돼요. 저장된 한 줄 평은 영향받지 않아요.',
        initial: '오늘은 커피를 참았다',
        maxLines: 3,
        confirmLabel: '저장',
        resetValue: '기본',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('BottomActionScrollView', () {
    testWidgets('본문이 짧으면 액션이 바닥에 붙는다', (tester) async {
      await _pump(
        tester,
        const Scaffold(
          // 실제 화면들과 같은 배선 (게이트 3화면 모두 SafeArea(top:false) 안에 둔다).
          body: SafeArea(
            top: false,
            child: BottomActionScrollView(
              body: [Text('짧은 본문')],
              actions: [SizedBox(height: 50, child: Placeholder())],
            ),
          ),
        ),
      );
      final action = tester.getRect(find.byType(Placeholder));
      // 하단 패딩(24) + 제스처 바만 남기고 바닥까지 내려가 있어야 한다.
      expect(action.bottom, closeTo(640 - 24 - _navBar, 1));
    });

    testWidgets('본문이 길면 액션까지 함께 스크롤된다 (터지지 않는다)', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: BottomActionScrollView(
            body: [
              for (var i = 0; i < 40; i++) const SizedBox(height: 40, child: Text('줄')),
            ],
            actions: const [SizedBox(height: 50, child: Placeholder())],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsOneWidget);
    });
  });
}
