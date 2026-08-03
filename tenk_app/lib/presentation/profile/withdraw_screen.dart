import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../data/api/api_error.dart';
import '../../design/tokens.dart';
import '../login/login_screen.dart';

/// 탈퇴 사유 코드. 서버 [WithdrawalReason] enum 과 **같은 코드**로 유지할 것
/// (표시 문구는 여기서만 들고, 서버엔 안정적인 코드만 저장한다 — 지출 카테고리와 같은 방식).
///
/// 라벨은 **해요체 문장으로 어미까지 통일**한다. 명사형("이용 불편")과 문장형이 섞이면 훑어보기가
/// 어려워지고, 실제로 그렇게 만든 국내 앱들이 지적받았다. 마지막 '기타' 만 관례대로 명사.
/// 선택지가 많을수록 고르는 데 걸리는 시간이 늘어난다 — 늘리려면 대신 뺄 것을 같이 정할 것.
const List<({String code, String label})> _reasons = [
  (code: 'INCONVENIENT', label: '사용하기 불편해요'),
  (code: 'MISSING_FEATURE', label: '원하는 기능이 없어요'),
  (code: 'LOST_INTEREST', label: '흥미가 떨어졌어요'),
  (code: 'GOAL_ACHIEVED', label: '목표를 이뤘어요'),
  (code: 'USING_OTHER_APP', label: '다른 앱을 쓰고 있어요'),
  (code: 'BUGS', label: '오류가 자주 생겨요'),
  (code: 'ETC', label: '기타'),
];

const String _etcCode = 'ETC';

/// 탈퇴 사유 화면. **확인 다이얼로그에서 탈퇴 의사를 이미 확정한 뒤** 열리고, 여기서 탈퇴가 끝난다.
///
/// 순서가 이런 이유 — 아직 마음을 못 정한 사람에게 설문부터 들이밀면 설문이 만류 장치처럼 읽히고,
/// 답도 부정확해진다. 결정을 먼저 받고 "떠나는 김에 한 가지만" 을 묻는 쪽이 응답도 솔직하다.
///
/// 사유는 **선택**이다 — 아무것도 안 고르고 '탈퇴하기' 를 누르는 게 곧 건너뛰기라서 별도의
/// '건너뛰기' 버튼을 두지 않는다(버튼을 하나 더 두면 무엇을 눌러야 넘어가는지가 되레 헷갈린다).
/// 같은 이유로 **'계속 이용하기' 같은 만류 버튼을 나란히 두지 말 것** — 두 버튼이 경쟁하면
/// 사용자가 어느 쪽이 진행인지 헷갈린다(국내 앱들의 대표적 실패 사례). 되돌리려면 뒤로 가면 된다.
/// **사유를 필수로 만들지도 말 것** — 탈퇴가 가입보다 어려워지면 안 된다.
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  String? _reason;
  final _detailController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _withdraw() async {
    final user = UserScope.of(context);
    final auth = AuthScope.of(context);
    setState(() => _busy = true);
    try {
      await user.withdraw(
        reason: _reason,
        detail: _reason == _etcCode ? _detailController.text : null,
      );
      // withdraw 직후 storage 의 토큰은 더 이상 유효하지 않음. logout() 의 storage.clear() 만 활용.
      await auth.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('탈퇴 실패: ${toApiException(e).message}')),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원 탈퇴')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            // 국내 앱 7종의 탈퇴 화면을 조사해 뽑은 구성: [감사] → [사유 요청 + 개선 약속] → [문장형 선택지].
            // 이미 탈퇴를 확정한 사람이라 경고는 반복하지 않는다.
            //
            // 마지막 문장("답하지 않으셔도 괜찮아요")이 선택임을 알리는 장치다 — 라벨의 (선택)
            // 표기나 별도 건너뛰기 버튼 대신 이 한 문장으로 처리한다. **지우지 말 것.**
            const Text('그동안 TenK를 이용해주셔서 감사드려요.', style: AppTypo.title),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '떠나시는 이유를 알려주시면 더 좋은 서비스로 보답할게요. 답하지 않으셔도 괜찮아요.',
              style: AppTypo.body,
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final reason in _reasons)
                  ChoiceChip(
                    label: Text(reason.label),
                    selected: _reason == reason.code,
                    // 다시 누르면 선택 해제 — 잘못 골랐을 때 되돌릴 자리가 있어야 한다
                    onSelected: _busy
                        ? null
                        : (selected) => setState(() => _reason = selected ? reason.code : null),
                  ),
              ],
            ),
            if (_reason == _etcCode) ...[
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _detailController,
                enabled: !_busy,
                maxLength: 200,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(hintText: '자유롭게 남겨주세요'),
              ),
            ],
          ],
        ),
      ),
      // ⚠️ Scaffold 는 이 슬롯에 시스템 내비 inset 을 넣어주지 않는다 — SafeArea 를 빼면
      // 제스처 바에 버튼이 잘린다 (CLAUDE.md "코딩 컨벤션 — Flutter").
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: _busy ? null : _withdraw,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  // 이 버튼이 실제 탈퇴다. 확인은 이미 앞 다이얼로그에서 받았으므로 여기서 또 묻지 않는다.
                  : const Text('탈퇴하기'),
            ),
          ),
        ),
      ),
    );
  }
}
