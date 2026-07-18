import 'package:flutter/material.dart';

/// Tenk 디자인 토큰 — 색/타이포/여백/라운드의 단일 진실.
///
/// 방향: **절제된 뉴트럴 베이스(웜 크림) + 민트 accent, 리워드 순간에만 화려.**
/// 화면·위젯은 여기서만 색·스타일을 가져오고 hex 를 직접 박지 말 것.
/// (결과 카드처럼 캡처 시 ThemeData 영향을 받으면 안 되는 곳은 예외 — 그건 위젯에 hardcode.)
class AppColors {
  AppColors._();

  // ── Neutral (평소 UI 90%) ──
  static const bg = Color(0xFFFAF9F6); // 화면 배경 (웜 크림)
  static const surface = Color(0xFFFFFFFF); // 카드 표면
  static const surfaceAlt = Color(0xFFF3F1EA); // 입력칸 등 옅은 채움
  static const ink = Color(0xFF23211D); // 주 텍스트 · 숫자 (웜 차콜)
  static const inkSub = Color(0xFF6E6A61); // 보조 라벨
  static const inkMuted = Color(0xFFA9A49A); // placeholder · 3차
  static const line = Color(0xFFECE8E0); // 구분선 · 보더

  // ── Primary (민트) ──
  static const primary = Color(0xFF1FBE9C); // 버튼 채움 · 활성
  static const primaryDark = Color(0xFF17A588); // pressed
  static const primaryTint = Color(0xFFE3F6F0); // 활성 알약 · 진행률 트랙
  static const onPrimary = Color(0xFFFFFFFF);

  // ── Semantic (뜻이 있을 때만) ──
  static const success = Color(0xFF12B886); // 절약 · 무지출 · 성공
  static const successTint = Color(0xFFE3F6F0);
  static const danger = Color(0xFFFF6B6B); // 초과 · 삭제 · 에러
  static const dangerTint = Color(0xFFFDECEC);
  static const warn = Color(0xFFE0951B); // 확정 대기 (텍스트 대비용 딥앰버)
  static const warnTint = Color(0xFFFFF1D6);

  // ── 챌린지 상태색 (텍스트색 + 틴트 배경) ──
  static const statusBefore = Color(0xFF8A857B);
  static const statusBeforeTint = Color(0xFFF0EDE6);
  static const statusActive = primary;
  static const statusActiveTint = primaryTint;
  static const statusAwait = warn;
  static const statusAwaitTint = warnTint;
  static const statusSuccess = Color(0xFF0A8F66);
  static const statusSuccessTint = Color(0xFFE3F6F0);
  static const statusFail = Color(0xFFC56B6B);
  static const statusFailTint = Color(0xFFF6E9E9);

  // ── Reward (페이오프 전용 — 평소엔 안 씀) ──
  static const rewardSuccessTop = Color(0xFFFFE6A0);
  static const rewardSuccessBottom = Color(0xFFFFC247);
  static const rewardPurple = Color(0xFF8B72FF);
  static const rewardFailTop = Color(0xFFE9EAEE);
  static const rewardFailBottom = Color(0xFFC7CAD1);
  static const rewardFailInk = Color(0xFF4A4E58);
}

/// 8pt 기반 여백 스케일.
class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
}

/// 라운드(코너) 스케일.
class AppRadius {
  AppRadius._();
  static const card = 20.0;
  static const button = 15.0;
  static const chip = 12.0;
  static const pill = 999.0;
}

/// 타이포 스케일. 위계는 색이 아니라 크기·굵기로.
/// 숫자가 열로 정렬되는 곳(금액)은 tabular figures.
class AppTypo {
  AppTypo._();

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// 금액 히어로 (잔액/목표 등).
  static const amountHero = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    letterSpacing: -0.5,
    height: 1.1,
    fontFeatures: _tabular,
  );

  /// 카드/섹션 제목.
  static const title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    letterSpacing: -0.2,
  );

  /// 본문.
  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
    height: 1.4,
  );

  /// 보조 라벨 (섹션 헤더 등, 약간의 자간).
  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.inkSub,
    letterSpacing: 0.2,
  );

  /// 캡션 · 3차 정보.
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.inkMuted,
  );

  /// 금액 옆 "원" 단위 등 작은 접미사.
  static const amountUnit = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
}
