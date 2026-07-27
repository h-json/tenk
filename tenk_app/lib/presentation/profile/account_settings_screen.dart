import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../data/api/api_error.dart';
import '../../data/user/user.dart';
import '../../design/tokens.dart';
import '../login/login_screen.dart';

/// 메뉴 → '계정 설정' 하위 화면. 연동 계정 표시 + 로그아웃 + 회원 탈퇴.
///
/// [user] 는 보통 메뉴가 이미 로드한 값을 넘겨받는다 (연동 계정 표시는 세션 중 안 바뀌므로 재fetch 불필요).
/// **null 이면 스스로 읽는다** — 메뉴가 `/me` 를 기다리지 않고 즉시 그려지기 때문에 아직 값이 없을 수 있다.
/// 이때도 화면을 스피너로 막지 않는다: 로그아웃·탈퇴는 user 없이도 되고, 연동 계정 자리는 폴백 문구가 있다.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key, required this.user});

  final User? user;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _busy = false; // 로그아웃 / 탈퇴 진행 중
  User? _user;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || _user != null) return; // 넘겨받았으면 읽지 않는다
    _started = true;
    _loadUser();
  }

  Future<void> _loadUser() async {
    final api = UserScope.of(context); // await 전에 읽을 것
    try {
      final user = await api.getMe();
      if (mounted) setState(() => _user = user);
    } catch (_) {
      // 연동 계정만 폴백 문구로 남는다. 로그아웃·탈퇴는 그대로 동작.
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
      // 제목 없이 설명 다음에 질문이 오는 한 문단. 무엇을 잃는지 읽은 뒤에 결정을 묻는 순서이고,
      // 위계(크기·굵기·색)를 나누지 않아 한 호흡으로 읽힌다. 순서를 뒤집거나 강조를 넣지 말 것.
      //
      // 철회 가능하다는 사실은 여기서 알리지 않는다 (의도). 탈퇴를 결심한 사람에게 "되돌릴 수 있다" 는
      // 안내는 결정을 흐리는 잡음이라, 철회는 실제로 돌아왔을 때 로그인 화면에서 안내한다.
      // 다만 "영구히 삭제되고 복구할 수 없어요" 로도 되돌리지 말 것. 사실이 아니게 됐다.
      builder: (_) => AlertDialog(
        // 제목 슬롯을 안 쓰므로 위쪽 여백을 조금 더 준다 (기본값 20 은 title 이 있다는 전제).
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: const Text(
          // 줄바꿈은 넣지 않는다. 다이얼로그 폭이 기기마다 달라 강제 개행은 오히려 어긋난다.
          '탈퇴하면 모든 챌린지와 기록을 더 이상 볼 수 없고, '
          '일정 기간이 지나면 완전히 삭제돼요. 정말 탈퇴하시겠어요?',
          style: AppTypo.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return; // 다이얼로그 대기 중 화면이 사라졌을 수 있다

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

  /// 로그인 공급자 표시명. 아직 로드 전이거나 모르는 값이면 현재 유일한 공급자인 카카오로 폴백.
  /// Google/Naver 를 붙이면 여기에 분기를 추가할 것.
  static String _providerLabel(String? provider) => switch (provider) {
        'GOOGLE' => '구글 계정으로 로그인 중',
        'NAVER' => '네이버 계정으로 로그인 중',
        _ => '카카오 계정으로 로그인 중',
      };

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('계정 설정')),
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('연동 계정'),
              // 이메일은 수집하지 않으므로 공급자만 표시한다 (2026-07-26).
              // 로딩 중에도 이 폴백 문구가 맞는 말이라 별도 로딩 표시를 두지 않는다.
              subtitle: Text(_providerLabel(_user?.provider)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: _busy ? null : _logout,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: AppColors.danger),
              title: const Text('회원 탈퇴', style: TextStyle(color: AppColors.danger)),
              onTap: _busy ? null : _confirmWithdraw,
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
