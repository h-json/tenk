import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../config/test_config.dart';
import '../../data/api/api_error.dart';
import '../../data/user/user.dart';
import '../../design/tokens.dart';
import '../common/async_state.dart';
import '../legal/legal_notice_screen.dart';
import 'account_settings_screen.dart';
import 'my_info_screen.dart';

/// 챌린지 목록 AppBar 의 사람 아이콘에서 진입하는 **메뉴 화면**. 자체 콘텐츠 없이 하위 화면으로만 분기한다.
///
/// - 내 정보 → [MyInfoScreen] (닉네임 / 성별)
/// - 계정 설정 → [AccountSettingsScreen] (연동 계정 / 로그아웃 / 회원 탈퇴)
/// - 법적 고지 → [LegalNoticeScreen] (이용약관 / 개인정보처리방침)
/// - 테스트 데이터 재생성 (dev 전용, TEST 계정만)
///
/// ⚠️ 화면 제목 '메뉴' 는 **임시**다. 하위에 '내 정보' 가 생기면서 같은 이름이 중첩되는 걸 피하려고
/// 붙였고, '설정'(톱니 아이콘) 으로 갈지 '메뉴'(햄버거) 로 갈지는 아직 미정 — docs/handoff.md 남은 일 참고.
/// 확정되면 제목과 함께 진입점 아이콘(현재 `account_circle_outlined`)도 같이 바꿀 것.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AsyncStateMixin<ProfileScreen, User> {
  bool _busy = false; // 테스트 데이터 재생성 진행 중

  @override
  Future<User> fetch() => UserScope.of(context).getMe();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ensureLoaded();
  }

  Future<void> _reseed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('테스트 데이터 재생성'),
        content: const Text(
          '이 계정의 기존 챌린지·기록을 모두 지우고 상태별(시작 전 / 진행 중 / 확정 대기 / 완료-성공 / 완료-실패) 챌린지를 새로 만들어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('재생성'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ChallengeScope.of(context).seedTestData();
      if (!mounted) return;
      // 목록 화면이 seed 결과를 반영하도록 true 를 반환하며 pop.
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('재생성 실패: ${toApiException(e).message}')),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('메뉴')),
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
    return ListView(
      children: [
        const SizedBox(height: 8),
        // ── 내 정보 (닉네임 / 성별) ──
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: const Text('내 정보'),
          trailing: const Icon(Icons.chevron_right, color: AppColors.inkMuted),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MyInfoScreen()),
            );
            // 하위 화면에서 닉네임을 바꿨을 수 있으니 돌아오면 갱신 (계정 설정에 넘길 user 도 최신으로).
            if (mounted) reload();
          },
        ),
        const Divider(height: 1),
        // ── 계정 설정 (하위 화면) ──
        ListTile(
          leading: const Icon(Icons.manage_accounts_outlined),
          title: const Text('계정 설정'),
          trailing: const Icon(Icons.chevron_right, color: AppColors.inkMuted),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AccountSettingsScreen(user: user),
            ),
          ),
        ),
        const Divider(height: 1),
        // ── 법적 고지 (하위 화면) ──
        ListTile(
          leading: const Icon(Icons.gavel_outlined),
          title: const Text('법적 고지'),
          trailing: const Icon(Icons.chevron_right, color: AppColors.inkMuted),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LegalNoticeScreen()),
          ),
        ),

        // ── 테스트 도구 (dev 전용) ──
        if (testToolsEnabled && user.provider == 'TEST') ...[
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.science_outlined, color: Colors.deepPurple),
            title: const Text('테스트 데이터 재생성',
                style: TextStyle(color: Colors.deepPurple)),
            subtitle: const Text('기존 데이터를 지우고 상태별 챌린지 5종 생성'),
            onTap: _busy ? null : _reseed,
          ),
        ],
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
