import 'package:flutter/material.dart';

import '../../../data/challenge/challenge.dart';
import '../../../design/tokens.dart';

/// 챌린지 상태(시작 전 / 진행 중 / 결과 확정 대기 / 성공 / 실패)의 표시 스타일.
/// 라벨 + 텍스트색(color) + 옅은 배경(tint) 세 값을 담는다. 칩·배너·카드 스트라이프가 공유.
class ChallengeStatusStyle {
  const ChallengeStatusStyle({
    required this.label,
    required this.color,
    required this.tint,
  });

  final String label;
  final Color color;
  final Color tint;

  factory ChallengeStatusStyle.of(Challenge c) {
    return switch (c) {
      Challenge(result: ChallengeResult.success) => const ChallengeStatusStyle(
        label: '성공',
        color: AppColors.statusSuccess,
        tint: AppColors.statusSuccessTint,
      ),
      Challenge(result: ChallengeResult.fail) => const ChallengeStatusStyle(
        label: '실패',
        color: AppColors.statusFail,
        tint: AppColors.statusFailTint,
      ),
      Challenge(awaitsFinalize: true) => const ChallengeStatusStyle(
        label: '결과 확정 대기',
        color: AppColors.statusAwait,
        tint: AppColors.statusAwaitTint,
      ),
      Challenge(isBeforeStart: true) => const ChallengeStatusStyle(
        label: '시작 전',
        color: AppColors.statusBefore,
        tint: AppColors.statusBeforeTint,
      ),
      _ => const ChallengeStatusStyle(
        label: '진행 중',
        color: AppColors.statusActive,
        tint: AppColors.statusActiveTint,
      ),
    };
  }
}

/// 리스트 카드 상단에 박는 컴팩트한 라벨.
class ChallengeStatusChip extends StatelessWidget {
  const ChallengeStatusChip({super.key, required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final status = ChallengeStatusStyle.of(challenge);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.tint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          color: status.color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 상세 화면 상단의 더 큰 배너. 점 표시 + 라벨.
class ChallengeStatusBanner extends StatelessWidget {
  const ChallengeStatusBanner({super.key, required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final status = ChallengeStatusStyle.of(challenge);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: status.tint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: status.color),
          const SizedBox(width: 8),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 14,
              color: status.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
