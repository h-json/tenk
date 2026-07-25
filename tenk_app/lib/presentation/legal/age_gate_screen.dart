import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/scopes.dart';
import '../../data/api/api_error.dart';
import '../../design/tokens.dart';
import '../challenge/challenge_list_screen.dart';
import '../login/login_screen.dart';

/// 연령 확인 화면. 생년월일을 입력해야 [next] 로 진입할 수 있고, 거부하면 로그아웃만 가능하다(back/swipe 차단).
///
/// **중립적 연령 심사(neutral age screen)** — Google Play 타겟층에 13~15세가 포함돼 가족 정책 대상이
/// 되면서 필요해졌다. 중립성을 위해 지키는 것:
/// - 이용 가능 최소 연령(만 14세)을 **입력 전에 알려주지 않는다**. 컷오프를 먼저 보여주면 사용자가
///   통과하는 값을 역산해 입력하도록 유도하는 셈이 된다.
/// - 기본값·초기 선택값을 두지 않는다 (DatePicker 대신 빈 입력칸 3개를 쓰는 이유).
///
/// 판정은 서버가 한다 ([UserApi.verifyAge]). 만 14세 미만이면 계정이 즉시 파기되고 `U0006` 이 오며,
/// 이 화면은 안내 후 로그인 화면으로 돌려보낸다.
class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({super.key, this.next = const ChallengeListScreen()});

  /// 확인 완료 후 이동할 화면. 신규 가입은 동의 화면, 기존 미확인자는 홈(기본값).
  final Widget next;

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  final _year = TextEditingController();
  final _month = TextEditingController();
  final _day = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _year.dispose();
    _month.dispose();
    _day.dispose();
    super.dispose();
  }

  /// 입력 3칸을 실제 달력상 존재하는 날짜로만 통과시킨다 (2월 30일 등은 거부).
  DateTime? _parseBirthDate() {
    final y = int.tryParse(_year.text.trim());
    final m = int.tryParse(_month.text.trim());
    final d = int.tryParse(_day.text.trim());
    if (y == null || m == null || d == null) return null;
    if (y < 1900 || m < 1 || m > 12 || d < 1 || d > 31) return null;
    final parsed = DateTime(y, m, d);
    if (parsed.year != y || parsed.month != m || parsed.day != d) return null;
    if (parsed.isAfter(DateTime.now())) return null;
    return parsed;
  }

  Future<void> _submit() async {
    if (_saving) return;
    final birthDate = _parseBirthDate();
    if (birthDate == null) {
      setState(() => _error = '생년월일을 정확히 입력해주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await UserScope.of(context).verifyAge(birthDate);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => widget.next),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final error = toApiException(e);
      if (error.code == 'U0006') {
        await _showBlockedAndLogout(error.message);
        return;
      }
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  /// 만 14세 미만 — 서버가 계정을 이미 파기했다. 안내 후 로그인 화면으로 되돌린다.
  Future<void> _showBlockedAndLogout(String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('서비스를 이용할 수 없어요'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await _logout();
  }

  Future<void> _logout() async {
    await AuthScope.of(context).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // back/swipe 차단 — 확인 또는 로그아웃으로만 벗어날 수 있다.
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('연령 확인'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          '생년월일을\n알려주세요.',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '서비스 이용 가능 연령을 확인하기 위해 필요해요.',
                          style: AppTypo.body.copyWith(color: AppColors.inkSub),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: _BirthField(
                                controller: _year,
                                label: '년',
                                maxLength: 4,
                                enabled: !_saving,
                                onChanged: _clearError,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: _BirthField(
                                controller: _month,
                                label: '월',
                                maxLength: 2,
                                enabled: !_saving,
                                onChanged: _clearError,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: _BirthField(
                                controller: _day,
                                label: '일',
                                maxLength: 2,
                                enabled: !_saving,
                                onChanged: _clearError,
                                onSubmitted: (_) => _submit(),
                              ),
                            ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: AppTypo.caption.copyWith(color: AppColors.danger),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          '입력한 생년월일은 연령 확인 목적으로만 보관돼요.',
                          style: AppTypo.caption.copyWith(color: AppColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            '확인',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _saving ? null : _logout,
                  style: TextButton.styleFrom(foregroundColor: AppColors.inkMuted),
                  child: const Text('로그아웃'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }
}

/// 생년월일 입력 한 칸. 기본값 없이 비워둔 채로 시작한다 (중립 심사).
class _BirthField extends StatelessWidget {
  const _BirthField({
    required this.controller,
    required this.label,
    required this.maxLength,
    required this.enabled,
    required this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final int maxLength;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      textAlign: TextAlign.center,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
