import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../data/settings/app_settings.dart';
import '../../design/tokens.dart';

/// 메뉴 → '설정' 하위 화면. 효과음 / 진동 on/off.
///
/// **최상위 메뉴에 토글을 두지 않고 이 화면으로 모은다** (CLAUDE.md "메뉴 화면").
/// 앱에 푸시 알림이 생기면 그 설정도 여기에 들어온다 — 그래서 이름이 '소리 및 진동'
/// 이 아니라 '설정' 이다 (알림 기능 자체는 별도 백로그 #17).
///
/// 값은 [AppSettings] 가 즉시 저장하고, 다른 화면은 **재생 직전에 읽는다** —
/// 구독이 없어서 여기서 알림을 쏠 곳이 없다. 리빌드가 필요한 건 이 화면뿐이라
/// 로컬 state 로 충분하다.
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

  @override
  Widget build(BuildContext context) {
    final settings = _settings!;
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
          ],
        ),
      ),
    );
  }
}
