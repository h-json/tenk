/// 결과 카드 화면이 **폭을 꽉 채우는지** 지키는 회귀 가드 (#29).
///
/// 규칙은 "풀블리드 = 카드를 화면 폭에 꽉 맞춘다" 인데, 카드가 480x864(높이 = 폭 × 1.8)
/// 고정이라 `BoxFit.contain` 을 쓰면 **가용 높이 < 화면 폭 × 1.8** 인 순간 높이 기준으로
/// 축소되고 그 차이가 양옆 흰 여백으로 나온다. 액션 Row(76dp) + 시스템 인셋이 그 임계선을
/// 21dp 차이로 넘나들어서 기기·글자 크기에 따라 "됐다 안 됐다" 했다 — 실기기에서 두 번
/// 재발한 자리라 문장이 아니라 테스트로 지킨다.
///
/// 지금 배선은 두 겹이다: ① 액션 Row 를 카드 위에 띄워 카드에 화면 높이를 통째로 주고
/// ② `BoxFit.fitWidth` 로 폭을 못박는다. **어느 한 겹만 빠져도 아래 케이스가 깨진다.**
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenk_app/app/scopes.dart';
import 'package:tenk_app/data/amount/amount.dart';
import 'package:tenk_app/data/badge/badge.dart';
import 'package:tenk_app/data/challenge/challenge.dart';
import 'package:tenk_app/data/user/user_api.dart';
import 'package:tenk_app/presentation/challenge/result_card/result_card_screen.dart';
import 'package:tenk_app/presentation/challenge/result_card/result_card_widget.dart';

/// 제스처 내비 바 높이(삼성 실기기 근사값) — keyboard_layout_test 와 같은 값.
const double _navBar = 24;
const double _statusBar = 24;

/// 화면은 진입 직후 `/api/users/me` 로 닉네임을 읽는다. 테스트에선 항상 실패시켜
/// 닉네임 없는 폴백 경로로 그린다 (레이아웃은 닉네임 유무와 무관하다).
class _OfflineAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline (test)',
    );
  }
}

UserApi _offlineUserApi() {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  dio.httpClientAdapter = _OfflineAdapter();
  return UserApi(authDio: dio);
}

Challenge _challenge({
  required int days,
  String name = '외식 줄이기',
  ChallengeResult result = ChallengeResult.success,
  List<AcquiredBadge> badges = const [],
}) {
  final start = DateTime(2026, 8, 1);
  return Challenge(
    id: 1,
    name: name,
    startDate: start,
    endDate: start.add(Duration(days: days - 1)),
    targetAmount: 10000,
    totalSpent: result == ChallengeResult.success ? 6800 : 12000,
    balance: result == ChallengeResult.success ? 3200 : -2000,
    result: result,
    started: true,
    finished: true,
    currentStreak: days,
    noSpendDays: 0,
    badges: badges,
  );
}

List<Amount> _amounts(Challenge c, {int spendDays = 2}) {
  return [
    for (var i = 0; i < spendDays; i++)
      Amount(
        id: i + 1,
        challengeId: c.id,
        category: 'FOOD',
        content: '점심',
        amount: 3400,
        noSpend: false,
        memo: null,
        spentDt: c.startDate.add(Duration(days: i, hours: 12)),
        mediaFiles: const [],
      ),
  ];
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required Size size,
  Challenge? challenge,
  double textScale = 1.0,
  // 기기 인셋은 보통 기본값이면 충분하지만, #31 은 **상태바가 두꺼운 기기**(펀치홀 40dp)
  // 에서만 드러났다 — 카드가 그만큼 아래로 밀려 하단이 액션 바에 먹힌다.
  double statusBar = _statusBar,
  double navBar = _navBar,
}) async {
  final c = challenge ?? _challenge(days: 7);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        viewPadding: EdgeInsets.only(top: statusBar, bottom: navBar),
        padding: EdgeInsets.only(top: statusBar, bottom: navBar),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        locale: const Locale('ko'),
        home: UserScope(
          api: _offlineUserApi(),
          child: ResultCardScreen(challenge: c, amounts: _amounts(c)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 화면 배치를 빼고 **카드 위젯 자체만** 그린다 (캡처 경로가 보는 모습).
///
/// 카드는 480x864 고정이라 기본 테스트 창(800x600)에 넣으면 세로로 넘친다 — 캡처는
/// 오프스크린이라 제약이 없으므로 뷰를 카드 크기로 맞춰 같은 조건을 만든다.
Future<void> _pumpRawCard(
  WidgetTester tester,
  Challenge c, {
  bool? showWatermark,
}) async {
  tester.view.physicalSize =
      const Size(ResultCardWidget.width, ResultCardWidget.height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ko'),
      home: Material(
        child: ResultCardWidget(
          challenge: c,
          amounts: _amounts(c),
          nickname: '테스터',
          // 기본값 자체가 캡처 동작이라, 안 넘기는 경로도 그대로 재현한다.
          showWatermark: showWatermark ?? true,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 화면에 그려진 카드의 실제 사각형 (FittedBox 스케일이 반영된 글로벌 좌표).
Rect _cardRect(WidgetTester tester) =>
    tester.getRect(find.byType(ResultCardWidget));

void main() {
  group('카드가 화면 폭을 꽉 채운다 (#29)', () {
    // 실기기(384x832) 근사. 고치기 전에도 통과하던 케이스지만, 여유가 21dp 뿐이라
    // 액션 Row 가 조금만 커지면 뒤집혔다 — 임계선 자체를 없앴는지 확인하는 기준점.
    testWidgets('384x832 — 여백 0', (tester) async {
      await _pumpCard(tester, size: const Size(384, 832));
      expect(_cardRect(tester).left, 0);
      expect(_cardRect(tester).width, 384);
    });

    // ⭐ 고치기 전 실패하던 케이스. 가용 높이(640 − 상태바 − 액션 76 − 제스처 24 = 516)가
    // 임계 648(=360×1.8)에 한참 못 미쳐 카드가 287dp 로 줄고 좌우에 36dp 씩 남았다.
    testWidgets('360x640 (16:9) — 여백 0', (tester) async {
      await _pumpCard(tester, size: const Size(360, 640));
      expect(_cardRect(tester).left, 0);
      expect(_cardRect(tester).width, 360);
    });

    testWidgets('320x568 (최소 폭) — 여백 0', (tester) async {
      await _pumpCard(tester, size: const Size(320, 568));
      expect(_cardRect(tester).left, 0);
      expect(_cardRect(tester).width, 320);
    });

    // 글자 크기 확대는 액션 버튼 라벨을 키워 액션 Row 를 높인다 — 예전 구조에선 이것만으로도
    // 임계선을 넘겨 여백이 생겼다. 지금은 액션이 카드 높이를 먹지 않으므로 무관해야 한다.
    testWidgets('글자 크기 1.5배 — 여백 0', (tester) async {
      await _pumpCard(tester, size: const Size(384, 832), textScale: 1.5);
      expect(_cardRect(tester).left, 0);
      expect(_cardRect(tester).width, 384);
    });

    testWidgets('실패 카드도 동일', (tester) async {
      await _pumpCard(
        tester,
        size: const Size(360, 640),
        challenge: _challenge(days: 7, result: ChallengeResult.fail),
      );
      expect(_cardRect(tester).width, 360);
    });
  });

  group('세로 배치', () {
    // 위쪽이 잘리면 닉네임·챌린지 이름이 사라진다. 모자란 세로는 **아래로만** 흘려보낼 것.
    testWidgets('카드 상단은 상태바 띠 바로 아래에서 시작한다', (tester) async {
      await _pumpCard(tester, size: const Size(360, 640));
      expect(_cardRect(tester).top, _statusBar);
    });

    // 액션 버튼은 카드 위에 떠 있지만 여전히 제스처 바 위여야 한다 (SafeArea 유지 가드).
    testWidgets('액션 버튼이 제스처 바에 잘리지 않는다', (tester) async {
      await _pumpCard(tester, size: const Size(360, 640));
      final save = tester.getRect(find.widgetWithText(FilledButton, '갤러리 저장'));
      final share = tester.getRect(find.widgetWithText(FilledButton, '공유하기'));
      expect(save.bottom, lessThanOrEqualTo(640 - _navBar));
      expect(share.bottom, lessThanOrEqualTo(640 - _navBar));
    });

    // 세로가 넉넉하면 카드가 액션 바 위에서 끝난다.
    testWidgets('384x832 에선 카드가 액션 바를 침범하지 않는다', (tester) async {
      await _pumpCard(tester, size: const Size(384, 832));
      final save = tester.getRect(find.widgetWithText(FilledButton, '갤러리 저장'));
      expect(_cardRect(tester).bottom, lessThanOrEqualTo(save.top));
    });
  });

  // ── 워터마크는 캡처 전용이다 (#31) ──────────────────────────────────────────
  //
  // 화면은 풀블리드라 세로가 모자라면 카드 아래를 잘라내는데(위 #29), 카드 하단 16dp 안에
  // 있던 워터마크가 액션 바의 **불투명 흰 바닥**에 먹혔다. 여유가 평범한 3버튼 내비
  // 기기에서도 8.8dp뿐이라 상태바가 두꺼운 기기(펀치홀 40dp)에서 실제로 잘렸다
  // (`1.2.1+6` 실기기). 간격 조정이 아니라 **역할대로 가르는 것**이 수정이다.
  group('워터마크는 캡처에만 남는다 (#31)', () {
    // 잘리던 그 자리가 지금은 비어 있어야 한다. 화면에 워터마크를 되돌리면 여기서 걸린다.
    testWidgets('화면에는 워터마크가 없다', (tester) async {
      await _pumpCard(tester, size: const Size(384, 832));
      expect(find.text('TenK'), findsNothing);
    });

    // 기기 인셋이 커져도(펀치홀 40 + 3버튼 48) 마찬가지 — 원래 잘리던 조합이다.
    testWidgets('인셋이 큰 기기에서도 없다', (tester) async {
      await _pumpCard(
        tester,
        size: const Size(384, 832),
        statusBar: 40,
        navBar: 48,
      );
      expect(find.text('TenK'), findsNothing);
    });

    // ⭐ 캡처 경로를 지키는 가드. [ResultCardCapture] 는 `showWatermark` 를 넘기지 않으므로
    // **기본값이 곧 캡처 동작**이다 — 기본값을 false 로 뒤집으면 갤러리 저장·공유 PNG 와
    // 영상 마지막 클립에서 출처 표기가 통째로 사라지는데, 그건 화면만 봐서는 안 보인다.
    testWidgets('캡처용 기본값은 워터마크를 그린다', (tester) async {
      final c = _challenge(days: 7);
      await _pumpRawCard(tester, c);
      expect(find.text('TenK'), findsOneWidget);
    });

    // 워터마크는 `Spacer` **뒤**에 있어서 빼도 위쪽이 안 밀린다 — 화면과 저장본이
    // 워터마크 유무만 다르다는 보장. 이게 깨지면 저장 PNG 와 화면이 갈라진다.
    testWidgets('워터마크 유무가 위쪽 콘텐츠를 밀지 않는다', (tester) async {
      final c = _challenge(days: 7);
      Future<Rect> gridRect({required bool watermark}) async {
        await _pumpRawCard(tester, c, showWatermark: watermark);
        return tester.getRect(find.text('7일간의 기록'));
      }

      expect(await gridRect(watermark: true), await gridRect(watermark: false));
    });
  });

  // 카드 내부(480x864)의 최악 케이스 — 이름 2줄 + 30일 그리드 + 배지 3종.
  // 화면 배치를 바꾸다 카드 자체를 넘치게 만드는 걸 막는다.
  testWidgets('최악 케이스(30일 + 2줄 이름 + 배지)에서도 터지지 않는다', (tester) async {
    await _pumpCard(
      tester,
      size: const Size(360, 640),
      challenge: _challenge(
        days: 30,
        name: '아주 긴 이름의 한 달짜리 절약 챌린지 기록입니다',
        badges: [
          AcquiredBadge(
            challengeBadgeId: 1,
            badgeId: 4,
            type: BadgeType.streak,
            conditionValue: 30,
            iconPath: '/badges/streak_30.png',
            acquiredDt: DateTime(2026, 8, 30),
          ),
          AcquiredBadge(
            challengeBadgeId: 2,
            badgeId: 9,
            type: BadgeType.challengeSuccess,
            conditionValue: 1,
            iconPath: '/badges/challenge_success.png',
            acquiredDt: DateTime(2026, 8, 30),
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(_cardRect(tester).width, 360);
  });
}
