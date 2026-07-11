import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/scopes.dart';
import '../../config/test_config.dart';
import '../../data/api/api_error.dart';
import '../challenge/challenge_list_screen.dart';
import '../profile/nickname_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final isNewUser = await AuthScope.of(context).loginWithKakao();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) =>
              isNewUser ? const NicknameSetupScreen() : const ChallengeListScreen(),
        ),
        (_) => false,
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') return; // 사용자 취소는 조용히 무시
      if (!mounted) return;
      _showError('카카오 로그인 실패: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      _showError('로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _testLogin() async {
    final slot = await showDialog<String>(
      context: context,
      builder: (_) => const _TestSlotDialog(),
    );
    if (!mounted || slot == null) return;
    setState(() => _loading = true);
    try {
      await AuthScope.of(context).loginAsTest(slot);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const ChallengeListScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showError('테스트 로그인 실패: ${toApiException(e).message}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Tenk',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '만원 챌린지',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 64),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE500),
                      foregroundColor: const Color(0xDD000000),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            '카카오로 로그인',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                if (testToolsEnabled) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _loading ? null : _testLogin,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '테스트 로그인',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
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

/// 테스트 로그인 시 테스터 식별자(슬롯)를 입력받는 다이얼로그. 슬롯별로 격리된 테스트 계정이 된다.
class _TestSlotDialog extends StatefulWidget {
  const _TestSlotDialog();

  @override
  State<_TestSlotDialog> createState() => _TestSlotDialogState();
}

class _TestSlotDialogState extends State<_TestSlotDialog> {
  // 백엔드 TEST_SLOT 패턴과 동일 — 한글·영문·숫자·-·_ 1~20자.
  static final RegExp _slotPattern = RegExp(r'^[a-zA-Z0-9가-힣_-]{1,20}$');
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final slot = _controller.text.trim();
    if (!_slotPattern.hasMatch(slot)) {
      setState(() => _error = '한글·영문·숫자·-·_ 1~20자로 입력해주세요.');
      return;
    }
    Navigator.of(context).pop(slot);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('테스트 로그인'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 20,
            decoration: InputDecoration(
              labelText: '테스터 이름',
              hintText: '예: alice',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 4),
          const Text(
            '이름별로 데이터가 분리된 테스트 계정이 만들어져요.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(onPressed: _submit, child: const Text('로그인')),
      ],
    );
  }
}
