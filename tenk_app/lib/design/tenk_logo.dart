import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// TenK 로고 마크 — **'10'**. 세로획+깃발이 '1', 오른쪽 링이 '0' 이면서 예산 게이지다.
///
/// 런처 아이콘과 **같은 형상**을 그린다. 자산 PNG 를 쓰지 않고 직접 그리는 이유는 배지
/// 컨페티를 `CustomPainter` 로 옮긴 것과 같다 — ① 색을 호출부가 정할 수 있어 민트/흰색
/// 반전에 자산이 두 벌 필요 없고 ② **결과 카드 캡처 경로에서 `precacheImage` 가 필요
/// 없다**(배지 PNG 는 첫 프레임 placeholder 가 캡처되는 회귀 때문에 필수다).
///
/// ⚠️ 비율 상수는 [assets_src/icon/generate_icons.py] 와 **같은 값**이어야 한다.
/// 한쪽만 고치면 앱 안의 로고와 런처 아이콘이 갈라진다. `_ink*` 는 그 스크립트의
/// `--ink` 출력값.
class TenkLogoMark extends StatelessWidget {
  const TenkLogoMark({
    super.key,
    this.size = 64,
    this.color,
    this.trackColor = AppColors.logoTrack,
  });

  final double size;

  /// 기본값은 민트(`AppColors.primary`). 민트 바탕 위에선 흰색을 넘길 것.
  final Color? color;

  /// 게이지 트랙(옅은 원). **null 이면 단색 실루엣** — 결과 카드 워터마크처럼
  /// 조용해야 하는 자리에서 쓴다.
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: TenkLogoPainter(
          color: color ?? AppColors.primary,
          trackColor: trackColor,
        ),
      ),
    );
  }
}

class TenkLogoPainter extends CustomPainter {
  const TenkLogoPainter({required this.color, this.trackColor});

  final Color color;
  final Color? trackColor;

  // ── 마크 형상 (generate_icons.py 와 동일) ──
  static const _stroke = 0.20;
  static const _flag = Offset(-0.16, 0.20);
  static const _ringCx = 0.60;
  static const _ringR = 0.40;
  static const _gapAt = 0.0;
  static const _gapHalf = 55.0;

  // 잉크 bbox (`python generate_icons.py --ink`). 마크를 상자 정중앙에 놓는 데 쓴다.
  static const _inkX = -0.2600;
  static const _inkY = -0.1000;
  static const _inkW = 1.3620;
  static const _inkH = 1.2020;

  static double _rad(double deg) => deg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / math.max(_inkW, _inkH);
    final origin = Offset(
      size.width / 2 - (_inkX + _inkW / 2) * unit,
      size.height / 2 - (_inkY + _inkH / 2) * unit,
    );

    Offset p(double rx, double ry) => origin + Offset(rx * unit, ry * unit);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = _stroke * unit;

    final ringRect = Rect.fromCircle(center: p(_ringCx, 0.5), radius: _ringR * unit);

    // '0' — 트랙(완전한 원) 먼저, 그 위에 게이지 링.
    if (trackColor != null) {
      canvas.drawCircle(p(_ringCx, 0.5), _ringR * unit, paint..color = trackColor!);
    }
    paint.color = color;
    canvas.drawArc(
      ringRect,
      _rad(_gapAt + _gapHalf),
      _rad(360 - _gapHalf * 2),
      false,
      paint,
    );

    // '1'
    canvas.drawLine(p(0, 0), p(0, 1), paint);
    canvas.drawLine(p(_flag.dx, _flag.dy), p(0, 0), paint);
  }

  @override
  bool shouldRepaint(TenkLogoPainter old) =>
      old.color != color || old.trackColor != trackColor;
}

/// 마크 + 워드마크 + 태그라인 세로 조합 — '브랜드를 보여주는 자리'용(로그인 화면).
///
/// 워드마크 표기는 앱 전체 규칙대로 **`TenK`** 고정 (CLAUDE.md "릴리스 빌드 / 배포").
class TenkLogoLockup extends StatelessWidget {
  const TenkLogoLockup({super.key, this.markSize = 88, this.showTagline = true});

  final double markSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TenkLogoMark(size: markSize),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'TenK',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
            letterSpacing: -0.5,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: AppSpacing.xs),
          const Text(
            '만원 챌린지',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.inkSub,
              letterSpacing: 2,
            ),
          ),
        ],
      ],
    );
  }
}
