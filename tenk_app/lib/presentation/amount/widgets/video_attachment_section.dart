import 'package:flutter/material.dart';

/// 영상 첨부 상태를 보여주고 행동 버튼을 노출하는 공용 위젯.
///
/// 두 모드를 [expandable] 로 가른다:
/// - **즉시 모드** (`expandable: false`, record 화면): "있음" 시 메시지 + 다시촬영/삭제 즉시.
/// - **미리보기 모드** (`expandable: true`, edit 화면): "있음" 시 메시지 + "영상 보기" 만.
///   미리보기·재촬영·삭제는 부모가 별도 화면([AmountVideoPreviewScreen])으로 띄워서 처리.
class VideoAttachmentSection extends StatelessWidget {
  const VideoAttachmentSection({
    super.key,
    required this.hasVideo,
    required this.fromServer,
    required this.onPickNew,
    required this.onRemove,
    this.expandable = false,
    this.previewLoading = false,
    this.onTapPreview,
  });

  /// 영상이 첨부된 상태인지. 로컬 path 든 서버 영상이든 동일하게 "있음" 으로 처리.
  final bool hasVideo;

  /// 기존 서버 영상인지 여부. 메시지를 살짝 다르게 보여주기 위해서만 사용.
  final bool fromServer;

  /// "촬영하기" / "다시 촬영" 트리거.
  final VoidCallback onPickNew;

  /// "삭제" 트리거. 영상 없음 상태 또는 expandable 모드에서는 호출되지 않는다.
  final VoidCallback onRemove;

  /// true 면 hasVideo 시 "영상 보기" 만 노출 — 미리보기·재촬영·삭제는 부모가 별도 화면에서 처리.
  /// false (기본) 면 hasVideo 시 메시지+다시촬영/삭제 즉시 노출 (record 화면).
  final bool expandable;

  /// "영상 보기" 가 외부 작업 중인지 (서버 영상 다운로드 등). 버튼 비활성 + 스피너 표시.
  final bool previewLoading;

  /// "영상 보기" 탭 콜백. expandable=true 일 때만 의미.
  final VoidCallback? onTapPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget body;
    if (!hasVideo) {
      body = _buildEmpty(context);
    } else if (!expandable) {
      body = _buildAttachedImmediate(context);
    } else {
      body = _buildAttachedPreviewOnly(context);
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: body,
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.videocam_off_outlined, color: theme.colorScheme.outline),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '첨부된 영상이 없어요.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: onPickNew,
          icon: const Icon(Icons.videocam),
          label: const Text('촬영하기'),
        ),
      ],
    );
  }

  Widget _buildAttachedImmediate(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fromServer ? '기존 영상이 첨부돼 있어요.' : '2초 영상 녹화 완료',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onPickNew,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 촬영'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('삭제'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttachedPreviewOnly(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.check_circle, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            fromServer ? '기존 영상이 첨부돼 있어요.' : '2초 영상 녹화 완료',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: previewLoading ? null : onTapPreview,
          icon: previewLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: Text(previewLoading ? '불러오는 중…' : '영상 보기'),
        ),
      ],
    );
  }
}
