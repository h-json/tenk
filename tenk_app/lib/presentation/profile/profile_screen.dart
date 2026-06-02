import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../data/api/api_error.dart';
import '../../data/user/user.dart';
import '../common/async_state.dart';
import '../login/login_screen.dart';

/// '내 정보' 화면. AppBar 의 사람 아이콘에서 진입.
///
/// - 이메일 / 카카오 연동 표시 (읽기 전용)
/// - 닉네임 (현재 값 + 변경 다이얼로그). 하루 1회 제한에 걸리면 '내일 자정 이후 변경 가능' 표시
/// - 로그아웃 (확인 X — 즉시 처리)
/// - 회원 탈퇴 (1단계 confirm 다이얼로그, "모든 정보와 기록이 영구히 삭제됩니다" 경고)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AsyncStateMixin<ProfileScreen, User> {
  bool _busy = false; // 로그아웃 / 탈퇴 / 닉네임 변경 진행 중

  @override
  Future<User> fetch() => UserScope.of(context).getMe();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ensureLoaded();
  }

  Future<void> _openNicknameDialog(User user) async {
    if (!user.canChangeNicknameNow) {
      _showSnack(_nextChangeMessage(user.nicknameChangeAvailableFrom));
      return;
    }
    final next = await showDialog<String>(
      context: context,
      builder: (_) => _NicknameEditDialog(initial: user.nickname ?? ''),
    );
    if (!mounted) return;
    if (next == null) return; // 취소
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

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await AuthScope.of(context).logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('로그아웃 실패: ${toApiException(e).message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmWithdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('정말 탈퇴하시겠어요?'),
        content: const Text(
          '탈퇴하면 모든 정보와 기록이 영구히 삭제되고 복구할 수 없어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await UserScope.of(context).withdraw();
      if (!mounted) return;
      // withdraw 직후 storage 의 토큰은 더 이상 유효하지 않음. logout() 의 storage.clear() 만 활용.
      await AuthScope.of(context).logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('탈퇴 실패: ${toApiException(e).message}');
      setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _nextChangeMessage(DateTime? from) {
    if (from == null) return '닉네임은 하루에 한 번만 변경할 수 있어요.';
    final y = from.year;
    final m = from.month.toString().padLeft(2, '0');
    final d = from.day.toString().padLeft(2, '0');
    return '$y년 $m월 $d일 이후에 다시 변경할 수 있어요.';
  }

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
          leading: const Icon(Icons.chat_bubble_outline),
          title: const Text('연동 계정'),
          subtitle: Text(user.email ?? '카카오 계정으로 로그인 중'),
        ),
        const Divider(height: 1),
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
                const Icon(Icons.lock_outline, size: 18, color: Colors.black38),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: _busy ? null : () => _openNicknameDialog(user),
        ),
        if (!canChange)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
            child: Text(
              _nextChangeMessage(user.nicknameChangeAvailableFrom),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('로그아웃'),
          onTap: _busy ? null : _logout,
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text('회원 탈퇴', style: TextStyle(color: Colors.red)),
          onTap: _busy ? null : _confirmWithdraw,
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

class _NicknameEditDialog extends StatefulWidget {
  const _NicknameEditDialog({required this.initial});

  final String initial;

  @override
  State<_NicknameEditDialog> createState() => _NicknameEditDialogState();
}

class _NicknameEditDialogState extends State<_NicknameEditDialog> {
  static final RegExp _forbiddenChars =
      RegExp(r'[\p{Cc}\p{Cf}]', unicode: true);
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
              labelText: '새 닉네임',
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
            '변경 후 24시간 동안은 다시 변경할 수 없어요.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
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
