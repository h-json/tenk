import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../data/api/api_error.dart';
import '../../data/app/app_version.dart';
import '../../data/user/user.dart';
import '../../design/tokens.dart';
import '../feedback/feedback_screen.dart';
import '../legal/legal_notice_screen.dart';
import '../update/update_gate.dart';
import 'account_settings_screen.dart';
import 'my_info_screen.dart';

/// 챌린지 목록 AppBar 의 사람 아이콘에서 진입하는 **메뉴 화면**. 자체 콘텐츠 없이 하위 화면으로만 분기한다.
///
/// - 내 정보 → [MyInfoScreen] (닉네임 / 성별)
/// - 계정 설정 → [AccountSettingsScreen] (연동 계정 / 로그아웃 / 회원 탈퇴)
/// - 의견 보내기 → [FeedbackScreen] (익명 저장, 회신 이메일만 선택)
/// - 법적 고지 → [LegalNoticeScreen] (이용약관 / 개인정보처리방침 / 문의)
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
        // ── 의견 보내기 (하위 화면) ──
        // 정적 문서(법적 고지)보다 위에 둔다 — 사용자가 능동적으로 하는 행동이라서.
        ListTile(
          leading: const Icon(Icons.chat_bubble_outline),
          title: const Text('의견 보내기'),
          trailing: const Icon(Icons.chevron_right, color: AppColors.inkMuted),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const FeedbackScreen()),
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
///
/// **판정은 앱 시작 때 이미 끝나 있다** — SessionGate 가 강제 업데이트 게이트를 위해 `checkVersion()`
/// 을 호출하고 `AppApi.lastKnownVersion` 에 남긴다. 그래서 이 행은 같은 걸 다시 묻지 않고 첫
/// 프레임에 버전+상태를 완성된 상태로 그린다(로딩 표시 없음). 부팅 확인이 실패해 캐시가 비어 있을
/// 때만 여기서 한 번 더 확인한다.
///
/// 업데이트 안내는 **눌러야 알 수 있으면 안 된다** — 알려야 할 순간에 아무도 누르지 않기 때문에,
/// 상태는 항상 그 자리에 떠 있어야 한다. '탭하면 확인' 방식으로 바꾸지 말 것.
class _AppVersionTile extends StatefulWidget {
  const _AppVersionTile();

  @override
  State<_AppVersionTile> createState() => _AppVersionTileState();
}

class _AppVersionTileState extends State<_AppVersionTile> {
  /// ListTile 이 leading 아이콘·제목을 배치하는 기본 치수. 이 행은 leading 슬롯을 쓰지 않고
  /// 직접 그리므로, 같은 값을 써야 다른 메뉴 항목과 가로가 정확히 맞는다.
  static const double _iconSize = 24;
  static const double _leadingGap = 16;

  String? _version;
  AppVersionInfo? _info;
  bool _started = false;
  bool _checking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return; // InheritedWidget 은 initState 밖(여기)에서 읽는다. 1회만.
    _started = true;

    // 첫 build 이전이라 setState 없이 그대로 채운다 → '확인 중…' 플래시가 없다.
    final api = AppScope.of(context);
    _version = api.cachedVersion;
    _info = api.lastKnownVersion;
    if (_version == null || _info == null) _load(); // 정상 경로에선 네트워크 0회.
  }

  Future<void> _load() async {
    if (_checking) return;
    setState(() => _checking = true);
    final api = AppScope.of(context);
    try {
      final version = await api.currentVersion();
      if (mounted) setState(() => _version = version);
      final info = await api.checkVersion();
      if (mounted) setState(() => _info = info);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final versionText = _version == null ? '확인 중…' : 'v$_version';
    final info = _info;
    final hasUpdate = info != null && (info.updateAvailable || info.updateRequired);
    final isLatest = info?.status == AppVersionStatus.latest;

    // 탭 3분기. 최신일 때도 눌리게 두는 이유: 아무 반응 없는 행은 고장처럼 보인다.
    final VoidCallback? onTap;
    if (hasUpdate) {
      onTap = () => openStorePage(context, info.storeUrl);
    } else if (isLatest) {
      // "이미 최신이에요" 처럼 쓰지 말 것 — 업데이트하러 눌렀다고 전제하는 말이라,
      // 그냥 버전을 확인하러 누른 사람에게는 어긋난다. 상태만 담백하게 알린다.
      onTap = () => _showSnack('최신 버전을 이용 중이에요.');
    } else {
      onTap = _checking ? null : _load; // 확인 실패 상태 → 다시 확인.
    }

    String? statusLabel;
    Color statusColor = AppColors.inkMuted;
    if (hasUpdate) {
      statusLabel = '업데이트가 있어요';
      statusColor = AppColors.primary;
    } else if (isLatest) {
      statusLabel = '최신 버전이에요';
    }
    // 확인 전이거나 unknown(확인 실패)이면 상태 라벨 없이 버전만 노출.

    // 아이콘·버전을 **첫째 줄에** 맞추기 위해 ListTile 의 `leading`/`trailing` 슬롯을 쓰지 않는다.
    // 그 슬롯들은 (titleAlignment 를 뭘로 주든) 두 줄 전체를 기준으로 배치돼 제목 줄과 어긋나고,
    // 가운데 정렬이면 둘째 줄이 제목과 동등한 무게로 읽힌다 — 상태 라벨은 **부가 줄**이라 그러면 안 된다.
    // 그래서 첫째 줄 요소를 전부 `title` 의 Row 하나에 담고, 가로 위치만 ListTile 기본값으로 재현한다.
    return ListTile(
      title: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.inkSub), // = ListTile leading 색
          const SizedBox(width: _leadingGap),
          const Text('앱 버전'),
          const Spacer(),
          // 이 행의 주인공은 버전 숫자다 — 제목과 같은 크기로 두고 색만 낮춘다.
          Text(versionText,
              style: AppTypo.body.copyWith(color: AppColors.inkSub)),
          if (hasUpdate) ...[
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppColors.inkMuted),
          ],
        ],
      ),
      subtitle: statusLabel == null
          ? null
          // 제목 글자 아래에 맞춰 들여쓴다 (아이콘 폭 + 간격).
          : Padding(
              padding: const EdgeInsets.only(left: _iconSize + _leadingGap),
              child: Text(statusLabel, style: TextStyle(color: statusColor)),
            ),
      onTap: onTap,
    );
  }
}
