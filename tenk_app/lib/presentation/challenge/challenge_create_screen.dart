import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/scopes.dart';
import '../../data/api/api_error.dart';
import '../../data/challenge/challenge.dart';
import '../../design/tokens.dart';
import '../common/field_label.dart';
import '_formatters.dart';

class ChallengeCreateScreen extends StatefulWidget {
  const ChallengeCreateScreen({super.key, required this.defaultName});

  /// 이름 칸에 미리 채워 둘 기본값 (예: "챌린지 3"). 비울 수 없으므로 사용자는
  /// 이 값을 그대로 쓰거나 수정한다. 산정은 호출부(목록 화면)가 담당.
  final String defaultName;

  @override
  State<ChallengeCreateScreen> createState() => _ChallengeCreateScreenState();
}

class _ChallengeCreateScreenState extends State<ChallengeCreateScreen> {
  /// 양끝 포함 최대 윈도우 — 백엔드 `Challenge.MAX_DURATION_DAYS = 30`과 일치시킬 것.
  static const _maxDurationDays = 30;

  /// 제어 문자(\p{Cc}) + 형식 문자(\p{Cf}) 거부 — 서버 검증과 동일. 진실의 원천은 서버.
  static final _forbiddenChars = RegExp(r'[\p{Cc}\p{Cf}]', unicode: true);

  late DateTime _startDate;
  late DateTime _endDate;
  late final _nameController = TextEditingController(text: widget.defaultName);
  final _amountController = TextEditingController(text: '10000');
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _startDate = _today();
    _endDate = _startDate.add(const Duration(days: 2));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// 시작·종료일 모두 포함한 총 일수.
  int get _totalDays => _endDate.difference(_startDate).inDays + 1;

  Future<void> _pickStart() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isBefore(today) ? today : _startDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      final maxEnd = _startDate.add(const Duration(days: _maxDurationDays - 1));
      if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      if (_endDate.isAfter(maxEnd)) _endDate = maxEnd;
    });
  }

  Future<void> _pickEnd() async {
    final maxEnd = _startDate.add(const Duration(days: _maxDurationDays - 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: maxEnd,
    );
    if (picked == null) return;
    setState(() {
      _endDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = int.parse(_amountController.text);
    setState(() => _submitting = true);
    try {
      // 백엔드는 startDate/endDate를 양끝 포함 날짜로 받는다. 별도 보정 없이 그대로 전달.
      final created = await ChallengeScope.of(context).create(
        name: _nameController.text,
        startDate: _startDate,
        endDate: _endDate,
        targetAmount: amount,
      );
      if (!mounted) return;
      Navigator.of(context).pop<Challenge>(created);
    } catch (e) {
      if (!mounted) return;
      final msg = toApiException(e).message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('생성 실패: $msg')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('새 챌린지')),
      body: SafeArea(
        top: false,
        child: AbsorbPointer(
          absorbing: _submitting,
          child: Form(
            key: _formKey,
            child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const FieldLabel('이름', required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                maxLength: 100,
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: 24),
              const FieldLabel('기간', required: true),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: '시작일',
                      date: _startDate,
                      onTap: _pickStart,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: '종료일',
                      date: _endDate,
                      onTap: _pickEnd,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '총 $_totalDays일 (최대 $_maxDurationDays일)',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 32),
              const FieldLabel('목표 금액', required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
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
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (_) {
                  final parsed = int.tryParse(_amountController.text);
                  if (parsed == null) return const SizedBox.shrink();
                  return Text(
                    formatWon(parsed),
                    style: theme.textTheme.bodySmall,
                  );
                },
              ),
              const SizedBox(height: 48),
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
                    : const Text('챌린지 시작'),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypo.caption),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: Text(formatDate(date), style: AppTypo.body)),
                  const Icon(Icons.event_outlined,
                      size: 18, color: AppColors.inkMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
