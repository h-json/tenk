// 우리 [AppSettings](효과음·진동·알림 설정)와 클래스 이름이 겹쳐 별칭으로 받는다.
import 'package:app_settings/app_settings.dart' as system_settings;
import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../data/notification/notification_prefs.dart';
import '../../data/settings/app_settings.dart';
import '../../design/tokens.dart';
import '../common/date_time_picker.dart';

/// 메뉴 → '설정' 하위 화면. 효과음·진동 + 알림(마스터 1 + 종류별 3 + 리마인더 시각).
///
/// **최상위 메뉴에 토글을 두지 않고 이 화면으로 모은다** (CLAUDE.md "메뉴 화면").
/// 이름이 '소리 및 진동' 이 아니라 '설정' 인 이유가 이것 — 알림이 들어올 자리가 필요했다.
///
/// 값은 [AppSettings] 가 즉시 저장하고, 효과음·햅틱은 **재생 직전에 읽는다** —
/// 구독이 없어서 여기서 알림을 쏠 곳이 없다. 리빌드가 필요한 건 이 화면뿐이라
/// 로컬 state 로 충분하다.
///
/// 단 **알림 설정만은 저장 후 곧바로 재예약**해야 한다([_SettingsScreenState._update]) —
/// 예약은 값을 읽어 미리 걸어두는 것이라, 저장만 하면 다음 앱 실행까지 예전 계획이 살아 있다.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings? _settings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // InheritedWidget 은 initState 밖(여기)에서 읽는다. 값은 이미 메모리에 있어 로딩 없음.
    _settings ??= SettingsScope.of(context);
  }

  NotificationPrefs get _noti => _settings!.notifications;

  TimeOfDay get _reminderTime =>
      TimeOfDay(hour: _noti.reminderHour, minute: _noti.reminderMinute);

  /// 값을 저장하고 **그 자리에서 재예약한다.** 저장만 하면 다음 앱 실행까지 예전 계획이 살아
  /// 있어 토글이 고장 난 것으로 보인다. (AppSettings 에 리스너를 붙이지 않는 게 의도 —
  /// 붙이는 순간 그 Scope 가 "화면 간 공유 상태" 가 된다. CLAUDE.md "알림".)
  Future<void> _update(NotificationPrefs next) async {
    await NotificationScope.of(context).updatePrefs(next);
    if (mounted) setState(() {});
  }

  /// 마스터 토글. 켤 때만 시스템 권한을 묻는다 — 여기가 "맥락 있는 opt-in" 지점이다.
  ///
  /// ⚠️ **거부당하면 앱이 할 수 있는 게 없다.** Android 11+ 는 두 번 거부하면, iOS 는
  /// 한 번 거부하면 시스템 다이얼로그가 **다시 뜨지 않는다**(요청은 즉시 false 로 돌아온다).
  /// 그래서 재요청을 반복하는 코드를 넣지 말 것 — 아무 일도 안 일어나 고장으로 보인다.
  /// 유일한 탈출구가 기기 설정이므로 **말만 하지 말고 그 화면으로 데려다준다.**
  Future<void> _setMaster(bool value) async {
    if (!value) {
      await _update(_noti.copyWith(enabled: false));
      return;
    }
    final granted = await NotificationScope.of(context).enableWithPermission();
    if (!mounted) return;
    setState(() {});
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('기기 설정에서 TenK 의 알림을 허용해 주세요.'),
          action: SnackBarAction(
            label: '설정 열기',
            // 앱의 알림 설정 페이지로 바로 꽂는다 (설정 앱 → 앱 목록 → TenK → 알림 을
            // 직접 찾아가면 4~5단계다). Android/iOS 16+ 모두 이 타입을 지원한다.
            onPressed: () => system_settings.AppSettings.openAppSettings(
              type: system_settings.AppSettingsType.notification,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await pickTenkTime(
      context,
      initial: _reminderTime,
      helpText: '리마인더 시각',
    );
    if (picked == null || !mounted) return;
    await _update(
      _noti.copyWith(reminderHour: picked.hour, reminderMinute: picked.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings!;
    final noti = _noti;
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            const SizedBox(height: 8),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_outlined),
              title: const Text('효과음'),
              subtitle: const Text('배지 획득·영상 녹화 시작에 소리를 재생해요'),
              value: settings.soundEnabled,
              onChanged: (v) async {
                await settings.setSoundEnabled(v);
                if (mounted) setState(() {});
              },
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.vibration_outlined),
              title: const Text('진동'),
              subtitle: const Text('배지 획득·녹화 시작·시간 선택에 진동을 울려요'),
              value: settings.hapticsEnabled,
              onChanged: (v) async {
                await settings.setHapticsEnabled(v);
                if (mounted) setState(() {});
                // 켠 직후 한 번 울려 어떤 느낌인지 그 자리에서 확인시킨다.
                if (v) settings.selectionClick();
              },
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: Text(
                '기기가 무음·방해 금지 모드면 설정과 상관없이 소리가 나지 않을 수 있어요.',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Divider(height: 1),
            _sectionHeader('알림'),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('알림 받기'),
              subtitle: Text(
                noti.enabled ? '기록·마감·결과를 알려드려요' : '지금은 알림을 보내지 않아요',
              ),
              value: noti.enabled,
              onChanged: _setMaster,
            ),
            // 마스터가 꺼져 있으면 종류별 토글은 의미가 없어 통째로 감춘다 — 꺼진 항목을
            // 늘어놓는 것보다 "지금 알림을 안 받는 중" 이 한눈에 읽히는 게 낫다.
            if (noti.enabled) ...[
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.edit_calendar_outlined),
                title: const Text('매일 기록 리마인더'),
                subtitle: Text(
                    '${formatTimeOfDay(context, _reminderTime)}에 알려드려요'),
                value: noti.reminderEnabled,
                onChanged: (v) => _update(noti.copyWith(reminderEnabled: v)),
              ),
              if (noti.reminderEnabled)
                ListTile(
                  contentPadding:
                      const EdgeInsets.only(left: 72, right: AppSpacing.lg),
                  title: const Text('알림 시각'),
                  trailing: Text(
                    formatTimeOfDay(context, _reminderTime),
                    style: AppTypo.body.copyWith(color: AppColors.inkSub),
                  ),
                  onTap: _pickReminderTime,
                ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.event_busy_outlined),
                title: const Text('챌린지 종료 임박'),
                subtitle: const Text('마지막 날에 한 번 알려드려요'),
                value: noti.deadlineEnabled,
                onChanged: (v) => _update(noti.copyWith(deadlineEnabled: v)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.emoji_events_outlined),
                title: const Text('결과 확정 대기'),
                subtitle: const Text('기간이 끝났는데 확정하지 않았을 때 알려드려요'),
                value: noti.finalizeEnabled,
                onChanged: (v) => _update(noti.copyWith(finalizeEnabled: v)),
              ),
            ],
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: Text(
                '알림은 기기에서 직접 예약해요. 진행 중인 챌린지가 없거나 그날 이미 기록했다면 리마인더를 보내지 않아요.',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Text(
          text,
          style: AppTypo.caption.copyWith(
            color: AppColors.inkMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
