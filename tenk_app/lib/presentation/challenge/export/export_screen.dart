import 'package:flutter/material.dart';

import '../../../data/amount/amount.dart';
import '../../../data/challenge/challenge.dart';
import '../../amount/spend_category.dart';
import '../../common/date_time_picker.dart';
import '../../common/text_input_sheet.dart';
import '../_formatters.dart';
import 'export_prefetch_screen.dart';
import 'export_settings_screen.dart';

/// 챌린지 영상 합본 내보내기 1단계 — 클립 선택 (확정된 챌린지에서만 진입).
///
/// 합본에 포함할 클립을 고르고 각 자막을 편집한다. "다음" 을 누르면 합성 설정([ExportSettingsScreen])
/// 으로 넘어가고, 자막 위치·배경·결과 카드 포함 설정과 실제 합성은 거기서 처리한다.
///
/// **상태는 화면 안에서만 산다** — 자막 편집은 `amount.memo` 를 건드리지 않고 세션 동안만 유지.
/// 사용자가 화면을 떠나면 사라진다. memo 가 진짜 영구 기억, 여기 comment 는 일회용 오버라이드.
class ExportScreen extends StatefulWidget {
  const ExportScreen({
    super.key,
    required this.challenge,
    required this.amounts,
  });

  final Challenge challenge;
  final List<Amount> amounts;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  /// 영상 합본에 들어갈 후보 클립. spentDt ASC 로 정렬 — 실제 합성 순서와 일치하게 보여준다.
  late final List<_Clip> _clips;

  @override
  void initState() {
    super.initState();
    final sorted = [...widget.amounts]
      ..sort((a, b) => a.spentDt.compareTo(b.spentDt));
    _clips = sorted
        .map((a) => _Clip(
              source: a,
              selected: true,
              comment: _defaultCommentFor(a),
            ))
        .toList();
  }

  /// 자막 디폴트. memo 있으면 memo, 없으면 지출=`"내용 금액원"` / 무지출=`"무지출"`.
  /// 회의 결정 #4 와 1:1 매칭. memo 정규화(공백→null)는 백엔드에서 끝나 있으므로 여기선 null/empty 만 거른다.
  static String _defaultCommentFor(Amount a) {
    final memo = a.memo?.trim();
    if (memo != null && memo.isNotEmpty) return memo;
    if (a.noSpend) return '무지출';
    final content = (a.content ?? '').trim();
    final won = formatWon(a.amount);
    return content.isEmpty ? won : '$content $won';
  }

  void _toggle(int index, bool? value) {
    setState(() => _clips[index].selected = value ?? false);
  }

  void _setAllSelected(bool value) {
    setState(() {
      for (final c in _clips) {
        c.selected = value;
      }
    });
  }

  Future<void> _editComment(int index) async {
    final clip = _clips[index];
    final result = await showTextInputSheet(
      context: context,
      title: '자막 편집',
      description: '영상이 재생될 때 자막으로 표시돼요. 저장된 한 줄 평은 영향받지 않아요.',
      initial: clip.comment,
      maxLines: 3,
      confirmLabel: '저장',
      resetValue: _defaultCommentFor(clip.source),
    );
    if (result == null || !mounted) return;
    setState(() => clip.comment = result);
  }

  Future<void> _next() async {
    final items = _clips
        .where((c) => c.selected)
        .map((c) => ExportPrefetchItem(source: c.source, comment: c.comment))
        .toList(growable: false);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExportSettingsScreen(
          challenge: widget.challenge,
          amounts: widget.amounts,
          items: items,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = _clips.where((c) => c.selected).length;
    final allSelected = selectedCount == _clips.length && _clips.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('영상 내보내기'),
        actions: [
          TextButton(
            onPressed: _clips.isEmpty
                ? null
                : () => _setAllSelected(!allSelected),
            child: Text(allSelected ? '전체 해제' : '전체 선택'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _clips.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '합칠 기록이 없어요.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            : Column(
                children: [
                  _HeaderBanner(
                    challenge: widget.challenge,
                    selectedCount: selectedCount,
                    totalCount: _clips.length,
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: _clips.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (_, i) => _ClipTile(
                        order: i + 1,
                        clip: _clips[i],
                        onToggle: (v) => _toggle(i, v),
                        onEditComment: () => _editComment(i),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: selectedCount > 0 ? _next : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text('다음 ($selectedCount개)'),
          ),
        ),
      ),
    );
  }
}

class _Clip {
  _Clip({
    required this.source,
    required this.selected,
    required this.comment,
  });

  final Amount source;
  bool selected;
  String comment;
}

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({
    required this.challenge,
    required this.selectedCount,
    required this.totalCount,
  });

  final Challenge challenge;
  final int selectedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: theme.colorScheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '시간 순서대로 합쳐져요. 빼고 싶은 기록은 체크를 풀어주세요.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            '자막은 기록을 탭해서 편집할 수 있어요. (저장된 한 줄 평은 안 바뀌어요.)',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Text(
            '선택 $selectedCount / 전체 $totalCount',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({
    required this.order,
    required this.clip,
    required this.onToggle,
    required this.onEditComment,
  });

  final int order;
  final _Clip clip;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onEditComment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = clip.source;
    final isNoSpend = a.noSpend;
    final hasVideo = a.mediaFiles.isNotEmpty;
    final dimmed = !clip.selected;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onEditComment,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: clip.selected, onChanged: onToggle),
              const SizedBox(width: 4),
              Expanded(
                child: Opacity(
                  opacity: dimmed ? 0.45 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#$order',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 로케일 시각 표기가 24시간제보다 길어 좁은 기기에서
                          // 이 행이 넘칠 수 있어 Flexible + ellipsis 로 받는다.
                          Flexible(
                            child: Text(
                              formatDateWithTime(context, a.spentDt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            hasVideo
                                ? Icons.videocam_outlined
                                : Icons.text_fields,
                            size: 14,
                            color: theme.colorScheme.outline,
                          ),
                          if (!hasVideo)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                '텍스트 카드',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isNoSpend
                            ? '무지출'
                            : '${spendCategoryForCode(a.category).label} · ${a.content ?? ''}',
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (!isNoSpend)
                        Text(
                          formatWon(a.amount),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 8),
                      _CommentPreview(comment: clip.comment),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentPreview extends StatelessWidget {
  const _CommentPreview({required this.comment});

  final String comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.closed_caption,
            size: 16,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              comment,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.edit,
            size: 14,
            color: theme.colorScheme.outline,
          ),
        ],
      ),
    );
  }
}

/// 한 클립의 자막을 편집하는 bottom sheet. 입력값을 반환하면 호출처가 그 자리에 반영.
