import 'package:flutter/material.dart';

import '../../../data/challenge/challenge.dart';
import '../../../design/tokens.dart';
import '../_formatters.dart';
import 'challenge_badges.dart';
import 'challenge_status.dart';

/// 목록의 챌린지 한 장. 상태를 한눈에 읽히게 하는 게 목적:
/// 좌측 상태색 스트라이프 + 우상단 D-day/시작/확정 마커 + 진행률 바.
/// 완료(성공/실패)는 톤다운해 진행 중 카드가 시각적으로 튀게 한다.
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
    final status = ChallengeStatusStyle.of(challenge);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: _isDone
            ? null
            : const [
                BoxShadow(
                  color: Color(0x1223211D),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
        border: _isDone ? Border.all(color: AppColors.line) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: status.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: _isDone ? _doneBody(status) : _activeBody(status),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 진행 중 / 시작 전 / 확정 대기 ──
  Widget _activeBody(ChallengeStatusStyle status) {
    final overBudget = challenge.balance < 0;
    final ratio = challenge.targetAmount <= 0
        ? 0.0
        : (challenge.totalSpent / challenge.targetAmount).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                challenge.name,
                style: AppTypo.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _marker(),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          challenge.isBeforeStart ? '목표' : '남은 금액',
          style: AppTypo.caption,
        ),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            style: AppTypo.amountHero.copyWith(
              color: overBudget ? AppColors.danger : AppColors.ink,
            ),
            children: [
              TextSpan(
                text: formatNumber(
                  challenge.isBeforeStart
                      ? challenge.targetAmount
                      : challenge.balance,
                ),
              ),
              TextSpan(
                text: '원',
                style: AppTypo.amountUnit.copyWith(
                  color: overBudget ? AppColors.danger : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        if (!challenge.isBeforeStart) ...[
          const SizedBox(height: 12),
          _ProgressBar(ratio: ratio, over: overBudget),
          const SizedBox(height: 8),
          Text(
            '목표 ${formatWon(challenge.targetAmount)} · 사용 ${formatWon(challenge.totalSpent)}',
            style: AppTypo.caption,
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            formatShortPeriod(challenge.startDate, challenge.endDate),
            style: AppTypo.caption,
          ),
        ],
        if (challenge.badges.isNotEmpty) ...[
          const SizedBox(height: 12),
          ChallengeBadgesRow(
            badges: challenge.badges,
            iconSize: 24,
            maxItems: 5,
          ),
        ],
      ],
    );
  }

  // ── 완료 (성공/실패) — 톤다운 ──
  Widget _doneBody(ChallengeStatusStyle status) {
    final saved = challenge.balance; // 목표-사용. 양수=절약, 음수=초과.
    final isSuccess = challenge.result == ChallengeResult.success;
    final resultLine = isSuccess
        ? '${formatWon(saved.abs())} 아꼈어요'
        : '${formatWon(saved.abs())} 초과했어요';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                challenge.name,
                style: AppTypo.title.copyWith(color: AppColors.inkSub),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
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
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          resultLine,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isSuccess ? AppColors.statusSuccess : AppColors.statusFail,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formatShortPeriod(challenge.startDate, challenge.endDate),
          style: AppTypo.caption,
        ),
        if (challenge.badges.isNotEmpty) ...[
          const SizedBox(height: 10),
          ChallengeBadgesRow(
            badges: challenge.badges,
            iconSize: 22,
            maxItems: 6,
          ),
        ],
      ],
    );
  }

  /// 우상단 마커 — 진행 중=D-day, 시작 전=시작일, 확정 대기="확정하기".
  Widget _marker() {
    final (String text, Color color, Color tint) = switch (challenge) {
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

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.ratio, required this.over});

  final double ratio;
  final bool over;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: 8,
        color: over ? AppColors.dangerTint : AppColors.primaryTint,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: over ? 1.0 : ratio,
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
