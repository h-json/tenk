import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../data/api/api_error.dart';
import '../../design/tokens.dart';
import '../challenge/challenge_list_screen.dart';
import '../common/field_label.dart';

/// 신규 가입자 전용 닉네임 확정 화면.
///
/// - 진입 시 `/api/users/me` 로 카카오 닉네임 pre-fill
/// - 사용자가 그대로 두든 수정하든 '시작하기' 누른 순간 `PATCH /api/users/me/nickname` 호출
/// - back / system-back / swipe 모두 차단 (PopScope canPop=false). 카카오 로그인은 이미 끝났고
///   닉네임만 확정하면 챌린지 리스트로 진입할 수 있는 상태이므로 뒤로 보내는 건 의미가 없다.
/// - 안내문에 "확정 후 24시간 동안 변경 불가" 명시
class NicknameSetupScreen extends StatefulWidget {
  const NicknameSetupScreen({super.key});

  @override
  State<NicknameSetupScreen> createState() => _NicknameSetupScreenState();
}

class _NicknameSetupScreenState extends State<NicknameSetupScreen> {
  // 백엔드와 동일한 거부 패턴 — 제어 문자(\p{Cc}) + 형식 문자(\p{Cf}: zero-width, BiDi override, BOM 등).
  // 즉시 피드백용 1차 방어선. 진실의 원천은 서버 검증 (USER_NICKNAME_INVALID).
  static final RegExp _forbiddenChars = RegExp(r'[\p{Cc}\p{Cf}]', unicode: true);
  static const int _maxLength = 50;

  final _controller = TextEditingController();
  bool _loadingInitial = true;
  Object? _initialError;
  bool _saving = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    // UserScope.of(context) 는 InheritedWidget 의존을 등록하므로 initState 중엔 호출 불가.
    // 첫 프레임 이후로 미뤄 context 접근을 안전하게 한다 (result_card/export_prefetch 와 동일 패턴).
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    if (!mounted) return;
    try {
      final me = await UserScope.of(context).getMe();
      if (!mounted) return;
      final initial = me.nickname ?? '';
      setState(() {
        _controller.text = initial;
        _controller.selection = TextSelection.collapsed(offset: initial.length);
        _loadingInitial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialError = e;
        _loadingInitial = false;
      });
    }
  }

  String? _validate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '닉네임을 입력해주세요.';
    if (trimmed.length > _maxLength) return '$_maxLength자 이하로 입력해주세요.';
    if (_forbiddenChars.hasMatch(trimmed)) {
      return '사용할 수 없는 문자가 포함돼 있어요.';
    }
    return null;
  }

  Future<void> _confirm() async {
    final raw = _controller.text;
    final err = _validate(raw);
    setState(() => _validationError = err);
    if (err != null) return;

    setState(() => _saving = true);
    try {
      await UserScope.of(context).updateNickname(raw.trim());
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const ChallengeListScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = toApiException(e).message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('닉네임 설정'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(top: false, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_initialError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                toApiException(_initialError!).message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loadingInitial = true;
                    _initialError = null;
                  });
                  _loadInitial();
                },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const Text(
            '환영합니다!',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tenk 에서 사용할 닉네임을 정해주세요.\n카카오 프로필 이름이 자동으로 채워져 있어요.',
            style: AppTypo.body.copyWith(color: AppColors.inkSub),
          ),
          const SizedBox(height: 28),
          const FieldLabel('닉네임', required: true),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            enabled: !_saving,
            maxLength: _maxLength,
            decoration: InputDecoration(
              hintText: '닉네임을 입력해주세요',
              errorText: _validationError,
            ),
            onChanged: (_) {
              if (_validationError != null) {
                setState(() => _validationError = null);
              }
            },
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warnTint,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.warn),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '확정 후 24시간 동안은 닉네임을 다시 변경할 수 없어요.',
                    style: TextStyle(
                        fontSize: 13, height: 1.4, color: Color(0xFF8A5A00)),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _confirm,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      '시작하기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
