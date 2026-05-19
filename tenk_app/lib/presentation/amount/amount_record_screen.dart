import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/scopes.dart';
import '../../data/api/api_error.dart';
import '../../data/challenge/challenge.dart';
import '../challenge/_formatters.dart';

/// 지출/무지출 기록 + 영상 녹화 화면.
///
/// `noSpend = false`: 카테고리/내용/금액 + 영상 녹화 (필수)
/// `noSpend = true` : 영상 녹화 (선택)
///
/// 일시는 [challenge.startDate, challenge.endDate] 범위 **날짜** 안에서만 고를 수 있다.
/// 기본값 = 지금 (날짜가 챌린지 기간 밖이면 가장 가까운 챌린지 날짜로 clamp).
/// 영상 사양: [ResolutionPreset.low] + 2초 타이머. 후처리 트랜스코딩 없음
/// (CLAUDE.md "영상" 정책 참고).
class AmountRecordScreen extends StatefulWidget {
  const AmountRecordScreen({
    super.key,
    required this.challenge,
    required this.noSpend,
  });

  final Challenge challenge;
  final bool noSpend;

  @override
  State<AmountRecordScreen> createState() => _AmountRecordScreenState();
}

class _AmountRecordScreenState extends State<AmountRecordScreen> {
  static const _recordDuration = Duration(seconds: 2);

  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  final _contentController = TextEditingController();
  final _amountController = TextEditingController();

  late DateTime _spentDt;
  CameraController? _camera;
  Object? _cameraError;
  bool _initializing = true;
  bool _recording = false;
  Timer? _stopTimer;
  String? _videoPath;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _spentDt = _defaultSpentDt();
    _initCamera();
  }

  /// 기본값: 지금. 날짜 부분이 챌린지 기간 밖이면 가장 가까운 챌린지 날짜로 옮기고 시각은 유지.
  DateTime _defaultSpentDt() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (today.isBefore(widget.challenge.startDate)) {
      return _combine(widget.challenge.startDate, TimeOfDay.fromDateTime(now));
    }
    if (today.isAfter(widget.challenge.endDate)) {
      return _combine(widget.challenge.endDate, TimeOfDay.fromDateTime(now));
    }
    return now;
  }

  static DateTime _combine(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _camera?.dispose();
    _categoryController.dispose();
    _contentController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', '사용 가능한 카메라를 찾지 못했어요.');
      }
      // 음성은 필요 없음 → enableAudio=false. RECORD_AUDIO 권한 안 떠도 통과되도록.
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = e;
        _initializing = false;
      });
    }
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _spentDt,
      firstDate: widget.challenge.startDate,
      lastDate: widget.challenge.endDate,
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_spentDt),
    );
    if (pickedTime == null) return;
    setState(() {
      _spentDt = _combine(pickedDate, pickedTime);
    });
  }

  Future<void> _startRecording() async {
    final camera = _camera;
    if (camera == null || _recording) return;
    setState(() {
      _recording = true;
      _videoPath = null;
    });
    try {
      await camera.startVideoRecording();
      _stopTimer = Timer(_recordDuration, _stopRecording);
    } catch (e) {
      if (!mounted) return;
      setState(() => _recording = false);
      _showError('녹화 시작 실패: ${toApiException(e).message}');
    }
  }

  Future<void> _stopRecording() async {
    final camera = _camera;
    if (camera == null || !_recording) return;
    _stopTimer?.cancel();
    _stopTimer = null;
    try {
      final file = await camera.stopVideoRecording();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _videoPath = file.path;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _recording = false);
      _showError('녹화 정지 실패: ${toApiException(e).message}');
    }
  }

  void _discardRecording() {
    final path = _videoPath;
    if (path != null) {
      // 임시 디렉토리에 저장된 파일 — 정리 실패는 무시.
      File(path).delete().catchError((_) => File(path));
    }
    setState(() => _videoPath = null);
  }

  Future<void> _submit() async {
    if (!widget.noSpend && !(_formKey.currentState?.validate() ?? false)) return;
    if (!widget.noSpend && _videoPath == null) {
      _showError('지출 기록은 영상이 필수예요.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final api = AmountScope.of(context);
      await api.record(
        challengeId: widget.challenge.id,
        noSpend: widget.noSpend,
        dateTime: _spentDt,
        category: widget.noSpend ? null : _categoryController.text.trim(),
        content: widget.noSpend ? null : _contentController.text.trim(),
        amount: widget.noSpend ? null : int.parse(_amountController.text),
        videoPath: _videoPath,
      );
      if (!mounted) return;
      Navigator.of(context).pop<bool>(true);
    } catch (e) {
      if (!mounted) return;
      _showError('저장 실패: ${toApiException(e).message}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.noSpend ? '무지출 기록' : '지출 기록';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AbsorbPointer(
        absorbing: _submitting,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('일시', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _DateTimeField(
                label: '기록 일시',
                dt: _spentDt,
                onTap: _pickDateTime,
              ),
              const SizedBox(height: 4),
              Text(
                '챌린지 기간: ${formatPeriod(widget.challenge.startDate, widget.challenge.endDate)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              if (!widget.noSpend) ..._buildSpendFields(theme),
              Text(
                widget.noSpend ? '영상 (선택)' : '영상 (필수, 2초)',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _CameraSection(
                initializing: _initializing,
                error: _cameraError,
                controller: _camera,
                recording: _recording,
                recordedPath: _videoPath,
                onRecord: _startRecording,
                onReRecord: _discardRecording,
                onRetry: () {
                  setState(() {
                    _initializing = true;
                    _cameraError = null;
                  });
                  _initCamera();
                },
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('저장'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSpendFields(ThemeData theme) {
    return [
      Text('카테고리', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      TextFormField(
        controller: _categoryController,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: '예) 식비, 교통, 카페',
        ),
        validator: (raw) =>
            (raw == null || raw.trim().isEmpty) ? '카테고리를 입력해주세요.' : null,
      ),
      const SizedBox(height: 24),
      Text('내용', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      TextFormField(
        controller: _contentController,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: '예) 김밥 한 줄',
        ),
        validator: (raw) =>
            (raw == null || raw.trim().isEmpty) ? '내용을 입력해주세요.' : null,
      ),
      const SizedBox(height: 24),
      Text('금액', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      TextFormField(
        controller: _amountController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
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
      Builder(
        builder: (_) {
          final parsed = int.tryParse(_amountController.text);
          if (parsed == null) return const SizedBox.shrink();
          return Text(formatWon(parsed), style: theme.textTheme.bodySmall);
        },
      ),
      const SizedBox(height: 32),
    ];
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.dt,
    required this.onTap,
  });

  final String label;
  final DateTime dt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(formatDateTime(dt)),
      ),
    );
  }
}

/// 카메라 상태(초기화 중 / 에러 / 대기 / 녹화 중 / 녹화 완료) UI.
class _CameraSection extends StatelessWidget {
  const _CameraSection({
    required this.initializing,
    required this.error,
    required this.controller,
    required this.recording,
    required this.recordedPath,
    required this.onRecord,
    required this.onReRecord,
    required this.onRetry,
  });

  final bool initializing;
  final Object? error;
  final CameraController? controller;
  final bool recording;
  final String? recordedPath;
  final VoidCallback onRecord;
  final VoidCallback onReRecord;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    if (initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null || controller == null) {
      final msg = error == null
          ? '카메라를 사용할 수 없어요.'
          : '카메라 초기화 실패: ${toApiException(error!).message}';
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (recordedPath != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle,
              size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          const Text('2초 영상 녹화 완료'),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onReRecord,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 녹화'),
          ),
        ],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller!),
        if (recording)
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Center(
            child: FilledButton.icon(
              onPressed: recording ? null : onRecord,
              icon: Icon(recording ? Icons.fiber_manual_record : Icons.videocam),
              label: Text(recording ? '녹화 중…' : '2초 녹화'),
            ),
          ),
        ),
      ],
    );
  }
}
