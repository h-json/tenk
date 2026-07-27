import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/scopes.dart';
import '../../config/legal_config.dart';
import '../../data/api/api_error.dart';
import '../../data/auth/auth_repository.dart';
import '../../design/tokens.dart';
import '../challenge/challenge_list_screen.dart';
import '../legal/age_gate_screen.dart';
import '../legal/consent_gate_screen.dart';
import '../legal/consent_section.dart';
import '../profile/nickname_setup_screen.dart';

/// 다이얼로그 액션 3개를 한 줄에 넣기 위한 축소 스타일.
/// 테마 기본값(15px w800 + 좌우 패딩 20)으로는 폭이 모자라 Material 이 버튼을 세로로 접는다.
ButtonStyle _dialogActionStyle(ButtonStyle? base) {
  const compact = ButtonStyle(
    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 6)),
    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
    minimumSize: WidgetStatePropertyAll(Size(0, 48)),
  );
  return base?.merge(compact) ?? compact;
}

/// 탈퇴 유예 기간 중 돌아온 사용자의 선택. 둘 다 같은 카카오 티켓으로 이어진다.
enum _WithdrawnChoice {
  /// 탈퇴 철회 — 이전 챌린지·기록을 그대로 이어서 쓴다.
  restore,

  /// 재가입 — 옛 계정을 파기하고 새로 시작한다 (되돌릴 수 없음).
  rejoin,
}

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
      _enterApp(outcome);
    } on WithdrawnAccountException catch (e) {
      if (!mounted) return;
      await _offerWithdrawnChoice(e);
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

  /// 로그인·철회 성공 후 진입. 게이트를 안쪽부터 감싼다:
  /// [연령 확인] → [약관 동의] → (신규만) 닉네임 설정 → 홈.
  /// 연령·동의·닉네임은 각각 별도 화면 — 하나에 몰아넣지 말 것.
  void _enterApp(LoginOutcome outcome) {
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
  }

  /// 탈퇴한 계정으로 로그인한 경우. 유예 기간이 남아 있어 계정이 아직 살아 있으므로 그냥 막지 않고
  /// **무엇을 원하는지 사용자에게 묻는다** — 기록을 되찾으러 온 사람과 리셋하러 온 사람이 갈리기 때문.
  /// 어느 쪽도 안 고르면 남겨뒀던 카카오 세션을 정리하고 로그인 화면에 머문다.
  Future<void> _offerWithdrawnChoice(WithdrawnAccountException e) async {
    final auth = AuthScope.of(context);
    final choice = await showDialog<_WithdrawnChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        // 제목/내용 구분 없이 한 문단. "이어서 쓰기" 가 곧 탈퇴 철회라는 것과, "새로 시작" 이 이전
        // 데이터를 지운다는 것을 문장 안에서 밝힌다 — 버튼 라벨만으로는 탈퇴한 사람이 오해한다.
        content: const Text(
          '탈퇴한 계정이에요. 탈퇴를 철회하면 이전 챌린지와 기록을 그대로 이어서 쓸 수 있고, '
          '새로 시작하면 이전 기록을 모두 삭제한 뒤 처음부터 시작해요.',
          style: AppTypo.body,
        ),
        // 버튼 3개를 한 줄로. 기본 스타일(15px w800 + 좌우 20 패딩)로는 좁은 기기에서 폭이 모자라
        // Material 이 세로로 접으므로, Expanded 로 폭을 2:3:3 으로 나누고 라벨·패딩을 줄여 고정한다.
        actions: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextButton(
                  style: _dialogActionStyle(TextButton.styleFrom(
                    foregroundColor: AppColors.inkSub,
                  )),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 3,
                // 되돌릴 수 없는 삭제라 danger 색으로 표시한다 (2차 확인은 두지 않는 대신).
                child: OutlinedButton(
                  style: _dialogActionStyle(OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  )),
                  onPressed: () => Navigator.of(ctx).pop(_WithdrawnChoice.rejoin),
                  child: const Text('새로 시작'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 3,
                child: FilledButton(
                  style: _dialogActionStyle(null),
                  onPressed: () => Navigator.of(ctx).pop(_WithdrawnChoice.restore),
                  child: const Text('탈퇴 철회'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (!mounted) return;

    switch (choice) {
      case null:
        await auth.abandonRestore();
      case _WithdrawnChoice.restore:
        await _finishReturn(
          () => auth.restoreWithdrawnAccount(e.restoreTicket),
          failureLabel: '탈퇴 철회 실패',
        );
      case _WithdrawnChoice.rejoin:
        // 2차 확인은 두지 않는다 — 본문이 "이전 기록을 모두 삭제한 뒤" 라고 이미 말하고 있고,
        // 같은 다이얼로그에 취소 버튼이 있어 오탭을 되돌릴 자리가 이미 한 번 있다.
        await _finishReturn(
          () => auth.rejoinAfterWithdrawal(e.restoreTicket),
          failureLabel: '재가입 실패',
        );
    }
  }

  Future<void> _finishReturn(
    Future<LoginOutcome> Function() action, {
    required String failureLabel,
  }) async {
    try {
      final outcome = await action();
      if (!mounted) return;
      _enterApp(outcome);
    } catch (error) {
      if (!mounted) return;
      _showError('$failureLabel: ${toApiException(error).message}');
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
