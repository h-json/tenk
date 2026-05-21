import 'package:flutter/material.dart';

import '../../../data/badge/badge.dart';

/// 챌린지 카드/상세에 끼우는 "획득한 배지 아이콘만 작게" row.
///
/// 잠금 상태나 카탈로그 전체는 노출하지 않는다 — 챌린지 단위라 미획득 배지를 보여줄 필요가 없음.
/// 비어 있으면 [SizedBox.shrink] 를 반환해 여백도 차지하지 않는다.
class ChallengeBadgesRow extends StatelessWidget {
  const ChallengeBadgesRow({
    super.key,
    required this.badges,
    this.iconSize = 28,
    this.maxItems,
  });

  final List<AcquiredBadge> badges;
  final double iconSize;

  /// null 이면 전체 노출. 카드처럼 좁은 공간은 4~5로 제한하고 +N 표시.
  final int? maxItems;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();

    final visible = maxItems != null && badges.length > maxItems!
        ? badges.take(maxItems!).toList()
        : badges;
    final hidden = badges.length - visible.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final badge in visible)
          _BadgeIcon(badge: badge, size: iconSize),
        if (hidden > 0) _MoreChip(count: hidden, size: iconSize),
      ],
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.badge, required this.size});

  final AcquiredBadge badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: badge.label,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          badge.assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _IconFallback(size: size),
        ),
      ),
    );
  }
}

class _IconFallback extends StatelessWidget {
  const _IconFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        border: Border.all(color: theme.colorScheme.primary, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.emoji_events,
        size: size * 0.6,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.count, required this.size});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      alignment: Alignment.center,
      child: Text(
        '+$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
