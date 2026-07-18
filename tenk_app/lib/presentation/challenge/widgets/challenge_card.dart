import 'package:flutter/material.dart';

import '../../../data/challenge/challenge.dart';
import '../../../design/tokens.dart';
import '../_formatters.dart';
import 'progress_bar.dart';

/// 목록의 챌린지 한 장.
///
/// 탭+섹션이 이미 상태로 분류하므로 카드는 좌측 색 스트라이프 없이 **동일한 구조**로 그린다
/// (모든 상태가 같은 행 수 → 높이 일관). 상태색은 우상단 마커에만 남긴다.
/// 배지는 카드에서 빼고(상세에서만 노출) 높이 변동을 없앤다.
class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.onTap,
  });

  final Challenge challenge;
  final VoidCallback onTap;

  bool get _isDone => challenge.result != null;

  @override
  Widget build(BuildContext context) {
    final done = _isDone;
    final beforeStart = challenge.isBeforeStart;
    final overBudget = !beforeStart && challenge.balance < 0;
    final ratio = (beforeStart || challenge.targetAmount <= 0)
        ? 0.0
        : (challenge.totalSpent / challenge.targetAmount).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
        boxShadow: done
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0F1C1D21),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        challenge.name,
                        style: done
                            ? AppTypo.title.copyWith(color: AppColors.inkSub)
                            : AppTypo.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _marker(),
                  ],
                ),
                const SizedBox(height: 12),
                Text(beforeStart ? '목표' : '남은 금액', style: AppTypo.caption),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: AppTypo.amountHero.copyWith(
                      fontSize: 26,
                      color: overBudget ? AppColors.danger : AppColors.ink,
                    ),
                    children: [
                      TextSpan(
                        text: formatNumber(
                          beforeStart
                              ? challenge.targetAmount
                              : challenge.balance,
                        ),
                      ),
                      TextSpan(
                        text: '원',
                        style: AppTypo.amountUnit.copyWith(
                          fontSize: 16,
                          color: overBudget ? AppColors.danger : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ChallengeProgressBar(ratio: ratio, over: overBudget),
                const SizedBox(height: 8),
                Text(_caption(done, beforeStart), style: _captionStyle(done)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _caption(bool done, bool beforeStart) {
    if (beforeStart) {
      return formatShortPeriod(challenge.startDate, challenge.endDate);
    }
    if (done) {
      final saved = challenge.balance.abs();
      return challenge.result == ChallengeResult.success
          ? '${formatWon(saved)} 아꼈어요'
          : '${formatWon(saved)} 초과했어요';
    }
    return '목표 ${formatWon(challenge.targetAmount)} · 사용 ${formatWon(challenge.totalSpent)}';
  }

  TextStyle _captionStyle(bool done) {
    if (!done) return AppTypo.caption;
    return AppTypo.caption.copyWith(
      color: challenge.result == ChallengeResult.success
          ? AppColors.statusSuccess
          : AppColors.statusFail,
      fontWeight: FontWeight.w700,
    );
  }

  /// 우상단 마커 — 상태색을 담는 유일한 곳.
  Widget _marker() {
    final (String text, Color color, Color tint) = switch (challenge) {
      Challenge(result: ChallengeResult.success) => (
        '성공',
        AppColors.statusSuccess,
        AppColors.statusSuccessTint,
      ),
      Challenge(result: ChallengeResult.fail) => (
        '실패',
        AppColors.statusFail,
        AppColors.statusFailTint,
      ),
      Challenge(awaitsFinalize: true) => (
        '확정하기',
        AppColors.statusAwait,
        AppColors.statusAwaitTint,
      ),
      Challenge(isBeforeStart: true) => (
        formatStartsOn(challenge.startDate),
        AppColors.statusBefore,
        AppColors.statusBeforeTint,
      ),
      _ => (
        formatDday(challenge.endDate),
        AppColors.statusActive,
        AppColors.statusActiveTint,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
