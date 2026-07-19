import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../data/api/api_error.dart';
import '../../design/tokens.dart';
import '../challenge/challenge_list_screen.dart';
import '../login/login_screen.dart';
import 'consent_section.dart';

/// 필수 동의 화면. 동의해야 [next] 로 진입할 수 있고, 거부하면 로그아웃만 가능하다(back/swipe 차단).
///
/// 두 진입 흐름에서 재사용한다:
/// - **신규 가입**: 동의 → [next] = 닉네임 설정 화면. (동의와 닉네임 설정은 별도 화면으로 분리)
/// - **기존 미동의자**(동의 기능 도입 전 가입자, 동의 화면 이탈자): 동의 → [next] = 홈(기본값).
class ConsentGateScreen extends StatefulWidget {
  const ConsentGateScreen({super.key, this.next = const ChallengeListScreen()});

  /// 동의 완료 후 이동할 화면. 신규 가입은 닉네임 설정 화면, 기존 미동의자는 홈.
  final Widget next;

  @override
  State<ConsentGateScreen> createState() => _ConsentGateScreenState();
}

class _ConsentGateScreenState extends State<ConsentGateScreen> {
  bool _consentOk = false;
  bool _saving = false;

  Future<void> _agree() async {
    if (!_consentOk || _saving) return;
    setState(() => _saving = true);
    try {
      await UserScope.of(context).agreeConsents();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => widget.next),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(toApiException(e).message)));
      setState(() => _saving = false);
    }
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
    // back/swipe 차단 — 동의 또는 로그아웃으로만 벗어날 수 있다.
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('약관 동의'),
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
                          '서비스 이용을 위해\n약관 동의가 필요해요.',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '아래 필수 항목에 동의하면 Tenk 를 시작할 수 있어요.',
                          style: AppTypo.body.copyWith(color: AppColors.inkSub),
                        ),
                        const SizedBox(height: 24),
                        ConsentSection(
                          onChanged: (ok) => setState(() => _consentOk = ok),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_consentOk && !_saving) ? _agree : null,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            '동의하고 시작하기',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _saving ? null : _logout,
                  style: TextButton.styleFrom(foregroundColor: AppColors.inkMuted),
                  child: const Text('동의하지 않고 로그아웃'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
