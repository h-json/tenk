import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/scopes.dart';
import '../../data/amount/amount.dart';
import '../../data/api/api_error.dart';
import '../../data/challenge/challenge.dart';
import '../../design/tokens.dart';
import '../challenge/_formatters.dart';
import '../common/field_label.dart';
import 'amount_camera_screen.dart';
import 'amount_video_preview_screen.dart';
import 'spend_category.dart';
import 'widgets/budget_hint_row.dart';
import 'widgets/video_attachment_section.dart';

/// 기록 수정 화면. 카드 탭으로 진입한다.
///
/// 수정 가능한 것:
/// - 지출: 카테고리/내용/금액/메모/**시간만** (날짜는 고정) + 영상 추가/교체/삭제
/// - 무지출: 메모 + 영상 추가/교체/삭제. 일시는 서버 now() 강제라 수정 불가.
///
/// 결과 (pop):
/// - `true`  → 수정 또는 삭제 완료 (호출자는 reload)
/// - `null`  → 취소
class AmountEditScreen extends StatefulWidget {
  const AmountEditScreen({
    super.key,
    required this.challenge,
    required this.original,
  });

  final Challenge challenge;
  final Amount original;

  @override
  State<AmountEditScreen> createState() => _AmountEditScreenState();
}

class _AmountEditScreenState extends State<AmountEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contentController;
  late final TextEditingController _amountController;
  final _amountFocus = FocusNode();
  late final TextEditingController _memoController;

  late TimeOfDay _time;

  /// 우측 "잔액" 표시에 반영되는 확정 금액. 금액 칸 포커스가 빠질 때만 갱신 (실시간 X).
  /// 진입 시 필드가 기존 금액으로 pre-fill 돼 있으므로 그 값으로 초기화한다.
  int? _committedAmount;

  /// 선택된 지출 카테고리 코드 (예: `FOOD`). null = 미선택.
  /// 진입 시 기존 값이 9종 코드면 pre-select, 옛 자유 텍스트면 null(재선택 유도).
  String? _selectedCategoryCode;

  /// 영상 처리 액션. 진입 시 KEEP, 사용자가 손대면 REPLACE/REMOVE 로 전이.
  VideoAction _videoAction = VideoAction.keep;

  /// REPLACE 일 때만 non-null (새로 찍은 로컬 임시 파일).
  String? _newVideoPath;

  /// "영상 보기" 시 서버에서 받아온 로컬 캐시 경로. 한 번 받으면 화면 종료까지 재사용.
  String? _serverVideoLocalPath;
  bool _serverVideoLoading = false;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    // 기존 카테고리가 9종 코드 중 하나면 pre-select, 아니면(옛 자유 텍스트) null 로 두고 재선택 유도.
    _selectedCategoryCode =
        kSpendCategories.any((c) => c.code == o.category) ? o.category : null;
    _contentController = TextEditingController(text: o.content ?? '');
    _amountController = TextEditingController(
      text: o.noSpend ? '' : o.amount.toString(),
    );
    _committedAmount = o.noSpend ? null : o.amount;
    _amountFocus.addListener(_handleAmountFocusChange);
    _memoController = TextEditingController(text: o.memo ?? '');
    _time = TimeOfDay.fromDateTime(o.spentDt);
  }

  void _handleAmountFocusChange() {
    if (!_amountFocus.hasFocus) {
      setState(() => _committedAmount = int.tryParse(_amountController.text));
    }
  }

  @override
  void dispose() {
    _disposeLocalVideo();
    _disposeServerPreview();
    _contentController.dispose();
    _amountController.dispose();
    _amountFocus.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _disposeLocalVideo() {
    final path = _newVideoPath;
    if (path == null) return;
    File(path).delete().catchError((_) => File(path));
    _newVideoPath = null;
  }

  void _disposeServerPreview() {
    final path = _serverVideoLocalPath;
    if (path == null) return;
    File(path).delete().catchError((_) => File(path));
    _serverVideoLocalPath = null;
  }

  Future<void> _loadServerVideo() async {
    if (_serverVideoLocalPath != null || _serverVideoLoading) return;
    final media = widget.original.mediaFiles.isEmpty
        ? null
        : widget.original.mediaFiles.first;
    if (media == null) return;
    final mediaApi = MediaScope.of(context);
    setState(() => _serverVideoLoading = true);
    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}/tenk_edit_preview');
      if (!await dir.exists()) await dir.create(recursive: true);
      // fileId 별 캐시 경로지만, 이전 호출의 잔재(짧은/깨진 파일)가 남아 있으면 truncate 가 늦거나
      // 다른 프로세스가 핸들을 잡고 있을 가능성을 차단하기 위해 항상 선삭제.
      final savePath = '${dir.path}/${media.fileId}.mp4';
      final saveFile = File(savePath);
      if (await saveFile.exists()) {
        try {
          await saveFile.delete();
        } catch (_) {
          // 삭제 실패는 무시 — dio 가 어차피 덮어쓴다. 검증은 사이즈로 한다.
        }
      }
      await mediaApi.downloadToFile(
        fileId: media.fileId,
        savePath: savePath,
      );
      // 0바이트 / 누락 방어 — 둘 다 video_player 초기화 실패로 이어진다. 캐시 안 박고 즉시 에러.
      if (!await saveFile.exists()) {
        throw StateError('다운로드된 파일이 존재하지 않아요 (fileId=${media.fileId})');
      }
      final size = await saveFile.length();
      if (size == 0) {
        throw StateError('다운로드된 파일이 비어 있어요 (fileId=${media.fileId})');
      }
      if (!mounted) return;
      setState(() => _serverVideoLocalPath = savePath);
    } catch (e) {
      if (!mounted) return;
      _showError('영상을 불러오지 못했어요: ${toApiException(e).message}');
    } finally {
      if (mounted) setState(() => _serverVideoLoading = false);
    }
  }

  /// "영상 보기" 진입: KEEP 이면 서버 영상을 lazy 다운로드 후, REPLACE 면 즉시
  /// [AmountVideoPreviewScreen] push. 미리보기에서 돌아온 액션(retake/delete)을 그대로 적용.
  Future<void> _onTapPreview() async {
    String? path;
    switch (_videoAction) {
      case VideoAction.replace:
        path = _newVideoPath;
      case VideoAction.keep:
        if (_serverVideoLocalPath == null) {
          await _loadServerVideo();
          if (!mounted) return;
        }
        path = _serverVideoLocalPath;
      case VideoAction.remove:
        return;
    }
    if (path == null) return;
    final result = await Navigator.of(context).push<VideoPreviewAction>(
      MaterialPageRoute<VideoPreviewAction>(
        builder: (_) => AmountVideoPreviewScreen(videoPath: path!),
      ),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case VideoPreviewAction.retake:
        await _openCamera();
      case VideoPreviewAction.delete:
        _removeVideo();
    }
  }

  bool get _hasExistingServerVideo => widget.original.mediaFiles.isNotEmpty;

  bool get _hasAttachedVideo {
    switch (_videoAction) {
      case VideoAction.keep:
        return _hasExistingServerVideo;
      case VideoAction.replace:
        return _newVideoPath != null;
      case VideoAction.remove:
        return false;
    }
  }

  bool get _videoFromServer => _videoAction == VideoAction.keep && _hasExistingServerVideo;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null) return;
    setState(() => _time = picked);
  }

  Future<void> _openCamera() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const AmountCameraScreen()),
    );
    if (path == null || !mounted) return;
    _disposeLocalVideo();
    setState(() {
      _newVideoPath = path;
      _videoAction = VideoAction.replace;
    });
  }

  void _removeVideo() {
    _disposeLocalVideo();
    setState(() {
      // 기존 서버 영상이 있다면 REMOVE 로 마킹, 없다면 KEEP 로 되돌림 (아무 변경 없음).
      _videoAction = _hasExistingServerVideo ? VideoAction.remove : VideoAction.keep;
    });
  }

  Future<void> _save() async {
    if (!widget.original.noSpend && !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final api = AmountScope.of(context);
      final memo = _memoController.text.trim();
      await api.update(
        challengeId: widget.challenge.id,
        amountId: widget.original.id,
        noSpend: widget.original.noSpend,
        category: widget.original.noSpend ? null : _selectedCategoryCode,
        content: widget.original.noSpend ? null : _contentController.text.trim(),
        amount: widget.original.noSpend ? null : int.parse(_amountController.text),
        memo: memo.isEmpty ? null : memo,
        // 무지출은 백엔드가 time 무시. 지출만 시간 전달.
        hour: widget.original.noSpend ? null : _time.hour,
        minute: widget.original.noSpend ? null : _time.minute,
        videoAction: _videoAction,
        videoPath: _newVideoPath,
      );
      if (!mounted) return;
      _disposeLocalVideo();
      Navigator.of(context).pop<bool>(true);
    } catch (e) {
      if (!mounted) return;
      _showError('수정 실패: ${toApiException(e).message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
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
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await AmountScope.of(context).delete(
        challengeId: widget.challenge.id,
        amountId: widget.original.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop<bool>(true);
    } catch (e) {
      if (!mounted) return;
      _showError('삭제 실패: ${toApiException(e).message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noSpend = widget.original.noSpend;
    final title = noSpend ? '무지출 기록 수정' : '지출 기록 수정';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: AbsorbPointer(
          absorbing: _busy,
          child: Form(
            key: _formKey,
            child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!noSpend) ..._buildDateTimeSection(theme),
              if (!noSpend) ..._buildSpendFields(theme),
              const FieldLabel('한 줄 평', optional: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _memoController,
                maxLength: 500,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: noSpend
                      ? '예) 오늘 잘 참았다'
                      : '예) 회식이라 어쩔 수 없었음',
                ),
              ),
              const SizedBox(height: 24),
              const FieldLabel('영상 (2초)', optional: true),
              const SizedBox(height: 8),
              VideoAttachmentSection(
                hasVideo: _hasAttachedVideo,
                fromServer: _videoFromServer,
                onPickNew: _openCamera,
                onRemove: _removeVideo,
                expandable: true,
                previewLoading: _serverVideoLoading,
                onTapPreview: _onTapPreview,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('저장'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _delete,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('삭제'),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDateTimeSection(ThemeData theme) {
    return [
      const FieldLabel('일시'),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _ReadonlyField(
              icon: Icons.event_busy_outlined,
              text: formatDate(widget.original.spentDt),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _pickTime,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 15),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_outlined,
                          size: 20, color: AppColors.inkMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_time.format(context),
                            style: AppTypo.body),
                      ),
                      const Icon(Icons.expand_more,
                          color: AppColors.inkMuted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildSpendFields(ThemeData theme) {
    return [
      const FieldLabel('카테고리', required: true),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _selectedCategoryCode,
        isExpanded: true,
        decoration: const InputDecoration(
          hintText: '카테고리 선택',
        ),
        items: [
          for (final category in kSpendCategories)
            DropdownMenuItem(
              value: category.code,
              child: Row(
                children: [
                  Icon(category.icon, size: 20),
                  const SizedBox(width: 12),
                  Text(category.label),
                ],
              ),
            ),
        ],
        onChanged: (code) => setState(() => _selectedCategoryCode = code),
        validator: (code) => code == null ? '카테고리를 선택해주세요.' : null,
      ),
      const SizedBox(height: 24),
      const FieldLabel('내용', required: true),
      const SizedBox(height: 8),
      TextFormField(
        controller: _contentController,
        decoration: const InputDecoration(
          hintText: '예) 김밥 한 줄',
        ),
        validator: (raw) =>
            (raw == null || raw.trim().isEmpty) ? '내용을 입력해주세요.' : null,
      ),
      const SizedBox(height: 24),
      const FieldLabel('금액', required: true),
      const SizedBox(height: 8),
      TextFormField(
        controller: _amountController,
        focusNode: _amountFocus,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          suffixText: '원',
        ),
        validator: (raw) {
          final v = int.tryParse(raw ?? '');
          if (v == null || v <= 0) return '1원 이상 숫자를 입력해주세요.';
          return null;
        },
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      // 좌측 에코는 실시간, 우측 잔액은 포커스 확정값(_committedAmount).
      // balance 는 이 기록을 이미 포함하므로 기존금액을 되더한 뒤 확정값을 뺀다.
      BudgetHintRow(
        entered: int.tryParse(_amountController.text),
        remaining: widget.challenge.balance +
            widget.original.amount -
            (_committedAmount ?? 0),
      ),
      const SizedBox(height: 32),
    ];
  }
}

/// 편집 불가 읽기 전용 필드 (지출 날짜). 톤다운된 채움 스타일.
class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypo.body.copyWith(color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
