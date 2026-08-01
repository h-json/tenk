import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 결과 카드 **상단 컬러 블록 안**에 뿌리는 정적 컨페티.
///
/// 카드가 오프스크린 캡처되므로 여기서도 ThemeData 를 읽지 않는다. 좌표는 블록 크기에 대한
/// **비율**이라 챌린지 이름이 1줄이든 2줄이든(=블록 높이가 변해도) 배치가 무너지지 않는다.
///
/// ⚠️ **가운데 열(fx 0.12~0.88)을 비워둔다.** 헤더·히어로 금액이 거기 놓이므로 조각을 두면
/// 글자 옆에 붙어 오타처럼 보인다 — 제목이 2줄인 카드에서 실제로 그랬다.
class ResultBlockConfettiPainter extends CustomPainter {
  const ResultBlockConfettiPainter({required this.colors});

  /// 비어 있으면 그리지 않는다 (실패 카드 — 축하 장식을 붙일 자리가 아니다).
  final List<Color> colors;

  /// (fx, fy, 길이, 두께, 회전(rad), 색 인덱스, 불투명도). fx/fy 는 블록 크기 대비 비율.
  static const _pieces = <(double, double, double, double, double, int, double)>[
    // 최상단 띠 — 위에서 흩뿌려진 느낌.
    (0.20, 0.055, 15, 6, 0.5, 0, 0.95),
    (0.42, 0.032, 13, 6, -0.7, 1, 0.85),
    (0.63, 0.062, 14, 6, 1.1, 2, 0.90),
    (0.83, 0.036, 12, 5, 0.3, 1, 0.80),
    // 좌우 여백.
    (0.055, 0.20, 15, 6, -0.4, 1, 0.85),
    (0.94, 0.26, 14, 6, 0.9, 0, 0.80),
    (0.04, 0.42, 13, 6, 0.2, 2, 0.75),
    (0.955, 0.50, 14, 6, -1.0, 1, 0.72),
    (0.07, 0.60, 12, 5, 0.6, 0, 0.65),
    (0.93, 0.66, 13, 5, -0.3, 2, 0.62),
    // 아래쪽 조각은 알파를 낮춰 시선이 헤더·히어로에 남게 한다 (블록 끝이 이제
    // 선명하게 끊기므로 페이드에 먹히는 문제는 없다).
    (0.045, 0.71, 12, 5, 0.8, 1, 0.55),
    (0.95, 0.74, 12, 5, -0.6, 0, 0.42),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    for (final (fx, fy, len, thick, angle, colorIndex, alpha) in _pieces) {
      canvas.save();
      canvas.translate(fx * size.width, fy * size.height);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: thick, height: len),
          Radius.circular(thick / 2),
        ),
        Paint()
          ..color = colors[colorIndex % colors.length].withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ResultBlockConfettiPainter old) => old.colors != colors;
}

/// 결과 카드 화면 **진입 순간**의 1회성 컨페티 연출.
///
/// 캡처되는 카드 위젯과는 무관하다 — 화면 위에 얹히는 오버레이라 저장·공유 PNG 에는
/// 들어가지 않는다. 확정 직후 자동 진입일 때만 재생한다(상세에서 다시 열어볼 때마다
/// 터지면 축하가 아니라 지연처럼 느껴진다).
class ResultCardConfettiOverlay extends StatefulWidget {
  const ResultCardConfettiOverlay({super.key, required this.colors});

  final List<Color> colors;

  @override
  State<ResultCardConfettiOverlay> createState() => _ResultCardConfettiOverlayState();
}

class _ResultCardConfettiOverlayState extends State<ResultCardConfettiOverlay>
    with SingleTickerProviderStateMixin {
  static const _pieceCount = 48;
  static const _duration = Duration(milliseconds: 2400);

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _duration)..forward();

  /// 시드 고정 — 연출은 매번 같은 그림이어도 무방하고, 재빌드마다 흩어지면 안 된다.
  late final List<_ConfettiPiece> _pieces = _buildPieces();

  List<_ConfettiPiece> _buildPieces() {
    final rnd = math.Random(20260801);
    return List.generate(_pieceCount, (i) {
      return _ConfettiPiece(
        startX: rnd.nextDouble(),
        drift: (rnd.nextDouble() - 0.5) * 0.42,
        delay: rnd.nextDouble() * 0.28,
        fallSpan: 0.72 + rnd.nextDouble() * 0.28,
        length: 10 + rnd.nextDouble() * 10,
        thickness: 4 + rnd.nextDouble() * 3,
        spin: (rnd.nextDouble() - 0.5) * 10,
        color: widget.colors[i % widget.colors.length],
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) => CustomPaint(
          painter: _ConfettiPainter(
            pieces: _pieces,
            progress: _controller.value,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  const _ConfettiPiece({
    required this.startX,
    required this.drift,
    required this.delay,
    required this.fallSpan,
    required this.length,
    required this.thickness,
    required this.spin,
    required this.color,
  });

  final double startX;
  final double drift;
  final double delay;
  final double fallSpan;
  final double length;
  final double thickness;
  final double spin;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.pieces, required this.progress});

  final List<_ConfettiPiece> pieces;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((progress - p.delay) / p.fallSpan).clamp(0.0, 1.0);
      if (local <= 0) continue;
      // 낙하는 살짝 가속, 가로 흔들림은 사인파. 끝 20% 구간에서 서서히 사라진다.
      final y = -0.08 + local * local * 1.2;
      final x = p.startX + p.drift * math.sin(local * math.pi * 2.2);
      final fade = local > 0.8 ? (1 - (local - 0.8) / 0.2) : 1.0;

      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.rotate(p.spin * local);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.thickness,
            height: p.length,
          ),
          Radius.circular(p.thickness / 2),
        ),
        Paint()..color = p.color.withValues(alpha: fade.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
