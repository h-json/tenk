import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../data/api/api_error.dart';
import '../../design/tokens.dart';
import '../common/field_label.dart';

/// 의견 유형 코드. 서버 `FeedbackType` enum 과 **같은 코드**로 유지할 것
/// (표시 문구는 여기서만 들고, 서버엔 안정적인 코드만 저장한다 — 지출 카테고리·탈퇴 사유와 같은 방식).
///
/// 아이콘은 색이 박히지 않은 Material 벡터라 렌더 시점에 테마 색으로 칠해진다 (지출 카테고리와 동일).
const List<({String code, String label, IconData icon})> _types = [
  (code: 'PROBLEM', label: '불편하거나 오류가 있어요', icon: Icons.report_problem_outlined),
  (code: 'SUGGESTION', label: '이런 기능이 있으면 좋겠어요', icon: Icons.lightbulb_outline),
  (code: 'PRAISE', label: '좋았던 점을 알려드릴게요', icon: Icons.favorite_outline),
  (code: 'ETC', label: '기타', icon: Icons.more_horiz),
];

/// 의견 보내기 화면. 메뉴에서 진입하며, 보낸 의견은 **계정과 연결되지 않고** 저장된다.
///
/// **이 화면은 고객센터가 아니다.** 국내 앱들이 '문의'와 '피드백'을 따로 두는 건 CS 팀과 제품 팀이
/// 서로 다른 큐를 보기 때문인데, TenK 은 받는 사람이 한 명이라 하나로 합쳤다. 대신 **회신용 이메일을
/// 적었는지가 "답변이 필요한가"를 가르는 유일한 스위치**다 — 유형으로 판정하지 말 것. 같은 '불편/오류'
/// 라도 답을 원하는 사람과 그냥 알려주는 사람이 갈린다.
///
/// 그래서 이메일 칸 아래에서 **"답변이 필요할 경우에만 적어주시면 돼요"** 로 그 자리에서 밝힌다 —
/// 답변 여부가 이 칸에 달렸다는 걸 알리는 유일한 장치라 지우지 말 것. 답을 기다리게 해놓고 안 주는 게
/// 창구가 아예 없는 것보다 나쁘다.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const int _contentMaxLength = 1000;

  /// 즉시 피드백용 1차 검증. 진실의 원천은 서버 (FEEDBACK_REPLY_EMAIL_INVALID).
  static final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _contentController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();

  String? _type;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 보내기 버튼 활성 조건이 내용에 걸려 있어 입력마다 다시 그린다.
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

  bool get _canSubmit =>
      _type != null && _contentController.text.trim().isNotEmpty && !_busy;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isNotEmpty && !_emailShape.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일 형식을 확인해주세요.')),
      );
      _emailFocus.requestFocus();
      return;
    }

    final api = FeedbackScope.of(context); // await 전에 읽을 것
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await api.submit(
        type: _type!,
        content: _contentController.text,
        replyEmail: email.isEmpty ? null : email,
      );
      if (!mounted) return;
      navigator.pop();
      // 감사 인사는 화면 상단이 맡는다 — 여기서 또 인사하면 두 번 겹쳐 오히려 옅어지므로
      // 완료 알림은 "보내졌다" 하나만 담백하게 전한다 (이메일 유무로 갈라지지 않는다).
      messenger.showSnackBar(
        const SnackBar(content: Text('의견이 성공적으로 보내졌어요.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('전송 실패: ${toApiException(e).message}')),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('의견 보내기')),
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
            // 말투는 탈퇴 화면과 같은 기준 — 해요체 + 겸양. 감사는 '덕분에'(공을 사용자에게)와
            // '시간 내어'(들인 노력을 알아줌) 두 축으로 표현하고, 부풀린 수식어는 쓰지 않는다.
            const Text('TenK에 보내고 싶은 의견이 있으신가요?', style: AppTypo.title),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              // 줄바꿈 없이 한 문단으로 흐르게 둔다 (기기 폭에 따라 자연스럽게 접힌다).
              '회원님의 소중한 시간을 내어 TenK에 의견을 내어 주셔서 진심으로 감사해요. '
              '보내주신 의견은 TenK와 개발자에게 큰 힘이 돼요.',
              style: AppTypo.body,
            ),
            const SizedBox(height: AppSpacing.xl),

            // 폐쇄형(유형) 먼저, 자유 서술은 그다음 — 고르는 부담이 낮은 것부터 둔다.
            // 지출 카테고리와 같은 셀렉박스(아이콘 + 라벨, value=code)로 통일한다.
            const FieldLabel('어떤 이야기인가요?', required: true),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(hintText: '유형 선택'),
              items: [
                for (final type in _types)
                  DropdownMenuItem(
                    value: type.code,
                    child: Row(
                      children: [
                        Icon(type.icon, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(type.label, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
              ],
              // 미선택 검증은 validator 대신 '보내기' 비활성으로 한다 (이 화면엔 Form 이 없다).
              onChanged: _busy ? null : (code) => setState(() => _type = code),
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
                hintText: '내용이 구체적일수록 정확하고 빠른 조치가 가능해요.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            const FieldLabel('답변받을 이메일', optional: true),
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
            const SizedBox(height: AppSpacing.md),
            const Text(
              '· 답변이 필요할 경우에만 적어주시면 돼요.\n'
              '· 정확한 조치를 위해 앱 버전과 기기 OS 정보가 함께 전송돼요.',
              style: AppTypo.caption,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
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
                : const Text('보내기'),
          ),
        ),
      ),
    );
  }
}
