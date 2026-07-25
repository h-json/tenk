import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../data/api/api_error.dart';
import '../../data/user/user.dart';
import '../../design/tokens.dart';
import '../common/async_state.dart';

/// '내 정보' 하위 화면 — **사용자 본인에 대한 정보**만 모은다 (닉네임 / 성별).
///
/// 로그인·탈퇴처럼 계정 자체를 다루는 것은 AccountSettingsScreen 소관이라 여기 두지 않는다.
/// 진입 시 `/api/users/me` 를 다시 읽어 최신 값을 보여주고, 변경 결과는 [replaceData] 로 즉시 반영한다.
class MyInfoScreen extends StatefulWidget {
  const MyInfoScreen({super.key});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen>
    with AsyncStateMixin<MyInfoScreen, User> {
  bool _busy = false;

  @override
  Future<User> fetch() => UserScope.of(context).getMe();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ensureLoaded();
  }

  Future<void> _openNicknameDialog(User user) async {
    if (!user.canChangeNicknameNow) {
      _showSnack(nextNicknameChangeMessage(user.nicknameChangeAvailableFrom));
      return;
    }
    final next = await showDialog<String>(
      context: context,
      builder: (_) => _NicknameEditDialog(initial: user.nickname ?? ''),
    );
    if (!mounted || next == null) return; // 취소
    setState(() => _busy = true);
    try {
      final updated = await UserScope.of(context).updateNickname(next);
      if (!mounted) return;
      replaceData(updated);
      _showSnack('닉네임이 변경되었어요.');
    } catch (e) {
      if (!mounted) return;
      _showSnack(toApiException(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openGenderDialog(User user) async {
    // 3-state: 값 선택 / 미입력으로 되돌리기 / 취소. 취소와 '입력 안 함' 을 구분해야 해서
    // pop 값을 감싸서 반환한다 (null 을 그냥 pop 하면 취소와 구분이 안 됨).
    final result = await showDialog<_GenderChoice>(
      context: context,
      builder: (_) => _GenderPickerDialog(initial: user.gender),
    );
    if (!mounted || result == null) return; // 취소
    setState(() => _busy = true);
    try {
      final updated = await UserScope.of(context).updateGender(result.value);
      if (!mounted) return;
      replaceData(updated);
    } catch (e) {
      if (!mounted) return;
      _showSnack(toApiException(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _genderLabel(String? code) => switch (code) {
        'MALE' => '남성',
        'FEMALE' => '여성',
        'OTHER' => '기타',
        _ => '입력 안 함',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      body: SafeArea(
        top: false,
        child: AsyncStateView<User>(
          data: data,
          error: error,
          loading: loading,
          onRetry: reload,
          builder: (_, user) => _buildBody(user),
        ),
      ),
    );
  }

  Widget _buildBody(User user) {
    final canChange = user.canChangeNicknameNow;
    return ListView(
      children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('닉네임'),
          subtitle: Text(
            user.nickname ?? '-',
            style: const TextStyle(fontSize: 16),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!canChange)
                const Icon(Icons.lock_outline, size: 18, color: AppColors.inkMuted),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.inkMuted),
            ],
          ),
          onTap: _busy ? null : () => _openNicknameDialog(user),
        ),
        if (!canChange)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
            child: Text(
              nextNicknameChangeMessage(user.nicknameChangeAvailableFrom),
              style: const TextStyle(fontSize: 12, color: AppColors.inkSub),
            ),
          ),

        const Divider(height: 1),
        // 성별은 기능에 쓰이지 않는 통계용 선택 항목 — '(선택)' 표기와 미입력 기본값을 유지할 것.
        ListTile(
          leading: const Icon(Icons.wc_outlined),
          title: const Text('성별 (선택)'),
          subtitle: Text(
            _genderLabel(user.gender),
            style: TextStyle(
              fontSize: 16,
              color: user.gender == null ? AppColors.inkMuted : null,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: AppColors.inkMuted),
          onTap: _busy ? null : () => _openGenderDialog(user),
        ),

        if (_busy)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

/// "X년 X월 X일 이후에 다시 변경할 수 있어요." — 닉네임 하루 1회 제한 안내.
String nextNicknameChangeMessage(DateTime? from) {
  if (from == null) return '닉네임은 하루에 한 번만 변경할 수 있어요.';
  final y = from.year;
  final m = from.month.toString().padLeft(2, '0');
  final d = from.day.toString().padLeft(2, '0');
  return '$y년 $m월 $d일 이후에 다시 변경할 수 있어요.';
}

/// 성별 선택 결과. `null` pop(=취소)과 "입력 안 함으로 되돌리기"(`value == null`)를 구분하려고 감싼다.
class _GenderChoice {
  const _GenderChoice(this.value);

  final String? value;
}

/// 성별 선택 다이얼로그. **선택 항목**이므로 ① 수집 목적을 그 자리에서 고지하고
/// ② '입력 안 함'(수집 철회)을 항상 동등한 선택지로 노출한다.
class _GenderPickerDialog extends StatelessWidget {
  const _GenderPickerDialog({required this.initial});

  final String? initial;

  /// '입력 안 함' 을 나타내는 sentinel. RadioGroup 의 onChanged 는 null 을 "선택 해제" 로도 쓰기 때문에
  /// 미입력을 null 로 표현하면 두 의미가 겹친다. 전송 직전에만 null 로 되돌린다.
  static const _none = 'NONE';

  static const _options = <(String, String)>[
    ('MALE', '남성'),
    ('FEMALE', '여성'),
    ('OTHER', '기타'),
    (_none, '입력 안 함'),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('성별 (선택)'),
      contentPadding: const EdgeInsets.only(top: 12, bottom: 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              '이용자 통계 목적으로만 사용해요. 입력하지 않아도 모든 기능을 그대로 이용할 수 있어요.',
              style: TextStyle(fontSize: 13, color: AppColors.inkSub),
            ),
          ),
          RadioGroup<String>(
            groupValue: initial ?? _none,
            onChanged: (v) =>
                Navigator.of(context).pop(_GenderChoice(v == _none ? null : v)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (code, label) in _options)
                  RadioListTile<String>(value: code, title: Text(label)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
      ],
    );
  }
}

class _NicknameEditDialog extends StatefulWidget {
  const _NicknameEditDialog({required this.initial});

  final String initial;

  @override
  State<_NicknameEditDialog> createState() => _NicknameEditDialogState();
}

class _NicknameEditDialogState extends State<_NicknameEditDialog> {
  // 서버 UserService.NICKNAME_FORBIDDEN_CHARS 와 같은 패턴 (1차 검증). 진실의 원천은 서버.
  static final RegExp _forbiddenChars = RegExp(r'[\p{Cc}\p{Cf}]', unicode: true);
  static const int _maxLength = 50;

  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial)
      ..selection = TextSelection.collapsed(offset: widget.initial.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  void _submit() {
    final raw = _controller.text;
    final err = _validate(raw);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pop(raw.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('닉네임 변경'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: _maxLength,
            decoration: InputDecoration(
              hintText: '새 닉네임',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 4),
          const Text(
            '변경 후 24시간 동안은 다시 변경할 수 없어요.',
            style: TextStyle(fontSize: 12, color: AppColors.inkSub),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(onPressed: _submit, child: const Text('변경')),
      ],
    );
  }
}
