import 'package:flutter/material.dart';

import '../../../design/tokens.dart';

/// 예산 사용 진행률 바. 목록 카드·상세 요약 카드가 공유.
/// 예산 초과(over)면 트랙·채움을 코랄로 바꾸고 꽉 채운다.
class ChallengeProgressBar extends StatelessWidget {
  const ChallengeProgressBar({
    super.key,
    required this.ratio,
    required this.over,
    this.height = 8,
  });

  final double ratio;
  final bool over;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: height,
        color: over ? AppColors.dangerTint : AppColors.primaryTint,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: over ? 1.0 : ratio.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: over ? AppColors.danger : AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
      ),
    );
  }
}
