import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../data/amount/amount.dart';
import '../../data/api/api_error.dart';
import '../../data/challenge/challenge.dart';
import '../amount/amount_record_screen.dart';
import '../common/async_state.dart';
import '_formatters.dart';
import 'widgets/challenge_badges.dart';
import 'widgets/challenge_status.dart';

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
      } else {
        await reload();
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

  Future<void> _openRecord(Challenge challenge, {required bool noSpend}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AmountRecordScreen(
          challenge: challenge,
          noSpend: noSpend,
        ),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      _changed = true;
      await reload();
    }
  }

  Future<void> _deleteAmount(Amount amount) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 기록과 첨부된 영상이 삭제돼요.'),
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
      await AmountScope.of(context).delete(
        challengeId: widget.challengeId,
        amountId: amount.id,
      );
      _changed = true;
      if (!mounted) return;
      await reload();
    } catch (e) {
      if (!mounted) return;
      final msg = toApiException(e).message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('삭제 실패: $msg')));
    } finally {
      if (mounted) setState(() => _busy = false);
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
          title: const Text('챌린지 상세'),
          actions: [
            IconButton(
              tooltip: '삭제',
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: RefreshIndicator(
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
              onDeleteAmount: _deleteAmount,
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
    required this.onDeleteAmount,
  });

  final Challenge challenge;
  final List<Amount> amounts;
  final bool busy;
  final VoidCallback? onFinalize;
  final VoidCallback? onRecordSpend;
  final VoidCallback? onRecordNoSpend;
  final ValueChanged<Amount> onDeleteAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = challenge.targetAmount == 0
        ? 0.0
        : (challenge.totalSpent / challenge.targetAmount).clamp(0.0, 1.0);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        ChallengeStatusBanner(challenge: challenge),
        const SizedBox(height: 24),
        Text(
          formatPeriod(challenge.startDate, challenge.endDate),
          style: theme.textTheme.titleSmall,
        ),
        if (challenge.badges.isNotEmpty) ...[
          const SizedBox(height: 16),
          ChallengeBadgesRow(badges: challenge.badges, iconSize: 36),
        ],
        const SizedBox(height: 24),
        Text('잔액', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          formatWon(challenge.balance),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: challenge.balance < 0
                ? theme.colorScheme.error
                : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: progress >= 1.0
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('누적 지출 ${formatWon(challenge.totalSpent)}',
                style: theme.textTheme.bodyMedium),
            Text('목표 ${formatWon(challenge.targetAmount)}',
                style: theme.textTheme.bodyMedium),
          ],
        ),
        if (onFinalize != null) ...[
          const SizedBox(height: 32),
          FilledButton(
            onPressed: busy ? null : onFinalize,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('결과 확정하기'),
          ),
          const SizedBox(height: 8),
          Text(
            '챌린지가 종료됐어요. 결과를 확정해서 배지를 받을 수 있어요.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        if (challenge.isBeforeStart) ...[
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '아직 시작하지 않은 챌린지예요.\n시작일(${formatDate(challenge.startDate)})부터 기록할 수 있어요.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
        if (onRecordSpend != null || onRecordNoSpend != null) ...[
          const SizedBox(height: 32),
          Row(
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
          ),
        ],
        const SizedBox(height: 32),
        Text('기록 (${amounts.length})', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (amounts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              '아직 기록이 없어요.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          )
        else
          ...amounts.map((a) => _AmountTile(
                amount: a,
                onDelete: busy ? null : () => onDeleteAmount(a),
              )),
      ],
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({required this.amount, required this.onDelete});

  final Amount amount;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasVideo = amount.mediaFiles.isNotEmpty;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: amount.noSpend
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.primaryContainer,
          child: Icon(
            amount.noSpend
                ? Icons.do_not_disturb_on_outlined
                : Icons.payments_outlined,
            color: amount.noSpend
                ? theme.colorScheme.onSecondaryContainer
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          amount.noSpend ? '무지출' : '${amount.category ?? ''} · ${amount.content ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(formatDateTime(amount.spentDt)),
            if (hasVideo) ...[
              const SizedBox(width: 8),
              Icon(Icons.videocam_outlined,
                  size: 14, color: theme.colorScheme.outline),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!amount.noSpend)
              Text(
                formatWon(amount.amount),
                style: theme.textTheme.titleSmall,
              ),
            IconButton(
              tooltip: '삭제',
              onPressed: onDelete,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
