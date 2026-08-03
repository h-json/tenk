/// 휠 시각 선택 다이얼로그가 **좁은 화면·키보드 상태에서 뭉개지지 않는지** 지키는 가드.
///
/// `AlertDialog` 는 공간이 모자라면 content 를 눌러버린다. 눌린 높이가 항목 높이의 배수가
/// 아니면 위아래 항목이 반쪽씩 걸쳐 숫자가 겹쳐 보인다 — 2026-08-03 실기기에서 실제로
/// `오전`·시·`:`·분이 한 줄에 뭉갰다(경고 줄무늬가 안 떠서 조용히 깨진다).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenk_app/app/scopes.dart';
import 'package:tenk_app/data/settings/app_settings.dart';
import 'package:tenk_app/presentation/common/date_time_picker.dart';

/// 휠 한 칸 높이 (wheel_time_picker.dart 의 `_itemExtent` 와 같은 값).
const double _itemExtent = 44;

Future<void> _openPicker(
  WidgetTester tester, {
  required Size size,
  double keyboard = 0,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await AppSettings.load();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  late BuildContext ctx;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
        padding: EdgeInsets.only(top: 24, bottom: keyboard > 0 ? 0 : 24),
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: SettingsScope(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('ko'),
          home: Scaffold(
            body: Builder(builder: (c) {
              ctx = c;
              return const SizedBox();
            }),
          ),
        ),
      ),
    ),
  );
  pickTenkTime(ctx, initial: const TimeOfDay(hour: 21, minute: 0));
  await tester.pumpAndSettle();
}

/// 휠 영역 높이 — 항목 높이의 배수여야 온전한 행만 보인다.
double _wheelBoxHeight(WidgetTester tester) {
  // AlertDialog content 의 SizedBox 는 폭 260 으로 고정돼 있어 그걸로 특정한다.
  final box = find.byWidgetPredicate(
    (w) => w is SizedBox && w.width == 260 && w.height != null,
  );
  return tester.widget<SizedBox>(box.first).height!;
}

void main() {
  // ⚠️ 아래 세 건 모두 **렌더 예외까지** 확인한다. 한때 가용 높이를 재려고 `LayoutBuilder`
  // 를 넣었다가 `AlertDialog` 의 intrinsic 측정과 충돌해 다이얼로그가 통째로 렌더에
  // 실패했는데, 예외를 안 보던 시절의 테스트는 그걸 통과시켰다.
  testWidgets('넉넉한 화면 — 휠 5칸이 그대로 보인다', (tester) async {
    await _openPicker(tester, size: const Size(360, 900));
    expect(_wheelBoxHeight(tester), _itemExtent * 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('좁은 화면 — 키보드 없이도 휠 5칸이 들어간다', (tester) async {
    await _openPicker(tester, size: const Size(360, 560));
    expect(_wheelBoxHeight(tester), _itemExtent * 5);
    expect(tester.takeException(), isNull);
  });

  // 평소엔 `Dialog` 기본 동작대로 키보드 **위로 올라가야** 한다. 안 줄이고 덮는 건
  // 공간이 정말 모자랄 때만 쓰는 예외다 — 그 둘이 실제로 갈리는지 본다.
  testWidgets('공간이 되면 다이얼로그가 키보드 위로 올라간다', (tester) async {
    const keyboard = 300.0;
    await _openPicker(tester, size: const Size(360, 900), keyboard: keyboard);
    await tester.tap(find.text('9'), warnIfMissed: false);
    await tester.pumpAndSettle();
    // `AlertDialog` 자체는 화면 전체를 차지하는 레이아웃이라 rect 로 못 잰다 —
    // 실제로 보이는 표면인 휠 영역으로 판단한다.
    final wheel = tester.getRect(
      find.byWidgetPredicate((w) => w is SizedBox && w.width == 260).first,
    );
    expect(wheel.bottom, lessThanOrEqualTo(900 - keyboard),
        reason: '여유가 있으면 키보드가 다이얼로그를 덮으면 안 된다');
    expect(_wheelBoxHeight(tester), _itemExtent * 5);
  });

  // 접지 않는 게 결정이다 — 키보드가 아래를 덮는 건 괜찮지만 **휠이 줄어들면 안 된다**.
  testWidgets('공간이 모자라면 안 줄이고 키보드가 덮게 둔다', (tester) async {
    await _openPicker(tester, size: const Size(360, 560), keyboard: 300);
    // 가운데 시(21시 → 9) 숫자를 탭하면 그 열이 직접 입력으로 바뀐다.
    // 실제 탭을 받는 건 숫자 위에 얹힌 **투명 탭 영역**이라 warnIfMissed 를 끈다
    // (위/아래는 휠 스크롤이 먹어야 해서 가운데 한 칸만 탭 대상으로 덮어둔 구조).
    await tester.tap(find.text('9'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(_wheelBoxHeight(tester), _itemExtent * 5);
    expect(tester.takeException(), isNull);
  });

  // 입력칸만은 반드시 보여야 한다 — 타이핑하는 자리라서.
  //
  // 아주 작은 화면(560dp)에서는 취소·확인까지 키보드 위에 올리는 게 물리적으로 불가능하다
  // (휠 220 + 제목 + 버튼 ≈ 353dp 인데 키보드 위에 남는 건 260dp). 그 경우의 탈출구는
  // **키보드의 완료 키**다 — `onSubmitted` 가 편집을 확정하면 다이얼로그가 제자리로
  // 돌아오며 버튼이 다시 보인다. 그래서 여기선 입력칸 가시성만 보장한다.
  testWidgets('직접 입력 중 입력칸은 키보드 위에 있다', (tester) async {
    const keyboard = 300.0;
    await _openPicker(tester, size: const Size(360, 560), keyboard: keyboard);
    await tester.tap(find.text('9'), warnIfMissed: false);
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byType(TextField));
    expect(field.bottom, lessThanOrEqualTo(560 - keyboard));
  });
}
