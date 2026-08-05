import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../data/api/api_error.dart';
import '../../design/tokens.dart';
import '../common/field_label.dart';
import '../common/selection_field.dart';
import '../common/selection_sheet.dart';
import '../legal/support_contact.dart';

/// 문의 유형 코드. 서버 `InquiryType` enum 과 **같은 코드**로 유지할 것
/// (표시 문구는 여기서만 들고, 서버엔 안정적인 코드만 저장한다 — 지출 카테고리·의견 유형과 같은 방식).
///
/// **일부러 굵게 잡은 4종**이다 (국내 고객센터 표준 = 계정/결제/오류/기타 에서, 결제가 없는
/// TenK 은 그 자리를 개인정보가 대신한다). 세분화하면 고르는 시간만 늘고 분류도 부정확해진다.
/// 빈도 순이라 순서를 뒤집지 말 것.
const List<({String code, String label, IconData icon})> _types = [
  (code: 'ACCOUNT', label: '계정·로그인', icon: Icons.person_outline),
  (code: 'SERVICE', label: '서비스 이용', icon: Icons.apps_outlined),
  (code: 'PRIVACY', label: '개인정보', icon: Icons.shield_outlined),
  (code: 'ETC', label: '기타', icon: Icons.more_horiz),
];

/// '고객센터' → '문의하기' 화면.
///
/// **같은 고객센터 안의 '의견 보내기'와는 다른 창구다.** 저쪽은 익명으로 저장되는 제품 의견이고,
/// 이쪽은 **답변이 전제되고 신원이 특정돼야 하는** 요청을 받는다 — 그래서 회신 이메일이 **필수**이고,
/// 계정 정보가 함께 전송된다는 사실을 그 자리에서 밝힌다. 익명인 줄 알고 쓰게 두면 안 된다.
///
/// **둘을 가르는 건 유형이 아니라 "답변을 원하는가" 하나다.** 그래서 오류 문의가 의견의
/// '불편/오류'와 겹쳐 보여도 문제가 아니다 — 답을 원하면 여기, 그냥 알려주는 거면 저기다.
///
/// 앱 밖에서 오는 문의(탈퇴자·로그인 불가·설치 전)는 여기로 들어올 수 없다. 그쪽 창구는 법적 고지
/// 문서에 적힌 이메일이며 **없애면 안 된다** — 전송이 실패했을 때 이 화면이 그 경로를 안내하는 것도
/// 같은 이유다.
class InquiryScreen extends StatefulWidget {
  const InquiryScreen({super.key});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  static const int _contentMaxLength = 1000;

  /// 즉시 피드백용 1차 검증. 진실의 원천은 서버 (INQUIRY_REPLY_EMAIL_INVALID).
  static final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _contentController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();

  String? _type;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 보내기 버튼 활성 조건이 내용·이메일에 걸려 있어 입력마다 다시 그린다.
    _contentController.addListener(_onChanged);
    _emailController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _contentController.dispose();
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// 의견 보내기와 달리 **이메일도 활성 조건**이다 — 답변이 전제된 창구라서.
  bool get _canSubmit =>
      _type != null &&
      _contentController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      !_busy;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (!_emailShape.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일 형식을 확인해주세요.')),
      );
      _emailFocus.requestFocus();
      return;
    }

    final api = InquiryScope.of(context); // await 전에 읽을 것
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await api.submit(
        type: _type!,
        content: _contentController.text,
        replyEmail: email,
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('문의가 접수됐어요. 적어주신 메일로 답변드릴게요.')),
      );
    } catch (e) {
      if (!mounted) return;
      // 전송이 실패해도 창구가 죽으면 안 된다 — 고지한 메일 주소로 빠져나갈 길을 같이 준다.
      messenger.showSnackBar(
        SnackBar(
          content: Text('전송 실패: ${toApiException(e).message}'),
          action: SnackBarAction(
            label: '메일로 보내기',
            onPressed: () => openSupportEmail(context),
          ),
        ),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문의하기')),
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
            // ⚠️ "궁금하신가요?" 로 되돌리지 말 것 — 이 창구에 오는 사람은 대부분 **문제가 생겨서**
            // 오지 궁금해서 오지 않는다. 고객센터의 표준 오프닝인 "무엇을 도와드릴까요?" 가
            // 문제·요청·질문을 모두 담으면서도 돕겠다는 태도를 먼저 밝힌다.
            const Text('무엇을 도와드릴까요?', style: AppTypo.title),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '불편하셨던 점이나 도움이 필요한 내용을 남겨주세요. '
              '확인 후 적어주신 메일로 답변드릴게요.',
              style: AppTypo.body,
            ),
            const SizedBox(height: AppSpacing.xl),

            // 폐쇄형(유형) 먼저, 자유 서술은 그다음 — 의견 보내기와 같은 순서.
            const FieldLabel('어떤 문의인가요?', required: true),
            const SizedBox(height: AppSpacing.md),
            SelectionField<String>(
              value: _type,
              options: [
                for (final type in _types)
                  SelectionOption(
                    value: type.code,
                    label: type.label,
                    icon: type.icon,
                  ),
              ],
              icon: Icons.forum_outlined,
              hintText: '유형 선택',
              sheetTitle: '어떤 문의인가요?',
              enabled: !_busy,
              // 미선택 검증은 validator 대신 '보내기' 비활성으로 한다 (이 화면엔 Form 이 없다).
              onChanged: (code) => setState(() => _type = code),
            ),
            const SizedBox(height: AppSpacing.xl),

            const FieldLabel('내용', required: true),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _contentController,
              enabled: !_busy,
              maxLength: _contentMaxLength,
              maxLines: 6,
              // 여러 줄 입력이라 액션 키는 줄바꿈이다 (서버도 줄바꿈만 허용한다).
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: '내용이 구체적일수록 정확하고 빠른 답변이 가능해요.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            const FieldLabel('답변받을 이메일', required: true),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _emailController,
              focusNode: _emailFocus,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              // 마지막 칸이라 '완료' + 곧바로 제출.
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (_canSubmit) _submit();
              },
              decoration: const InputDecoration(hintText: 'name@example.com'),
            ),
            // 하단 안내 2줄(계정 정보 전송 / 보관 기간)은 **사용자 결정으로 삭제**했다
            // (2026-08-06). 수집·보관 사실은 privacy.html §1·§3 이 고지한다 — 되살릴 땐
            // 화면을 설명서로 만들지 않는 쪽을 택했다는 걸 알고 되살릴 것.
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
              onPressed: _canSubmit ? _submit : null,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('문의하기'),
            ),
          ),
        ),
      ),
    );
  }
}
