import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../data/amount/amount.dart';
import '../../data/api/api_error.dart';
import '../../data/challenge/challenge.dart';
import '../../design/tokens.dart';
import '../amount/amount_edit_screen.dart';
import '../amount/amount_record_screen.dart';
import '../amount/spend_category.dart';
import '../common/async_state.dart';
import '_formatters.dart';
import 'export/export_screen.dart';
import 'result_card/result_card_screen.dart';
import 'widgets/badge_celebration_dialog.dart';
import 'widgets/challenge_badges.dart';
import 'widgets/challenge_status.dart';
import 'widgets/progress_bar.dart';

/// 챌린지 1건 + 그 챌린지의 지출 기록 목록을 함께 다룬다.
/// `AsyncStateMixin`은 단일 자원 가정이라 둘을 record로 묶어 한 번에 fetch한다.
typedef _Detail = ({Challenge challenge, List<Amount> amounts});

class ChallengeDetailScreen extends StatefulWidget {
  const ChallengeDetailScreen({super.key, required this.challengeId});

  final int challengeId;

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen>
    with AsyncStateMixin<ChallengeDetailScreen, _Detail> {
  bool _changed = false;
  bool _busy = false;

  /// 이미 한 번 본 챌린지-배지의 식별자. 새 응답에서 여기 없는 것만 축하 모달로 띄운다.
  /// 첫 로드는 [_baselineSet] 으로 막아 baseline 만 채우고 모달은 띄우지 않는다 —
  /// 화면에 처음 들어왔을 때 과거에 받은 배지를 다시 축하하면 안 됨.
  final Set<int> _knownBadgeIds = <int>{};
  bool _baselineSet = false;

  @override
  Future<_Detail> fetch() async {
    final challengeApi = ChallengeScope.of(context);
    final amountApi = AmountScope.of(context);
    final results = await Future.wait([
      challengeApi.getOne(widget.challengeId),
      amountApi.list(widget.challengeId),
    ]);
    return (
      challenge: results[0] as Challenge,
      amounts: results[1] as List<Amount>,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ensureLoaded();
  }

  /// `reload` 가 끝난 뒤 한 번씩 호출 — baseline 외엔 신규 배지만 골라 축하 모달을 띄운다.
  /// `replaceData` 처럼 mixin 의 reload 를 우회하는 경로에서도 직접 호출할 것.
  Future<void> _syncBadgesAndMaybeCelebrate() async {
    final current = data;
    if (current == null) return;
    final incoming = current.challenge.badges;
    final incomingIds = incoming.map((b) => b.challengeBadgeId).toSet();

    if (!_baselineSet) {
      _knownBadgeIds
        ..clear()
        ..addAll(incomingIds);
      _baselineSet = true;
      return;
    }

    final newBadges = incoming
        .where((b) => !_knownBadgeIds.contains(b.challengeBadgeId))
        .toList()
      ..sort((a, b) => a.acquiredDt.compareTo(b.acquiredDt));

    // 알려진 집합은 모달 띄우기 전에 먼저 갱신해 둔다 —
    // 모달 중 reload 가 또 돌아도 같은 배지를 다시 큐에 넣지 않도록.
    _knownBadgeIds
      ..clear()
      ..addAll(incomingIds);

    if (newBadges.isEmpty || !mounted) return;
    await showBadgeCelebrations(context, newBadges);
  }

  @override
  Future<void> reload() async {
    await super.reload();
    if (!mounted) return;
    await _syncBadgesAndMaybeCelebrate();
  }

  Future<void> _finalize() async {
    setState(() => _busy = true);
    try {
      final next = await ChallengeScope.of(context).finalize(widget.challengeId);
      _changed = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결과가 확정됐어요.')),
      );
      final current = data;
      if (current != null) {
        replaceData((challenge: next, amounts: current.amounts));
        await _syncBadgesAndMaybeCelebrate();
      } else {
        await reload();
      }
      if (!mounted) return;
      // 배지 큐가 끝난 뒤 결과 카드 풀스크린 push (자동 진입점 — finalize 경로 한정).
      final after = data;
      if (after != null) {
        await _openResultCard(after.challenge, after.amounts);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = toApiException(e).message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('확정 실패: $msg')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openResultCard(Challenge challenge, List<Amount> amounts) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ResultCardScreen(
          challenge: challenge,
          amounts: amounts,
        ),
      ),
    );
  }

  Future<void> _rename(Challenge challenge) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: challenge.name),
    );
    if (newName == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final next = await ChallengeScope.of(context).rename(challenge.id, newName);
      _changed = true;
      final current = data;
      if (current != null) {
        replaceData((challenge: next, amounts: current.amounts));
      }
    } catch (e) {
      if (!mounted) return;
      final msg = toApiException(e).message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('이름 변경 실패: $msg')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('챌린지 삭제'),
        content: const Text('이 챌린지와 관련 기록이 삭제돼요. 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ChallengeScope.of(context).delete(widget.challengeId);
      if (!mounted) return;
      Navigator.of(context).pop<bool>(true);
    } catch (e) {
      if (!mounted) return;
      final msg = toApiException(e).message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('삭제 실패: $msg')));
      setState(() => _busy = false);
    }
  }

  void _openExport(Challenge challenge, List<Amount> amounts) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExportScreen(challenge: challenge, amounts: amounts),
      ),
    );
  }

  Future<void> _openRecord(Challenge challenge, {required bool noSpend}) async {
    final result = await Navigator.of(context).push<AmountRecordResult>(
      MaterialPageRoute<AmountRecordResult>(
        builder: (_) => AmountRecordScreen(
          challenge: challenge,
          noSpend: noSpend,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      _changed = true;
      if (result.removedNoSpendCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오늘 무지출 기록이 취소되었어요.')),
        );
      }
      await reload();
    }
  }

  Future<void> _openEdit(Challenge challenge, Amount amount) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AmountEditScreen(
          challenge: challenge,
          original: amount,
        ),
      ),
    );
    if (!mounted) return;
    if (changed == true) {
      _changed = true;
      await reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop<bool>(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(data?.challenge.name ?? '챌린지 상세'),
          actions: [
            // 이름 변경은 결과 확정 전(result == null)까지만.
            if (data?.challenge.result == null)
              IconButton(
                tooltip: '이름 변경',
                onPressed: _busy || data == null
                    ? null
                    : () => _rename(data!.challenge),
                icon: const Icon(Icons.edit_outlined),
              ),
            IconButton(
              tooltip: '삭제',
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: reload,
            child: AsyncStateView<_Detail>(
              data: data,
              error: error,
              loading: loading,
              onRetry: reload,
              builder: (_, detail) => _DetailBody(
                challenge: detail.challenge,
                amounts: detail.amounts,
                busy: _busy,
                onFinalize: detail.challenge.awaitsFinalize ? _finalize : null,
                onRecordSpend: detail.challenge.isInProgress
                    ? () => _openRecord(detail.challenge, noSpend: false)
                    : null,
                onRecordNoSpend: detail.challenge.isInProgress
                    ? () => _openRecord(detail.challenge, noSpend: true)
                    : null,
                onEditAmount: (amount) => _openEdit(detail.challenge, amount),
                onOpenExport: detail.challenge.result != null
                    ? () => _openExport(detail.challenge, detail.amounts)
                    : null,
                onOpenResultCard: detail.challenge.result != null
                    ? () => _openResultCard(detail.challenge, detail.amounts)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.challenge,
    required this.amounts,
    required this.busy,
    required this.onFinalize,
    required this.onRecordSpend,
    required this.onRecordNoSpend,
    required this.onEditAmount,
    required this.onOpenExport,
    required this.onOpenResultCard,
  });

  final Challenge challenge;
  final List<Amount> amounts;
  final bool busy;
  final VoidCallback? onFinalize;
  final VoidCallback? onRecordSpend;
  final VoidCallback? onRecordNoSpend;

  /// 기록 카드 탭 → 수정 화면 진입. 수정 화면 안에서 저장/삭제 양쪽 모두 처리한다.
  final ValueChanged<Amount> onEditAmount;

  /// 챌린지가 확정(SUCCESS/FAIL)된 뒤에만 non-null. 진행 중·시작 전이면 null → 진입 카드 숨김.
  final VoidCallback? onOpenExport;

  /// 결과 카드 풀스크린 진입. 확정 후에만 non-null.
  final VoidCallback? onOpenResultCard;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SummaryCard(challenge: challenge),
        if (onFinalize != null) ...[
          const SizedBox(height: 16),
          _FinalizeCard(busy: busy, onFinalize: onFinalize!),
        ],
        if (challenge.isBeforeStart) ...[
          const SizedBox(height: 16),
          _InfoCard(
            icon: Icons.schedule_outlined,
            text:
                '아직 시작하지 않은 챌린지예요.\n${formatDate(challenge.startDate)}부터 기록할 수 있어요.',
          ),
        ],
        if (challenge.isInProgress) ...[
          const SizedBox(height: 16),
          _TodayActionPanel(
            amounts: amounts,
            busy: busy,
            onRecordSpend: onRecordSpend,
            onRecordNoSpend: onRecordNoSpend,
          ),
        ],
        if (onOpenResultCard != null) ...[
          const SizedBox(height: 16),
          _EntryCard(
            icon: Icons.celebration_outlined,
            title: '결과 카드',
            subtitle: '챌린지 결과를 카드 한 장으로. 갤러리 저장·공유까지.',
            tint: AppColors.rewardSuccessTop,
            fg: const Color(0xFF8A6100),
            onTap: busy ? null : onOpenResultCard,
          ),
        ],
        if (onOpenExport != null) ...[
          const SizedBox(height: 12),
          _EntryCard(
            icon: Icons.movie_creation_outlined,
            title: '영상 만들기',
            subtitle: '기록 영상을 시간순으로 합쳐 하나의 영상으로.',
            tint: AppColors.primaryTint,
            fg: AppColors.statusSuccess,
            onTap: busy ? null : onOpenExport,
          ),
        ],
        if (challenge.totalSpent > 0) ...[
          const SizedBox(height: 28),
          _CategoryBreakdown(amounts: amounts, total: challenge.totalSpent),
        ],
        const SizedBox(height: 28),
        Row(
          children: [
            Text('기록', style: AppTypo.title),
            const SizedBox(width: 6),
            Text('${amounts.length}',
                style: AppTypo.title.copyWith(color: AppColors.inkMuted)),
          ],
        ),
        const SizedBox(height: 8),
        if (amounts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              '아직 기록이 없어요.',
              style: AppTypo.body.copyWith(color: AppColors.inkMuted),
              textAlign: TextAlign.center,
            ),
          )
        else
          ..._buildGroupedAmounts(amounts, onEditAmount),
      ],
    );
  }

  /// 백엔드는 spentDt asc 로 보내지만 화면은 "최신이 위" 가 자연스러움 → 그룹 자체도, 그룹 안에서도 내림차순.
  /// 같은 날에 무지출과 지출이 섞이는 케이스는 백엔드 자동 취소 로직이 막아주지만 (`AmountService.record`),
  /// 방어적으로 헤더는 "지출이 있으면 합계 / 없고 무지출만 있으면 '무지출'" 로 표기.
  List<Widget> _buildGroupedAmounts(
    List<Amount> all,
    ValueChanged<Amount> onEdit,
  ) {
    final byDay = <DateTime, List<Amount>>{};
    for (final a in all) {
      byDay.putIfAbsent(dateOnly(a.spentDt), () => []).add(a);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final dayAmounts = byDay[day]!
        ..sort((a, b) => b.spentDt.compareTo(a.spentDt));
      final spendTotal = dayAmounts
          .where((a) => !a.noSpend)
          .fold<int>(0, (sum, a) => sum + a.amount);
      final isNoSpendDay = spendTotal == 0 && dayAmounts.any((a) => a.noSpend);

      if (i > 0) widgets.add(const SizedBox(height: 16));
      widgets.add(_DaySectionHeader(
        day: day,
        isNoSpend: isNoSpendDay,
        spendTotal: spendTotal,
      ));
      widgets.add(const SizedBox(height: 4));
      for (final a in dayAmounts) {
        widgets.add(_AmountTile(
          amount: a,
          onTap: () => onEdit(a),
        ));
      }
    }
    return widgets;
  }
}

/// 진행 중 챌린지에서 "오늘 어떤 행동을 할 수 있나" 를 좌우하는 패널.
///
/// 분기 3가지:
/// 1. 오늘 무지출 기록이 있음 → 강조 카드만, 두 버튼 모두 숨김 (오늘은 절약을 의지로 박았으니
///    지출 진입점을 보여주지 않음. 마음 바꾸려면 아래 무지출 row 삭제).
/// 2. 오늘 지출 기록이 1건 이상 → 오늘 지출 합계 카드 + 지출 버튼만 (무지출은 이미 의미 없음).
/// 3. 오늘 기록 없음 → 지출/무지출 두 버튼 다.
class _TodayActionPanel extends StatelessWidget {
  const _TodayActionPanel({
    required this.amounts,
    required this.busy,
    required this.onRecordSpend,
    required this.onRecordNoSpend,
  });

  final List<Amount> amounts;
  final bool busy;
  final VoidCallback? onRecordSpend;
  final VoidCallback? onRecordNoSpend;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final todayAmounts =
        amounts.where((a) => dateOnly(a.spentDt) == today).toList();
    final hasNoSpendToday = todayAmounts.any((a) => a.noSpend);
    final spendToday =
        todayAmounts.where((a) => !a.noSpend).toList(growable: false);
    final hasSpendToday = spendToday.isNotEmpty;
    final spendTodayTotal =
        spendToday.fold<int>(0, (sum, a) => sum + a.amount);

    if (hasNoSpendToday) {
      // 이번 챌린지 안의 누적 무지출 일수 — 백엔드 자동 취소 로직이 있어 noSpend row 의 DISTINCT day
      // 만 세면 백엔드 정의(`BadgeGrantService.daysWithOnlyNoSpend`)와 동일하다.
      final noSpendDays = amounts
          .where((a) => a.noSpend)
          .map((a) => dateOnly(a.spentDt))
          .toSet()
          .length;
      return _NoSpendTodayCard(noSpendDays: noSpendDays);
    }
    if (hasSpendToday) {
      return Column(
        children: [
          _TodaySpendSummaryCard(total: spendTodayTotal),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : onRecordSpend,
            icon: const Icon(Icons.payments_outlined),
            label: const Text('지출 기록'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: busy ? null : onRecordSpend,
            icon: const Icon(Icons.payments_outlined),
            label: const Text('지출 기록'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: busy ? null : onRecordNoSpend,
            icon: const Icon(Icons.do_not_disturb_on_outlined),
            label: const Text('무지출'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoSpendTodayCard extends StatelessWidget {
  const _NoSpendTodayCard({required this.noSpendDays});

  /// 이 챌린지 안의 누적 무지출 일수. NO_SPEND 배지의 사다리(3/7/14/30) 와 동일한 정의.
  final int noSpendDays;

  /// 백엔드 `BadgeType.NO_SPEND` 의 condition_value 와 일치. 사다리는 [docs/schema.sql](docs/schema.sql)
  /// badge 마스터 시드와 1:1 매칭되며, 변경 시 양쪽을 같이 갱신할 것.
  static const _ladder = [3, 7, 14, 30];

  @override
  Widget build(BuildContext context) {
    final nextStep = _ladder.firstWhere(
      (s) => s > noSpendDays,
      orElse: () => _ladder.last,
    );
    final reachedMax = noSpendDays >= _ladder.last;
    final goal = reachedMax ? _ladder.last : nextStep;
    final progress = (noSpendDays / goal).clamp(0.0, 1.0);
    final daysToGo = (nextStep - noSpendDays).clamp(0, _ladder.last);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          const Text('🌱', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          Text(
            '오늘은 무지출!',
            style: AppTypo.title.copyWith(
              fontSize: 20,
              color: AppColors.statusSuccess,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            reachedMax
                ? '챌린지 풀 무지출 $noSpendDays일 달성!'
                : '이번 챌린지 무지출 $noSpendDays일째 누적 중',
            style: AppTypo.body.copyWith(color: AppColors.inkSub),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              height: 10,
              color: AppColors.surface,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$noSpendDays / $goal일', style: AppTypo.caption),
              Text(
                reachedMax ? '최고 단계 달성 🎉' : '다음 배지까지 $daysToGo일',
                style: AppTypo.caption.copyWith(
                  color: AppColors.statusSuccess,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 상세 상단 히어로 요약 카드. 목록 카드와 같은 언어(좌측 상태 스트라이프 + 남은 금액
/// 히어로 + 진행률 바)로 목록↔상세 일관성을 만든다.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final status = ChallengeStatusStyle.of(challenge);
    final overBudget = challenge.balance < 0;
    final ratio = challenge.targetAmount <= 0
        ? 0.0
        : (challenge.totalSpent / challenge.targetAmount).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1223211D),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: status.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: status.tint,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
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
                        const Spacer(),
                        Text(
                          formatShortPeriod(
                              challenge.startDate, challenge.endDate),
                          style: AppTypo.caption,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text('남은 금액', style: AppTypo.caption),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(
                        style: AppTypo.amountHero.copyWith(
                          fontSize: 36,
                          color:
                              overBudget ? AppColors.danger : AppColors.ink,
                        ),
                        children: [
                          TextSpan(text: formatNumber(challenge.balance)),
                          TextSpan(
                            text: '원',
                            style: AppTypo.amountUnit.copyWith(
                              fontSize: 20,
                              color: overBudget
                                  ? AppColors.danger
                                  : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ChallengeProgressBar(ratio: ratio, over: overBudget),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('사용 ${formatWon(challenge.totalSpent)}',
                            style: AppTypo.caption),
                        Text('목표 ${formatWon(challenge.targetAmount)}',
                            style: AppTypo.caption),
                      ],
                    ),
                    if (challenge.badges.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ChallengeBadgesRow(
                          badges: challenge.badges, iconSize: 32),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 확정 대기 상태의 강조 카드 — 앰버 틴트 + 확정 버튼 + 안내.
class _FinalizeCard extends StatelessWidget {
  const _FinalizeCard({required this.busy, required this.onFinalize});

  final bool busy;
  final VoidCallback onFinalize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warnTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Text(
            '챌린지가 종료됐어요.\n결과를 확정하면 배지를 받을 수 있어요.',
            style: AppTypo.body.copyWith(color: const Color(0xFF8A5A00)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onFinalize,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('결과 확정하기'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 정보성 안내 카드 (시작 전 등). 뉴트럴 틴트.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.inkMuted, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: AppTypo.body.copyWith(color: AppColors.inkSub),
            ),
          ),
        ],
      ),
    );
  }
}

/// 확정 후 노출되는 진입 카드(결과 카드 / 영상 만들기 공용). 아이콘 + 제목/부제 + chevron.
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.fg,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final Color fg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Icon(icon, size: 24, color: fg),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypo.title),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTypo.caption),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodaySpendSummaryCard extends StatelessWidget {
  const _TodaySpendSummaryCard({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          const Icon(Icons.today, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '오늘 ${formatWon(total)} 지출했어요',
              style: AppTypo.title,
            ),
          ),
        ],
      ),
    );
  }
}

/// 카테고리별 지출 분포 (뱅크샐러드식 가로 바). 지출 기록에서 클라 계산 — 백엔드 무관.
/// 무지출/0원은 제외, 금액 큰 순 정렬.
class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.amounts, required this.total});

  final List<Amount> amounts;
  final int total;

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, int>{};
    for (final a in amounts) {
      if (a.noSpend || a.amount <= 0) continue;
      final code = a.category ?? 'ETC';
      byCategory[code] = (byCategory[code] ?? 0) + a.amount;
    }
    if (byCategory.isEmpty || total <= 0) return const SizedBox.shrink();

    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('카테고리별 지출', style: AppTypo.title),
          const SizedBox(height: 16),
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _CategoryRow(
              code: entries[i].key,
              amount: entries[i].value,
              total: total,
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.code,
    required this.amount,
    required this.total,
  });

  final String code;
  final int amount;
  final int total;

  @override
  Widget build(BuildContext context) {
    final category = spendCategoryForCode(code);
    final ratio = (amount / total).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();
    return Column(
      children: [
        Row(
          children: [
            Icon(category.icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(category.label,
                style: AppTypo.body.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(formatWon(amount), style: AppTypo.body),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: Text(
                '$percent%',
                style: AppTypo.caption,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            height: 8,
            color: AppColors.primaryTint,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DaySectionHeader extends StatelessWidget {
  const _DaySectionHeader({
    required this.day,
    required this.isNoSpend,
    required this.spendTotal,
  });

  final DateTime day;
  final bool isNoSpend;
  final int spendTotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(formatDayHeader(day), style: AppTypo.label),
          Text(
            isNoSpend ? '무지출' : formatWon(spendTotal),
            style: AppTypo.label.copyWith(
              color: isNoSpend ? AppColors.statusSuccess : AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({required this.amount, required this.onTap});

  final Amount amount;

  /// 탭 → 수정 화면 진입. 삭제도 수정 화면 안에서만 가능 (별도 X 버튼 없음).
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasVideo = amount.mediaFiles.isNotEmpty;
    final category = spendCategoryForCode(amount.category);
    final noSpend = amount.noSpend;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: noSpend
                        ? AppColors.successTint
                        : AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Icon(
                    noSpend
                        ? Icons.do_not_disturb_on_outlined
                        : category.icon,
                    size: 22,
                    color: noSpend
                        ? AppColors.statusSuccess
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        noSpend
                            ? '무지출'
                            : '${category.label} · ${amount.content ?? ''}',
                        style: AppTypo.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(formatDateTime(amount.spentDt),
                              style: AppTypo.caption),
                          if (hasVideo) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.videocam_outlined,
                                size: 14, color: AppColors.inkMuted),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (!noSpend) ...[
                  const SizedBox(width: 8),
                  Text(
                    formatWon(amount.amount),
                    style: AppTypo.title.copyWith(fontSize: 15),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 챌린지 이름 변경 다이얼로그. '확인' 시 trim 된 새 이름을 `pop<String>` 으로 반환.
/// 클라 1차 검증(길이/제어문자)은 서버 검증과 동일 — 진실의 원천은 서버.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  static final _forbiddenChars = RegExp(r'[\p{Cc}\p{Cf}]', unicode: true);

  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop<String>(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('챌린지 이름 변경'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: 100,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            hintText: '예: 외식 줄이기',
          ),
          validator: (raw) {
            final v = (raw ?? '').trim();
            if (v.isEmpty) return '이름을 입력해주세요.';
            if (v.length > 100) return '이름은 100자 이하로 입력해주세요.';
            if (_forbiddenChars.hasMatch(v)) {
              return '사용할 수 없는 문자가 포함되어 있어요.';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('확인'),
        ),
      ],
    );
  }
}
