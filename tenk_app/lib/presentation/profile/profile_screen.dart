import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../data/api/api_error.dart';
import '../../data/app/app_version.dart';
import '../../data/user/user.dart';
import '../../design/tokens.dart';
import '../legal/legal_notice_screen.dart';
import '../update/update_gate.dart';
import 'account_settings_screen.dart';
import 'my_info_screen.dart';

/// 챌린지 목록 AppBar 의 사람 아이콘에서 진입하는 **메뉴 화면**. 자체 콘텐츠 없이 하위 화면으로만 분기한다.
///
/// - 내 정보 → [MyInfoScreen] (닉네임 / 성별)
/// - 계정 설정 → [AccountSettingsScreen] (연동 계정 / 로그아웃 / 회원 탈퇴)
/// - 법적 고지 → [LegalNoticeScreen] (이용약관 / 개인정보처리방침)
/// - 테스트 데이터 재생성 (TESTER 권한 계정만)
///
/// 화면 제목은 '메뉴'로 확정됐다 (2026-07-25). 이 허브는 설정(preference) 모음이 아니라
/// 내 정보·계정·법적 고지·앱 정보 등 이질적 항목을 모아 분기하는 메뉴라서 '설정'이 아닌 '메뉴'다.
/// 진입점 아이콘도 챌린지 목록 AppBar 에서 `Icons.menu`(햄버거)로 통일했다.
/// 소리·진동 같은 설정성 항목이 생기면 최상위에 토글을 두지 말고 '알림/효과 설정' 하위 화면을 새로 추가할 것.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false; // 테스트 데이터 재생성 진행 중
  User? _user;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return; // InheritedWidget 은 initState 밖(여기)에서 읽는다. 1회만.
    _started = true;
    _loadUser();
  }

  /// user 는 **TESTER 타일 노출 판정 + 계정 설정에 넘길 값**에만 쓰인다.
  /// 메뉴 자체는 순수 내비게이션 허브라 이 로드를 기다리지 않고, 실패해도 막지 않는다
  /// (실패 시 영향은 TESTER 타일 미노출뿐이고, 계정 설정은 user 가 null 이면 스스로 읽는다).
  /// `/me` 하나가 실패했다고 법적 고지·앱 버전까지 못 들어가면 안 되므로 ErrorView 로 덮지 않는다.
  Future<void> _loadUser() async {
    final api = UserScope.of(context); // await 전에 읽을 것
    try {
      final user = await api.getMe();
      if (mounted) setState(() => _user = user);
    } catch (_) {
      // 무시 — 위 주석 참고.
    }
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
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
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
            // 화면을 막지 않는 백그라운드 갱신이라 돌아온 즉시 메뉴가 보인다.
            if (mounted) _loadUser();
          },
        ),
        const Divider(height: 1),
        // ── 계정 설정 (하위 화면) ──
        ListTile(
          leading: const Icon(Icons.manage_accounts_outlined),
          title: const Text('계정 설정'),
          trailing: const Icon(Icons.chevron_right, color: AppColors.inkMuted),
          // user 가 아직 안 왔으면 null 을 넘긴다 — 그 화면이 스스로 읽는다 (탭을 막지 않기 위해).
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AccountSettingsScreen(user: _user),
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
        const Divider(height: 1),
        // ── 앱 버전 (+ 최신 여부. 업데이트 있으면 탭 시 스토어로) ──
        const _AppVersionTile(),

        // ── 테스트 도구 (TESTER 권한 계정만) ──
        // user 로드 후에 나타난다. dev 계정 한정이라 뒤늦은 등장이 문제되지 않는다.
        if (_user?.isTester ?? false) ...[
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

/// 메뉴의 '앱 버전' 행. 현재 버전을 표시하고, 서버 정책상 업데이트가 있으면 안내 + 탭 시 스토어로.
/// User 로딩과 별개의 비동기 자원이라 (AsyncStateMixin 을 겹쳐 쓰지 않고) 자체 상태를 든다.
class _AppVersionTile extends StatefulWidget {
  const _AppVersionTile();

  @override
  State<_AppVersionTile> createState() => _AppVersionTileState();
}

class _AppVersionTileState extends State<_AppVersionTile> {
  String? _version;
  AppVersionInfo? _info;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return; // InheritedWidget 은 initState 밖(여기)에서 읽는다. 1회만.
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final api = AppScope.of(context);
    final version = await api.currentVersion();
    if (mounted) setState(() => _version = version);
    final info = await api.checkVersion();
    if (mounted) setState(() => _info = info);
  }

  @override
  Widget build(BuildContext context) {
    final versionText = _version == null ? '확인 중…' : 'v$_version';
    final info = _info;
    final hasUpdate = info != null && (info.updateAvailable || info.updateRequired);

    String? statusLabel;
    Color statusColor = AppColors.inkMuted;
    if (hasUpdate) {
      statusLabel = '업데이트가 있어요';
      statusColor = AppColors.primary;
    } else if (info?.status == AppVersionStatus.latest) {
      statusLabel = '최신 버전이에요';
    }
    // info 가 null(로딩 중)이거나 unknown(확인 실패)이면 상태 라벨 없이 버전만 노출.

    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('앱 버전'),
      subtitle: statusLabel == null
          ? null
          : Text(statusLabel, style: TextStyle(color: statusColor)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(versionText, style: const TextStyle(color: AppColors.inkSub)),
          if (hasUpdate) ...[
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppColors.inkMuted),
          ],
        ],
      ),
      onTap: hasUpdate ? () => openStorePage(context, info.storeUrl) : null,
    );
  }
}
