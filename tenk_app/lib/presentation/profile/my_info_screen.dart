import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../data/api/api_error.dart';
import '../../data/user/user.dart';
import '../../design/tokens.dart';
import '../common/async_state.dart';
import 'gender_edit_screen.dart';
import 'nickname_edit_screen.dart';

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

  Future<void> _openNicknameEditor(User user) async {
    if (!user.canChangeNicknameNow) {
      _showSnack(nextNicknameChangeMessage(user.nicknameChangeAvailableFrom));
      return;
    }
    final next = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => NicknameEditScreen(initial: user.nickname ?? ''),
      ),
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

  Future<void> _openGenderEditor(User user) async {
    // 3-state: 값 선택 / 미입력으로 되돌리기 / 취소. 취소와 '입력 안 함' 을 구분해야 해서
    // pop 값을 감싸서 반환한다 (null 을 그냥 pop 하면 취소와 구분이 안 됨).
    final result = await Navigator.of(context).push<GenderChoice>(
      MaterialPageRoute<GenderChoice>(
        builder: (_) => GenderEditScreen(initial: user.gender),
      ),
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
          onTap: _busy ? null : () => _openNicknameEditor(user),
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
          onTap: _busy ? null : () => _openGenderEditor(user),
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

/// 닉네임 24시간 1회 제한 안내. **잠긴 상태에서 탭했을 때만** 노출한다 —
/// 목록 행에 상시 표시하지 않는 게 의도 (행에는 `lock_outline` 아이콘만).
///
/// 구성은 **규칙 먼저, 가능 시점은 짧게**. 연도는 넣지 않고 날짜도 절대 표기 대신
/// `now` 기준 오늘/내일 라벨을 쓴다 — 쿨다운이 정확히 24시간이라 변경 직후엔 늘 '내일',
/// 다음 날 다시 열면 '오늘'이 된다. 사용자가 뺄셈하지 않아도 되는 게 핵심.
String nextNicknameChangeMessage(DateTime? from) {
  const rule = '닉네임은 24시간에 한 번만 바꿀 수 있어요.';
  if (from == null) return rule;
  return '$rule ${_dayLabel(from)} ${_clockLabel(from)}부터 가능해요.';
}

String _dayLabel(DateTime at) {
  final days = DateUtils.dateOnly(at)
      .difference(DateUtils.dateOnly(DateTime.now()))
      .inDays;
  return switch (days) {
    0 => '오늘',
    1 => '내일',
    _ => '${at.month}월 ${at.day}일', // 24시간 쿨다운에선 안 나오지만 방어적으로
  };
}

/// "오후 10시 11분" — 정각이면 분은 생략한다.
String _clockLabel(DateTime at) {
  final hour12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final base = '${at.hour < 12 ? '오전' : '오후'} $hour12시';
  return at.minute == 0 ? base : '$base ${at.minute}분';
}

