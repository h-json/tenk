import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/scopes.dart';
import '../../config/legal_config.dart';
import '../../data/api/api_error.dart';
import '../../design/tokens.dart';
import '../challenge/challenge_list_screen.dart';
import '../legal/age_gate_screen.dart';
import '../legal/consent_gate_screen.dart';
import '../legal/consent_section.dart';
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
      final outcome = await AuthScope.of(context).loginWithKakao();
      if (!mounted) return;
      // 게이트를 안쪽부터 감싼다: [연령 확인] → [약관 동의] → (신규만) 닉네임 설정 → 홈.
      // 연령·동의·닉네임은 각각 별도 화면 — 하나에 몰아넣지 말 것.
      Widget destination =
          outcome.isNewUser ? const NicknameSetupScreen() : const ChallengeListScreen();
      if (outcome.consentRequired) {
        destination = ConsentGateScreen(next: destination);
      }
      if (outcome.ageVerificationRequired) {
        destination = AgeGateScreen(next: destination);
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => destination),
        (_) => false,
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') return; // 사용자 취소는 조용히 무시
      if (!mounted) return;
      _showError('카카오 로그인 실패: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      // dio 예외 원문을 그대로 띄우면 화면이 영문 스택으로 덮인다. 서버가 내려준 한국어 메시지를 쓸 것.
      _showError('로그인 실패: ${toApiException(e).message}');
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
        child: Column(
          children: [
            Expanded(
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
              ],
                  ),
                ),
              ),
            ),
            const _LegalFooter(),
          ],
        ),
      ),
    );
  }
}

/// 로그인 화면 하단의 법적 고지 링크. 로그인(=가입) 전에 문서를 확인할 수 있게 노출한다.
class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: AppColors.inkMuted,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 13),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: () => openLegalDoc(context, termsUrl),
            style: style,
            child: const Text('이용약관'),
          ),
          const Text('·', style: TextStyle(color: AppColors.inkMuted)),
          TextButton(
            onPressed: () => openLegalDoc(context, privacyPolicyUrl),
            style: style,
            child: const Text('개인정보처리방침'),
          ),
        ],
      ),
    );
  }
}
