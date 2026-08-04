/// 결과 카드 **진입 컨페티가 끝난 뒤 흔적을 남기지 않는지** 지키는 가드.
///
/// 오버레이는 카드 위에 얹히므로 조각이 하나라도 멈춰 서면 그 자리의 콘텐츠(일자 그리드·범례)를
/// 영구히 가린다. 2026-08-03 실기기에서 실제로 그랬다 — `delay + fallSpan > 1` 인 조각이
/// 낙하 도중에 얼어붙었고(48개 중 15개), `AnimationController` 가 완료 후 그대로 서 있어
/// 마지막 프레임이 계속 유지됐다. 갤러리 저장 PNG 는 카드 내부 정적 컨페티만 담기므로 멀쩡해
/// **화면에서만 보이는 결함**이었다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenk_app/design/tokens.dart';
import 'package:tenk_app/presentation/challenge/result_card/result_card_painters.dart';

/// 오버레이가 실제로 뭔가 그리고 있는지 (자기 하위의 `CustomPaint` 존재 여부).
Finder _overlayPainter() => find.descendant(
      of: find.byType(ResultCardConfettiOverlay),
      matching: find.byType(CustomPaint),
    );

Future<void> _pumpOverlay(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: ResultCardConfettiOverlay(colors: AppColors.rewardConfetti),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('연출 중에는 컨페티가 그려진다', (tester) async {
    await _pumpOverlay(tester);
    // 연출 길이(2.4초)의 중간 지점.
    await tester.pump(const Duration(milliseconds: 1200));
    expect(
      _overlayPainter(),
      findsOneWidget,
      reason: '연출이 도는 동안에는 컨페티가 보여야 한다 — 잔존을 막으려다 효과 자체를 죽이면 안 된다',
    );
  });

  testWidgets('연출이 끝나면 오버레이가 아무것도 그리지 않는다', (tester) async {
    await _pumpOverlay(tester);
    await tester.pumpAndSettle();
    expect(
      _overlayPainter(),
      findsNothing,
      reason: '조각이 남으면 그 자리의 일자 그리드·범례를 영구히 가린다',
    );
  });

  testWidgets('멈춘 뒤에도 탭을 가로채지 않는다', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tapped = true,
                ),
              ),
              const Positioned.fill(
                child:
                    ResultCardConfettiOverlay(colors: AppColors.rewardConfetti),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GestureDetector).first);
    expect(tapped, isTrue, reason: '오버레이가 남아 카드 아래 버튼·닫기를 먹으면 안 된다');
  });
}
