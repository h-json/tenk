import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/amount/amount.dart';
import '../../../data/badge/badge.dart';
import '../../../data/challenge/challenge.dart';
import '../../../design/tenk_logo.dart';
import '../_formatters.dart';
import 'result_card_painters.dart';

/// 챌린지 결과 카드 위젯. 항상 480x864 (9:16) 고정 크기로 그려져 PNG 캡처/영상 합성에 그대로 들어간다.
///
/// 화면에 띄울 때는 [FittedBox] 로 감싸 디바이스 폭에 맞춰 스케일링한다 — 위젯 자체의 픽셀 좌표는
/// 영상 export 해상도(480x864) 와 1:1 매칭이라 흔들리면 안 된다.
///
/// **구조는 2블록이다** (카카오뱅크 26주적금 레퍼런스): 상단 컬러 블록에 헤더+히어로 금액+예산,
/// 하단 화이트에 일자 그리드+배지. 흰 배경 하나에 요소를 8개 나열하던 이전 안은 위계가 없어
/// 폼처럼 읽혔다 — 근거는 [docs/decisions.md] "결과 카드 디자인".
///
/// **이모지를 쓰지 않는다.** 시스템 이모지는 OS 마다 다른 글리프로 그려져 같은 챌린지의 카드가
/// 기기별로 달라진다 — 장식은 [ResultBlockConfettiPainter] 로 직접 그린다.
class ResultCardWidget extends StatelessWidget {
  const ResultCardWidget({
    super.key,
    required this.challenge,
    required this.amounts,
    required this.nickname,
  });

  static const double width = 480;
  static const double height = 864;

  final Challenge challenge;
  final List<Amount> amounts;

  /// null 이면 헤더에서 닉네임 부분 생략 — "만원 챌린지" 만 표시.
  final String? nickname;

  bool get _isSuccess => challenge.result == ChallengeResult.success;

  // 절약액(목표 − 사용)은 **의도적으로 쓰지 않는다** — 성취는 "덜 쓴 정도" 가 아니라
  // "기간 안에서 목표를 지킨 것" 이다 (히어로 문장 참고).

  int get _durationDays =>
      dateOnly(challenge.endDate).difference(dateOnly(challenge.startDate)).inDays + 1;

  // ── 색은 캡처가 ThemeData 변동에 영향받지 않도록 hardcode (design/tokens.dart 의
  // AppColors.reward* 와 정합시켜 둔다 — 한쪽만 바꾸면 리워드 색 언어가 갈라진다).
  static const _white = Color(0xFFFFFFFF);
  static const _inkSub = Color(0xFF5E6572);

  /// 배지 슬롯의 테두리 — 획득/미획득 **양쪽 다** 흰 원 + 이 테두리다.
  static const _slotBorder = Color(0xFFDFE5EC);
  static const _inkMuted = Color(0xFF9AA0AD);

  /// 상단 블록 — 성공은 **브랜드 민트**, 실패는 **앱 `danger` 와 같은 레드**를 꽉 채운다.
  ///
  /// 옅은 틴트(명도 94%)를 쓰던 안은 **썸네일·피드에서 그냥 흰 카드로 읽혔다** — 배경색을
  /// 커밋하는 게 Spotify Wrapped·Strava·카뱅이 공통으로 하는 일이고, 스크롤 중에 눈에
  /// 걸리는 유일한 장치다.
  ///
  /// 실패 레드를 더 어둡게(#D94F4F) 눌렀던 안은 카드가 경고창처럼 무거워져 폐기했다.
  /// 앱 `danger` 와 같은 값이라 실패를 말하는 색이 앱 안에서 하나로 유지된다.
  Color get _block => _isSuccess ? const Color(0xFF1FBE9C) : const Color(0xFFFF6B6B);

  /// 블록 위 텍스트는 흰색이 기본. 보조 정보는 알파로 낮춘다.
  static const _onBlock = Color(0xFFFFFFFF);

  /// 민트/그레이 블록 위에서 **보이는** 컨페티 색. 민트 계열은 배경에 묻히므로 쓰지 않는다.
  static const _confetti = <Color>[
    Color(0xFFFFFFFF), // 화이트
    Color(0xFFFFC94D), // 골드
    Color(0xFFBFEFE2), // 아주 연한 민트
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: _white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBlock(
              block: _block,
              onBlock: _onBlock,
              confetti: _isSuccess ? _confetti : const [],
              nickname: nickname,
              name: challenge.name,
              // 일수는 히어로 문장("N일 동안")이 맡으므로 여기선 날짜 범위만.
              period: formatShortPeriod(challenge.startDate, challenge.endDate),
              durationDays: _durationDays,
              isSuccess: _isSuccess,
              spent: challenge.totalSpent,
              target: challenge.targetAmount,
            ),
            // **배지 → 기록** 순서다. 블록 바로 아래에 성취(배지)가 붙고 그 근거(기록)가
            // 따라오면 카드 위쪽이 "결과" 로 뭉친다. 반대 순서로 되돌리지 말 것.
            //
            // 콘텐츠는 블록 **바로 아래에 붙이고** 남는 공백은 워터마크 위 한 곳으로 몬다.
            // 위아래로 나눠 중앙에 띄우면 (기간이 짧아 그리드가 1줄일 때) 카드 하단 절반이
            // 통째로 비어 보인다.
            //
            // ⚠️ 여기 간격은 **최악 케이스(이름 2줄 + 30일 그리드 + 배지)에서 864 를 넘지
            // 않도록 맞춰진 값**이다. 이름이 2줄이면 블록이 32px 자라 하단이 그만큼 밀린다.
            // 늘리려면 30일 카드로 오버플로우부터 확인할 것.
            const SizedBox(height: 18),
            if (challenge.badges.isNotEmpty) ...[
              _BadgeRow(badges: challenge.badges),
              const SizedBox(height: 16),
            ],
            _DayGrid(
              states: _dayStates(),
              durationDays: _durationDays,
              // 실패 카드에선 **지출한 날을 빨강**으로 — 색면뿐 아니라 데이터에서도 어디가
              // 문제였는지 보이게 한다. 무지출(잘한 날)은 결과와 무관하게 늘 민트다.
              spendColor: _isSuccess ? const Color(0xFFA5E3D3) : const Color(0xFFFF6B6B),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 마크는 `CustomPainter` 라 캡처 전에 precache 할 게 없다 (배지 PNG 와
                  // 다른 점). 색은 글자와 같은 뮤트 톤이되 **트랙은 반드시 남긴다** —
                  // 빼면 갭이 열려 `0` 이 `C` 로 읽힌다(런처 아이콘에서 트랙을 완전한
                  // 원으로 둔 것과 같은 이유).
                  TenkLogoMark(
                    size: 17,
                    color: _inkMuted,
                    trackColor: _slotBorder,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'TenK',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _inkMuted,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 챌린지 기간의 하루하루를 상태로 만든다. 무지출은 지출 등록 시 자동 삭제되므로 한 날에
  /// 둘이 공존하지 않지만, 방어적으로 지출을 우선한다.
  List<_DayState> _dayStates() {
    final spendDays = <DateTime>{};
    final noSpendDays = <DateTime>{};
    for (final a in amounts) {
      final day = dateOnly(a.spentDt);
      if (a.noSpend) {
        noSpendDays.add(day);
      } else {
        spendDays.add(day);
      }
    }

    final start = dateOnly(challenge.startDate);
    return List.generate(_durationDays, (i) {
      final day = start.add(Duration(days: i));
      if (spendDays.contains(day)) return _DayState.spend;
      if (noSpendDays.contains(day)) return _DayState.noSpend;
      return _DayState.none;
    });
  }
}

enum _DayState { noSpend, spend, none }

class _TopBlock extends StatelessWidget {
  const _TopBlock({
    required this.block,
    required this.onBlock,
    required this.confetti,
    required this.nickname,
    required this.name,
    required this.period,
    required this.durationDays,
    required this.isSuccess,
    required this.spent,
    required this.target,
  });

  final Color block;
  final Color onBlock;
  final List<Color> confetti;
  final String? nickname;
  final String name;
  final String period;
  final int durationDays;
  final bool isSuccess;
  final int spent;
  final int target;

  @override
  Widget build(BuildContext context) {
    // ⚠️ "만원 챌린지" 라고 쓰지 말 것 — 목표 금액은 챌린지마다 다르다(30만원짜리도 있다).
    // '만원 챌린지' 는 서비스 컨셉 이름이지 이 카드가 말할 사실이 아니다.
    final title = nickname == null || nickname!.isEmpty
        ? '챌린지 기록'
        : '$nickname님의 챌린지';

    return ColoredBox(
      // **경계는 선명하게 끊는다 — 페이드로 흐리지 말 것.** 한때 하단 12%를 투명으로
      // 페이드시켰는데("두 장을 붙인 것처럼 보인다" 는 우려), 실물에선 색이 바래며
      // 끝나 블록이 **덜 칠해진 것처럼** 보였다. 컬러 블록이 하는 일이 대비를 만드는
      // 것이라 그 끝은 또렷해야 한다.
      color: block,
      child: Stack(
        children: [
          // 컨페티는 블록 크기에 맞춰 비율 좌표로 그려진다 (이름 1줄/2줄 모두 대응).
          Positioned.fill(
            child: CustomPaint(painter: ResultBlockConfettiPainter(colors: confetti)),
          ),
          Padding(
            // 상단 여백은 화면에서 이 자리에 얹히는 닫기(X) 버튼의 자리다.
            // 하단 여백은 예산 바가 경계에 붙지 않게 하는 여유 — 세로가 모자라면 여기가 아니라
            // 하단 화이트 쪽 간격에서 뺄 것(블록이 카드의 절반 이상을 차지해야 한다).
            padding: const EdgeInsets.fromLTRB(36, 52, 36, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: onBlock.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: onBlock,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 10),
                // 일정은 **부가 정보가 아니라 성취의 조건**이라 작게 두지 않는다.
                Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: onBlock.withValues(alpha: 0.86),
                  ),
                ),
                // 블록이 카드의 절반 이상을 차지하게 여백을 넉넉히 준다 — 기간이 짧아
                // 그리드가 작을 때 하단 화이트가 통째로 비어 보이는 걸 막는 장치이기도 하다.
                const SizedBox(height: 30),
                _Hero(
                  durationDays: durationDays,
                  target: target,
                  isSuccess: isSuccess,
                  onBlock: onBlock,
                ),
                const SizedBox(height: 24),
                _BudgetBar(
                  spent: spent,
                  target: target,
                  onBlock: onBlock,
                  block: block,
                  isSuccess: isSuccess,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 카드의 주인공 — 절약액(성공) 또는 초과액(실패). 타이포 대비를 극단으로 벌리는 자리라
/// 크기를 줄이지 말 것(레퍼런스 3종 모두 히어로 숫자가 압도적이다).
class _Hero extends StatelessWidget {
  const _Hero({
    required this.durationDays,
    required this.target,
    required this.isSuccess,
    required this.onBlock,
  });

  final int durationDays;
  final int target;
  final bool isSuccess;
  final Color onBlock;

  @override
  Widget build(BuildContext context) {
    // 히어로는 **"기간 동안 / 목표 금액 / 지켰어요"** 한 문장이다.
    //
    // 절약액(목표 − 사용)을 주인공으로 두던 안은 틀렸다 — 10,000원 목표에서 3,000원만 썼다고
    // "7,000원 아꼈다" 가 성취인 게 아니라, **주어진 기간 안에서 목표를 지킨 것**이 성취다.
    // 덜 쓴 정도는 자랑거리가 아니라 부산물이라 강조하지 않는다.
    return Column(
      children: [
        Text(
          '$durationDays일 동안',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: onBlock.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatNumber(target),
                style: TextStyle(
                  fontSize: 66,
                  fontWeight: FontWeight.w800,
                  color: onBlock,
                  height: 1.0,
                  letterSpacing: -2,
                ),
              ),
              Text(
                '원',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: onBlock.withValues(alpha: 0.90),
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isSuccess ? '챌린지 성공' : '챌린지 실패',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: onBlock,
          ),
        ),
      ],
    );
  }
}

/// 예산 진행 바. 도넛 링을 걷어낸 이유가 "비율만 말하고 척도(최대값·현재값)를 못 나른다"
/// 였으므로, 실제 금액을 글자로 적는 줄이 바와 한 세트다.
///
/// **성공**은 트랙(흰색 28%) 위에 쓴 만큼을 불투명 흰색으로 채운다.
///
/// **실패**는 막대 전체가 실사용액이고 목표 지점에 흰 눈금을 세운다. 여기서 초과 구간을
/// 딥레드로 눌렀던 안은 빨강 위 어두운 빨강이라 **빈 칸으로 읽혔다** — 그래서 밝기를
/// 뒤집어 **넘긴 만큼만 불투명 흰색**, 목표까지는 흐린 흰색으로 둔다. 빨강 위에서 제일
/// 밝은 게 초과분이 되도록 하는 게 요점이라 다시 뒤집지 말 것.
///
/// ⚠️ **막대 아래에 라벨 줄을 두지 말 것.** 초과액은 바로 위 흰 칩이, 목표액은 히어로가
/// 이미 말한다. 줄을 하나라도 붙이면 그만큼 **빨강 면이 성공(민트)보다 아래로 내려와**
/// 두 카드의 블록 높이가 어긋난다. 눈금은 레이아웃을 차지하지 않게 바 위로 넘쳐 그린다.
class _BudgetBar extends StatelessWidget {
  const _BudgetBar({
    required this.spent,
    required this.target,
    required this.onBlock,
    required this.block,
    required this.isSuccess,
  });

  final int spent;
  final int target;
  final Color onBlock;
  final Color block;
  final bool isSuccess;

  static const _barHeight = 9.0;
  static const _tickWidth = 3.0;
  static const _tickHeight = 19.0;
  static const _tickRing = 2.0;

  @override
  Widget build(BuildContext context) {
    // 초과는 결과가 아니라 숫자로 판정한다 — 목표와 정확히 같으면(성공) 칩이 안 나온다.
    final over = spent - target;
    final showOver = !isSuccess && over > 0 && spent > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 목표액은 히어로가 이미 말했으므로 여기선 **실제로 쓴 금액만** 적는다.
        // 양쪽에 다 적으면 같은 숫자가 카드에 두 번 나온다.
        //
        // 높이를 고정하는 건 의도다 — 초과 칩(패딩 있음)이 들어가는 실패 카드와 글자만
        // 있는 성공 카드의 이 줄이 같은 높이여야 블록 높이가 어긋나지 않는다.
        SizedBox(
          height: 26,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${formatWon(spent)} 썼어요',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: onBlock,
                  ),
                ),
                if (showOver) ...[
                  const SizedBox(width: 10),
                  // 빨강 위에서 가장 튀는 조합 — 흰 칩 + 블록색 글씨.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: onBlock,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${formatNumber(over)}원 초과',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: block,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(height: _barHeight, child: _bar(showOver)),
      ],
    );
  }

  Widget _bar(bool showOver) {
    if (!showOver) {
      final ratio = target <= 0 ? 0.0 : (spent / target).clamp(0.0, 1.0);
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            ColoredBox(
              color: onBlock.withValues(alpha: 0.28),
              child: const SizedBox.expand(),
            ),
            FractionallySizedBox(
              widthFactor: ratio == 0 ? 0.0001 : ratio,
              child: ColoredBox(color: onBlock, child: const SizedBox.expand()),
            ),
          ],
        ),
      );
    }

    // 막대 전체 = 실사용액. 목표까지가 흐린 흰색, 넘긴 만큼이 불투명 흰색.
    final withinFactor = (target / spent).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tickX = constraints.maxWidth * withinFactor;
        return Stack(
          // 눈금은 바 위아래로 넘쳐 그려진다 — 레이아웃 높이를 늘리지 않기 위한 것.
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Row(
                children: [
                  Expanded(
                    flex: (withinFactor * 1000).round(),
                    child: ColoredBox(
                      color: onBlock.withValues(alpha: 0.42),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Expanded(
                    flex: 1000 - (withinFactor * 1000).round(),
                    child: ColoredBox(color: onBlock, child: const SizedBox.expand()),
                  ),
                ],
              ),
            ),
            Positioned(
              left: tickX - _tickWidth / 2 - _tickRing,
              top: -(_tickHeight - _barHeight) / 2 - _tickRing,
              child: Container(
                width: _tickWidth + _tickRing * 2,
                height: _tickHeight + _tickRing * 2,
                alignment: Alignment.center,
                // 블록색 링을 둘러 흐린 흰색 구간 위에서도 눈금이 끊겨 보인다.
                decoration: BoxDecoration(
                  color: block,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Container(
                  width: _tickWidth,
                  height: _tickHeight,
                  decoration: BoxDecoration(
                    color: onBlock,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 챌린지 기간을 하루 = 한 칸으로 그리는 그리드 (카카오뱅크 26주적금 방식).
///
/// **바나 링 대신 이걸 쓰는 이유**: 칸 수가 곧 기간이라 척도가 눈에 보이고, "다 채웠다" 가
/// 그림으로 읽혀 자랑거리가 된다. 카테고리 분포는 자랑거리가 아니라 정산서라 뺐다.
///
/// **무지출은 성공/실패와 무관하게 늘 민트**다 — 기록한 날은 결과와 상관없이 잘한 것이고,
/// 실패 카드까지 온통 빨강이면 카드가 우울해진다. 반대로 **지출한 날은 실패 카드에서만
/// 빨강**([spendColor])이라, 색면뿐 아니라 데이터에서도 어디가 문제였는지 보인다.
class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.states,
    required this.durationDays,
    required this.spendColor,
  });

  final List<_DayState> states;
  final int durationDays;
  final Color spendColor;

  static const _gap = 6.0;
  static const _maxCell = 44.0;
  static const _available = 408.0; // 480 - 좌우 패딩 36

  static const _noSpend = Color(0xFF1FBE9C);
  static const _none = Color(0xFFE4E8EE);

  @override
  Widget build(BuildContext context) {
    final cols = _columnsFor(states.length);
    if (cols == 0) return const SizedBox.shrink();
    final cell = math.min(_maxCell, (_available - _gap * (cols - 1)) / cols);

    final rows = <Widget>[];
    for (var i = 0; i < states.length; i += cols) {
      final chunk = states.sublist(i, math.min(i + cols, states.length));
      rows.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var j = 0; j < chunk.length; j++) ...[
              if (j > 0) const SizedBox(width: _gap),
              Container(
                width: cell,
                height: cell,
                decoration: BoxDecoration(
                  color: switch (chunk[j]) {
                    _DayState.noSpend => _noSpend,
                    _DayState.spend => spendColor,
                    _DayState.none => _none,
                  },
                  borderRadius: BorderRadius.circular(cell * 0.28),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$durationDays일간의 기록',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: ResultCardWidget._inkSub,
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: _gap),
          rows[i],
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _legend(),
        ),
      ],
    );
  }

  /// 열 수. 짧은 챌린지를 한 줄로 늘어놓으면 칸이 폭에 눌려 작아지고 **카드 하단이 텅 빈다** —
  /// 5~20일은 2줄로 접어 칸을 키운다. 21일 이상은 10열(3줄)로 둬야 세로가 넘치지 않는다.
  int _columnsFor(int days) {
    if (days <= 4) return days;
    if (days <= 20) return (days / 2).ceil();
    return 10;
  }

  /// 실제로 나온 상태만 범례에 남긴다 — 전부 기록한 챌린지에 '기록 없음' 은 잡음이다.
  /// 색만 알려주는 대신 **일수까지 적어** 범례가 곧 요약이 되게 한다.
  List<Widget> _legend() {
    final all = [
      (_DayState.noSpend, _noSpend, '무지출'),
      (_DayState.spend, spendColor, '지출'),
      (_DayState.none, _none, '기록 없음'),
    ];
    final items = <Widget>[];
    for (final (state, color, label) in all) {
      final count = states.where((s) => s == state).length;
      if (count == 0) continue;
      if (items.isNotEmpty) items.add(const SizedBox(width: 14));
      items.add(_LegendDot(color: color, label: '$label $count일'));
    }
    return items;
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ResultCardWidget._inkMuted,
          ),
        ),
      ],
    );
  }
}

/// 배지 3칸 — **[연속 기록] [챌린지 성공] [무지출 누적]** 고정 배치.
///
/// 규칙(2026-08-01):
/// - **타입별로 최상위 등급 하나만** 보여준다. 3·7·14 를 다 늘어놓으면 같은 성취가 세 번
///   나오는 셈이고, 14 를 땄다는 건 3·7 을 이미 지났다는 뜻이라 정보가 중복이다.
/// - **챌린지 성공이 가운데**, 좌우가 연속/무지출. 자리가 고정이라 카드끼리 비교가 된다.
/// - **못 딴 자리는 비워 둔다** — 3칸 대칭이 유지되고, 빈 칸 자체가 "여긴 다음에" 로 읽힌다.
/// - 3개뿐이라 **크게** 그릴 수 있다(가운데 78 / 좌우 64).
class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.badges});

  final List<AcquiredBadge> badges;

  static const _sideSize = 62.0;
  static const _centerSize = 76.0;

  /// 해당 타입에서 `conditionValue` 가 가장 큰 배지. 없으면 null.
  AcquiredBadge? _top(BadgeType type) {
    AcquiredBadge? best;
    for (final b in badges) {
      if (b.type != type) continue;
      if (best == null || b.conditionValue > best.conditionValue) best = b;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final streak = _top(BadgeType.streak);
    final success = _top(BadgeType.challengeSuccess);
    final noSpend = _top(BadgeType.noSpend);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _BadgeSlot(badge: streak, size: _sideSize),
        const SizedBox(width: 20),
        _BadgeSlot(badge: success, size: _centerSize),
        const SizedBox(width: 20),
        _BadgeSlot(badge: noSpend, size: _sideSize),
      ],
    );
  }
}

/// 배지 한 칸. [badge] 가 null 이면 **빈 자리**를 그린다(자리를 없애지 않는다).
///
/// 획득/미획득 **양쪽 다 흰 원 + 테두리**이고 안에 배지 자산이 들어가느냐만 다르다.
/// 미획득만 회색으로 채우던 안은 빈 칸이 얼룩처럼 읽혔다 — 되돌리지 말 것.
class _BadgeSlot extends StatelessWidget {
  const _BadgeSlot({required this.badge, required this.size});

  final AcquiredBadge? badge;

  /// 원의 지름. 배지 자산은 이보다 작게(테두리 안쪽에) 그려진다.
  final double size;

  static const _iconRatio = 0.7;

  @override
  Widget build(BuildContext context) {
    final b = badge;
    final icon = size * _iconRatio;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ResultCardWidget._white,
        border: Border.all(color: ResultCardWidget._slotBorder, width: 2),
      ),
      child: b == null
          ? null
          : Image.asset(
              b.assetPath,
              width: icon,
              height: icon,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.emoji_events,
                size: icon * 0.7,
                color: ResultCardWidget._inkSub,
              ),
            ),
    );
  }
}
