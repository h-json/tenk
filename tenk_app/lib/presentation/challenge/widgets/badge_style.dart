import 'package:flutter/material.dart';

import '../../../data/badge/badge.dart';
import '../../../design/tokens.dart';

/// 배지 획득 연출의 색. **단계(conditionValue)로 갈리고 타입으로는 갈리지 않는다** —
/// 자산 PNG 가 브론즈(3) → 실버(7) → 골드(14) → 주얼골드(30) 사다리로 그려져 있고
/// `streak_3` 과 `no_spend_3` 이 같은 구리색이라서다. 근거·표는
/// [assets_src/badges/README.md]. 자산 색을 바꾸면 여기도 같이.
///
/// 연출 강도는 단계와 무관하게 **전부 동일**하다 (2026-08-01 결정). 위계는 연출이
/// 아니라 자산의 색이 만든다 — 등급별로 연출을 갈라 30일만 화려하게 만들지 말 것.
Color badgeAccentColor(AcquiredBadge badge) {
  if (badge.type == BadgeType.challengeSuccess) return AppColors.rewardGlow;
  return switch (badge.conditionValue) {
    <= 3 => AppColors.badgeBronze,
    <= 7 => AppColors.badgeSilver,
    <= 14 => AppColors.badgeGold,
    _ => AppColors.rewardGlow, // 30 = 더 밝은 주얼 골드
  };
}

/// 파티클 색 팔레트. 보석이 박힌 자산(30단계·성공)만 다색으로 뿌려 자산과 호응시킨다.
List<Color> badgeParticleColors(AcquiredBadge badge) {
  final accent = badgeAccentColor(badge);
  final jeweled =
      badge.type == BadgeType.challengeSuccess || badge.conditionValue >= 30;
  if (!jeweled) {
    return [accent, Color.lerp(accent, Colors.white, 0.45)!];
  }
  return [
    accent,
    Color.lerp(accent, Colors.white, 0.4)!,
    AppColors.badgeGemCyan,
    AppColors.badgeGemPink,
    AppColors.badgeGemPurple,
  ];
}

/// 자산에 반짝임이 이미 그려져 있는 배지 — 광택 sweep 을 약하게 건다.
/// 세게 걸면 자산의 sparkle 과 겹쳐 지저분해진다.
bool badgeHasBakedSparkle(AcquiredBadge badge) =>
    badge.type == BadgeType.challengeSuccess || badge.conditionValue >= 30;
