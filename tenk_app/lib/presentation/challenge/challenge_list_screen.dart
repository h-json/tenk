import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../data/challenge/challenge.dart';
import '../../design/tokens.dart';
import '../common/async_state.dart';
import '../profile/profile_screen.dart';
import 'challenge_create_screen.dart';
import 'challenge_detail_screen.dart';
import 'widgets/challenge_card.dart';

class ChallengeListScreen extends StatefulWidget {
  const ChallengeListScreen({super.key});

  @override
  State<ChallengeListScreen> createState() => _ChallengeListScreenState();
}

class _ChallengeListScreenState extends State<ChallengeListScreen>
    with AsyncStateMixin<ChallengeListScreen, List<Challenge>> {
  @override
  Future<List<Challenge>> fetch() => ChallengeScope.of(context).list();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ensureLoaded();
  }

  Future<void> _openCreate() async {
    // 기본 이름 "챌린지 N" — N = 삭제분 제외 현재 챌린지 수 + 1. 서버 목록이 이미
    // 삭제분을 제외하므로 data.length 가 곧 N-1. (삭제 후 재생성 시 중복 가능하나
    // 사용자가 자유 편집하는 기본값이라 허용 — handoff/CLAUDE.md "챌린지 이름" 참고)
    final defaultName = '챌린지 ${(data?.length ?? 0) + 1}';
    // Navigator generic 추론 문제로 pop result가 누락되는 경우가 있어,
    // result 의존 없이 push 종료 시점에 무조건 새로고침. (handoff.md "함정 — Flutter" 참고)
    await Navigator.of(context).push<Challenge>(
      MaterialPageRoute<Challenge>(
        builder: (_) => ChallengeCreateScreen(defaultName: defaultName),
      ),
    );
    if (!mounted) return;
    await reload();
  }

  Future<void> _openDetail(Challenge challenge) async {
    // 상세에서 finalize / delete가 일어났을 수 있으니 push 후 무조건 새로고침.
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ChallengeDetailScreen(challengeId: challenge.id),
      ),
    );
    if (!mounted) return;
    await reload();
  }

  Future<void> _openProfile() async {
    // 닉네임/이메일 변경은 챌린지 데이터에 영향 없으니 보통은 reload 없음.
    // 단 테스트 데이터 재생성(pop(true))이 일어났으면 목록을 새로고침한다.
    final seeded = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ProfileScreen()),
    );
    if (!mounted) return;
    if (seeded == true) {
      await reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('테스트 데이터를 생성했어요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = data ?? const <Challenge>[];
    final awaitingCount = all.where((c) => c.awaitsFinalize).length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('내 챌린지'),
          actions: [
            IconButton(
              tooltip: '내 정보',
              onPressed: _openProfile,
              icon: const Icon(Icons.account_circle_outlined),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(child: _InProgressTabLabel(awaitingCount: awaitingCount)),
              const Tab(text: '완료'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: AsyncStateView<List<Challenge>>(
            data: data,
            error: error,
            loading: loading,
            onRetry: reload,
            builder: (_, challenges) => TabBarView(
              children: [
                _ActiveTab(
                  challenges: challenges,
                  onRefresh: reload,
                  onTapChallenge: _openDetail,
                  onCreate: _openCreate,
                ),
                _DoneTab(
                  challenges: challenges,
                  onRefresh: reload,
                  onTapChallenge: _openDetail,
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCreate,
          icon: const Icon(Icons.add),
          label: const Text('새 챌린지'),
        ),
      ),
    );
  }
}

/// "진행 중" 탭 라벨 — 확정 대기가 있으면 옆에 카운트 뱃지를 붙여 놓치지 않게.
class _InProgressTabLabel extends StatelessWidget {
  const _InProgressTabLabel({required this.awaitingCount});

  final int awaitingCount;

  @override
  Widget build(BuildContext context) {
    if (awaitingCount == 0) return const Text('진행 중');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('진행 중'),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.warn,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '$awaitingCount',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// 진행 중 탭: 확정 대기 → 진행 중 → 시작 전 순으로 그룹핑.
class _ActiveTab extends StatelessWidget {
  const _ActiveTab({
    required this.challenges,
    required this.onRefresh,
    required this.onTapChallenge,
    required this.onCreate,
  });

  final List<Challenge> challenges;
  final Future<void> Function() onRefresh;
  final void Function(Challenge) onTapChallenge;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final awaiting = challenges.where((c) => c.awaitsFinalize).toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));
    final inProgress = challenges.where((c) => c.isInProgress).toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));
    final before = challenges.where((c) => c.isBeforeStart).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    final hasAny = awaiting.isNotEmpty || inProgress.isNotEmpty || before.isNotEmpty;

    final children = <Widget>[];
    void addSection(String label, List<Challenge> list) {
      if (list.isEmpty) return;
      children.add(_SectionHeader(label: label, count: list.length));
      for (final c in list) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ChallengeCard(challenge: c, onTap: () => onTapChallenge(c)),
          ),
        );
      }
    }

    addSection('확정 대기', awaiting);
    addSection('진행 중', inProgress);
    addSection('시작 전', before);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: hasAny
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: children,
            )
          : _EmptyScroll(
              message: challenges.isEmpty
                  ? '아직 챌린지가 없어요.\n아래 + 버튼으로 첫 챌린지를 시작해보세요.'
                  : '진행 중인 챌린지가 없어요.\n[완료] 탭에서 지난 챌린지를 볼 수 있어요.',
              actionLabel: challenges.isEmpty ? '새 챌린지 시작' : null,
              onAction: challenges.isEmpty ? onCreate : null,
            ),
    );
  }
}

/// 완료 탭: 성공/실패를 종료일 최신순으로. (히스토리라 시간순 하나면 충분)
class _DoneTab extends StatelessWidget {
  const _DoneTab({
    required this.challenges,
    required this.onRefresh,
    required this.onTapChallenge,
  });

  final List<Challenge> challenges;
  final Future<void> Function() onRefresh;
  final void Function(Challenge) onTapChallenge;

  @override
  Widget build(BuildContext context) {
    final done = challenges.where((c) => c.result != null).toList()
      ..sort((a, b) => b.endDate.compareTo(a.endDate));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: done.isEmpty
          ? const _EmptyScroll(message: '아직 완료한 챌린지가 없어요.')
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: done.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => ChallengeCard(
                challenge: done[i],
                onTap: () => onTapChallenge(done[i]),
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Text(label, style: AppTypo.label),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: AppTypo.label.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _EmptyScroll extends StatelessWidget {
  const _EmptyScroll({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypo.body.copyWith(color: AppColors.inkSub),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
