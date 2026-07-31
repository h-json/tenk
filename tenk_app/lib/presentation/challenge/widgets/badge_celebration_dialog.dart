import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../app/scopes.dart';
import '../../../data/badge/badge.dart';
import '../../../data/challenge/challenge.dart';
import '../../../data/settings/app_settings.dart';
import '../../../design/tokens.dart';
import 'badge_next_goal.dart';
import 'badge_style.dart';

const String _celebrationSound = 'sounds/badge_acquired.mp3';

/// 연출 타임라인 (총 [_totalDuration]). 구간을 바꿀 땐 세 상수를 같이 볼 것 —
/// "무대 → 임팩트 → 여운" 3막이고, 임팩트는 **한 점에 몰아줘야** "쿵" 이 생긴다.
/// (예전엔 900ms 에 걸쳐 완만하게 퍼져 있어 절정이 없었다.)
const Duration _totalDuration = Duration(milliseconds: 1400);
const Duration _impactAt = Duration(milliseconds: 180); // 소리·햅틱·파티클
const double _impactStart = 180 / 1400;
const double _impactPeak = 520 / 1400;
const double _settleEnd = 660 / 1400;

/// 여러 배지를 순차로 보여준다. 한 번의 amount 기록으로 STREAK + NO_SPEND 가 동시에 들어올 수
/// 있어서 큐 형태 — 동시 표시는 시각적으로 혼란스럽고 모달끼리 겹치면 dismiss 도 깨진다.
///
/// 배지가 2개 이상이면 CTA 가 `다음 (1/2)` 로 **남은 개수를 알려준다**. 연출 강도를
/// 낮춰 피로를 줄이는 대신(모든 배지는 동등하게 축하한다) 체인의 길이를 밝혀서
/// 반복이 지루함이 아니라 수확으로 읽히게 하는 쪽을 택했다 (듀오링고 패턴).
Future<void> showBadgeCelebrations(
  BuildContext context,
  List<AcquiredBadge> badges, {
  required Challenge challenge,
}) async {
  for (var i = 0; i < badges.length; i++) {
    if (!context.mounted) return;
    final badge = badges[i];

    // 첫 프레임에 디코딩이 걸리면 임팩트가 시작부터 끊긴다. 자산이 없으면 조용히 넘어가고
    // 아래 errorBuilder 폴백이 받는다.
    try {
      await precacheImage(AssetImage(badge.assetPath), context);
    } catch (_) {}
    if (!context.mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '배지 획득',
      // 무대(radial 글로우)가 가운데를 밝히기 때문에 barrier 가 옅으면 뒤 화면이 비쳐
      // 연출과 경쟁한다 (0.78 로 실측했더니 상세 화면의 카드·버튼이 그대로 읽혔다).
      barrierColor: Colors.black.withValues(alpha: 0.93),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, _, _) => _BadgeCelebrationDialog(
        badge: badge,
        challenge: challenge,
        index: i,
        total: badges.length,
      ),
      transitionBuilder: (_, anim, _, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }
}

class _BadgeCelebrationDialog extends StatefulWidget {
  const _BadgeCelebrationDialog({
    required this.badge,
    required this.challenge,
    required this.index,
    required this.total,
  });

  final AcquiredBadge badge;
  final Challenge challenge;
  final int index;
  final int total;

  @override
  State<_BadgeCelebrationDialog> createState() =>
      _BadgeCelebrationDialogState();
}

class _BadgeCelebrationDialogState extends State<_BadgeCelebrationDialog>
    with TickerProviderStateMixin {
  late final AnimationController _timeline;

  /// 여운 구간의 글로우 호흡. 타임라인과 분리해 느리게 반복시킨다.
  late final AnimationController _breath;

  late final Animation<double> _scale;
  late final Animation<double> _wobble;
  late final Animation<double> _glow;
  late final Animation<double> _shine;

  late final List<_Particle> _particles;

  /// 효과음 전용 플레이어. dispose 에서 정지되므로 **CTA 로 닫으면 소리도 함께 끊기고**,
  /// 다음 배지 모달이 이전 소리 위에 겹쳐 재생되지 않는다 (자산이 ~2초라 실제로 겹친다).
  final AudioPlayer _sound = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  Timer? _impactTimer;
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    _particles = _buildParticles(badgeParticleColors(widget.badge));

    _timeline = AnimationController(vsync: this, duration: _totalDuration);
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // 0.3 에서 대기 → 1.12 로 오버슈트 → 1.0 으로 안착. 오버슈트가 "쿵" 의 정체다.
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.3), weight: 180),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.3,
          end: 1.12,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 340,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.12,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 140,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 740),
    ]).animate(_timeline);

    // 여운의 좌우 흔들림 (rad ≈ ±2.9°). 임팩트가 끝난 뒤에만 돈다.
    _wobble =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.05), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.05), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 0.05, end: 0.0), weight: 1),
        ]).animate(
          CurvedAnimation(
            parent: _timeline,
            curve: const Interval(_settleEnd, 0.78, curve: Curves.easeInOut),
          ),
        );

    _glow = CurvedAnimation(
      parent: _timeline,
      curve: const Interval(_impactStart, _impactPeak, curve: Curves.easeOut),
    );

    // 광택이 배지 위를 한 번 지나간다 — 자산이 글로시라 여운에 가장 잘 먹는다.
    _shine = CurvedAnimation(
      parent: _timeline,
      curve: const Interval(0.40, 0.78, curve: Curves.easeInOut),
    );

    _timeline.forward();

    // 소리·햅틱은 시각 임팩트와 같은 순간에. 셋이 흩어지면 "쿵" 이 뭉개진다.
    _impactTimer = Timer(_impactAt, _impact);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings ??= SettingsScope.of(context);
  }

  void _impact() {
    if (!mounted) return;
    _settings?.heavyImpact();
    if (_settings?.soundEnabled ?? true) {
      // 실패해도 무시 — 소리는 햅틱·시각의 보조다 (녹화 시작음과 같은 방침).
      unawaited(_sound.play(AssetSource(_celebrationSound)).catchError((_) {}));
    }
  }

  @override
  void dispose() {
    _impactTimer?.cancel();
    _sound.dispose();
    _timeline.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = widget.badge;
    final accent = badgeAccentColor(badge);
    final goal = badgeNextGoalText(badge, widget.challenge, DateTime.now());
    final isLast = widget.index == widget.total - 1;

    // ⚠️ Material 로 감싸지 않으면 `showGeneralDialog` 의 라우트엔 Material 조상이 없어
    // 기본 TextStyle 을 못 찾은 Text 가 **노란 밑줄 디버그 표시**로 렌더된다 (실측).
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            // 배지 중심을 고정해 파티클 원점·무대 중심과 정확히 일치시킨다.
            final badgeSize = math.min(180.0, w * 0.46);
            final centerY = h * 0.36;
            final origin = Offset(w / 2, centerY);

            return Stack(
              children: [
                // ── 무대: 배지 뒤에 깔리는 radial 글로우 (검정 단색 위에 "떠오르게") ──
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _timeline,
                      builder: (_, _) => DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(0, (centerY / h) * 2 - 1),
                            radius: 0.75,
                            colors: [
                              accent.withValues(alpha: 0.28 * _glow.value),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // ── 파티클 버스트 ──
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _timeline,
                      builder: (_, _) => CustomPaint(
                        painter: _ParticlePainter(
                          particles: _particles,
                          progress: _timeline.value,
                          origin: origin,
                        ),
                      ),
                    ),
                  ),
                ),
                // ── 배지 ──
                Positioned(
                  top: centerY - badgeSize / 2,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_timeline, _breath]),
                      builder: (_, _) {
                        return Transform.rotate(
                          angle: _wobble.value,
                          child: Transform.scale(
                            scale: _scale.value,
                            child: _BadgeWithGlow(
                              badge: badge,
                              accent: accent,
                              size: badgeSize,
                              glow: _glow.value,
                              breath: _breath.value,
                              shine: _shine.value,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // ── 텍스트 (60ms 간격 순차 등장 — 한꺼번에 페이드하면 위계가 안 보인다) ──
                Positioned(
                  top: centerY + badgeSize / 2 + 32,
                  left: 24,
                  right: 24,
                  child: Column(
                    children: [
                      _Staggered(
                        timeline: _timeline,
                        startMs: 400,
                        child: Text(
                          '🎉 배지 획득!',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Staggered(
                        timeline: _timeline,
                        startMs: 460,
                        child: Text(
                          badge.label,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _Staggered(
                        timeline: _timeline,
                        startMs: 520,
                        child: Text(
                          badge.type.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (goal != null) ...[
                        const SizedBox(height: 20),
                        _Staggered(
                          timeline: _timeline,
                          startMs: 580,
                          child: _GoalPill(text: goal, accent: accent),
                        ),
                      ],
                    ],
                  ),
                ),
                // ── CTA: 힌트 텍스트가 아니라 명시적 버튼. 체인이면 남은 개수를 밝힌다 ──
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24 + MediaQuery.of(context).padding.bottom,
                  child: _Staggered(
                    timeline: _timeline,
                    startMs: 700,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.ink,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: Text(
                          isLast
                              ? '완료'
                              : '다음 (${widget.index + 1}/${widget.total})',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 타임라인의 [startMs] 부터 260ms 동안 아래에서 살짝 올라오며 페이드인.
class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.timeline,
    required this.startMs,
    required this.child,
  });

  final AnimationController timeline;
  final int startMs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final total = _totalDuration.inMilliseconds;
    final begin = startMs / total;
    final end = math.min(1.0, (startMs + 260) / total);
    final anim = CurvedAnimation(
      parent: timeline,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - anim.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// "다음 목표" 한 줄. 없으면 이 위젯 자체가 안 그려진다 ([badgeNextGoalText] 가 null).
class _GoalPill extends StatelessWidget {
  const _GoalPill({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BadgeWithGlow extends StatelessWidget {
  const _BadgeWithGlow({
    required this.badge,
    required this.accent,
    required this.size,
    required this.glow,
    required this.breath,
    required this.shine,
  });

  final AcquiredBadge badge;
  final Color accent;
  final double size;

  /// 0.0 → 1.0. 임팩트 구간에 차오르는 글로우 강도.
  final double glow;

  /// 0.0 → 1.0 왕복. 여운의 느린 호흡.
  final double breath;

  /// 0.0 → 1.0. 광택이 배지를 가로지르는 진행도.
  final double shine;

  @override
  Widget build(BuildContext context) {
    // 호흡은 임팩트가 끝난 뒤에만 티가 나게 (glow 가 1 에 가까울수록 폭이 커진다).
    final pulse = 1 + 0.12 * breath * glow;
    // 자산에 반짝임이 이미 그려진 배지는 광택을 약하게 — 세게 걸면 겹쳐서 지저분해진다.
    final shineStrength = badgeHasBakedSparkle(badge) ? 0.35 : 0.7;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.55 * glow),
            blurRadius: 52 * glow * pulse,
            spreadRadius: 14 * glow * pulse,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.09),
        child: ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            // 좌상단 → 우하단으로 지나가는 흰 띠. shine 이 0 이나 1 이면 화면 밖.
            final t = shine * 2 - 0.5;
            return LinearGradient(
              begin: Alignment(-1 + t * 2 - 0.6, -1),
              end: Alignment(-1 + t * 2 + 0.6, 1),
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: shineStrength),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(rect);
          },
          child: Image.asset(
            badge.assetPath,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _IconFallback(accent: accent),
          ),
        ),
      ),
    );
  }
}

class _IconFallback extends StatelessWidget {
  const _IconFallback({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.2),
        border: Border.all(color: accent, width: 2),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.emoji_events, size: 80, color: accent),
    );
  }
}

// ─────────────────────────── 파티클 ───────────────────────────

/// 컨페티 한 조각. Lottie 대신 직접 그린다 — 배지 **단계색에 맞춰** 뿌려야 하는데
/// Lottie 는 색이 JSON 에 박혀 있어 연동이 안 된다 (그리고 의존성이 하나 줄었다).
class _Particle {
  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.rotation,
    required this.spin,
    required this.color,
    required this.isRect,
    required this.delay,
  });

  final double angle;
  final double speed;
  final double size;
  final double rotation;
  final double spin;
  final Color color;
  final bool isRect;

  /// 0.0~1.0 중 이 조각이 튀어나가기 시작하는 지연 (동시에 다 나가면 링처럼 보인다).
  final double delay;
}

List<_Particle> _buildParticles(List<Color> palette) {
  final rnd = math.Random();
  return List.generate(46, (i) {
    // 위쪽으로 살짝 치우친 전방위 분사. 아래로만 떨어지면 폭발감이 없다.
    final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 1.8;
    return _Particle(
      angle: angle,
      speed: 180 + rnd.nextDouble() * 320,
      size: 6 + rnd.nextDouble() * 8,
      rotation: rnd.nextDouble() * math.pi,
      spin: (rnd.nextDouble() - 0.5) * 12,
      color: palette[i % palette.length],
      isRect: i % 3 != 0,
      delay: rnd.nextDouble() * 0.06,
    );
  });
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.origin,
  });

  final List<_Particle> particles;
  final double progress;
  final Offset origin;

  /// 낙하 가속도 (논리 px). 위로 솟았다가 떨어지는 포물선을 만든다.
  static const double _gravity = 900;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < _impactStart) return;

    // 임팩트 시점부터의 경과를 0~1 로 정규화.
    final span = 1 - _impactStart;
    final base = ((progress - _impactStart) / span).clamp(0.0, 1.0);

    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final t = ((base - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      // 초반에 빠르고 뒤로 갈수록 감속 (공기 저항 느낌).
      final travel = 1 - math.pow(1 - t, 2.2).toDouble();
      final dx = math.cos(p.angle) * p.speed * travel;
      final dy = math.sin(p.angle) * p.speed * travel + _gravity * t * t * 0.5;

      // 후반 40% 에 걸쳐 사라진다.
      final opacity = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4);
      if (opacity <= 0) continue;

      paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(p.rotation + p.spin * t);
      if (p.isRect) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.55,
            ),
            const Radius.circular(1.5),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.35, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.progress != progress || old.origin != origin;
}
