import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../design/tokens.dart';
import '../common/bottom_action_scroll_view.dart';

/// 가입 직후(닉네임 다음) 알림을 권하는 화면.
///
/// ⚠️ **게이트가 아니다 — back 을 차단하지 말 것.** 앞의 셋(연령·동의·닉네임)은 통과해야만
/// 서비스를 쓸 수 있는 필수 관문이지만 알림은 **선택**이다. '나중에' 로 건너뛸 수 있어야 하고,
/// 강제하면 정책 위반이기도 하다 (CLAUDE.md "알림", decisions.md "알림 기능" 결정 8).
///
/// **왜 시스템 다이얼로그를 바로 띄우지 않나**: Android 13+ 는 한 번 거부하면 그 다이얼로그가
/// 다시 뜨지 않는다. 맥락 없이 물어 거부당하면 되돌릴 방법이 앱 설정 안내뿐이라, 무엇을 알릴지
/// 먼저 보여주고 원하는 사람만 시스템 다이얼로그로 보낸다.
class NotificationPrimingScreen extends StatefulWidget {
  const NotificationPrimingScreen({super.key, required this.next});

  /// 승인하든 건너뛰든 다음에 갈 화면 (보통 홈).
  final Widget next;

  @override
  State<NotificationPrimingScreen> createState() =>
      _NotificationPrimingScreenState();
}

class _NotificationPrimingScreenState extends State<NotificationPrimingScreen> {
  bool _busy = false;

  void _goNext() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => widget.next),
      (_) => false,
    );
  }

  Future<void> _allow() async {
    setState(() => _busy = true);
    // 거부해도 그냥 넘어간다 — 여기서 붙잡으면 게이트가 된다. 나중에 설정에서 켤 수 있다.
    await NotificationScope.of(context).enableWithPermission();
    if (!mounted) return;
    _goNext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // 작은 화면에서 그대로 터지던 자리다 (2026-08-03 실측: 560dp 에서 2.6px overflow).
        // 하단 액션 + 스크롤 처리는 게이트 화면들과 같은 공용 위젯에 맡긴다.
        child: BottomActionScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          // 원래 위 1 : 아래 2 로 콘텐츠를 살짝 위에 두던 비율을 그대로 유지한다.
          spacerFlex: 2,
          body: [
            const Spacer(),
            // 공용 위젯의 Column 은 stretch 라 아이콘 상자가 가로로 늘어난다 — Align 으로 잡아둔다.
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('알림을 받아보시겠어요?', style: AppTypo.title),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '기록을 놓치지 않도록 하루 한 번만 알려드려요.',
              style: TextStyle(color: AppColors.inkSub, fontSize: 15),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _Bullet(
              icon: Icons.edit_calendar_outlined,
              title: '매일 기록 리마인더',
              body: '그날 기록이 없을 때만 저녁에 알려드려요.',
            ),
            const _Bullet(
              icon: Icons.event_busy_outlined,
              title: '챌린지 종료 임박',
              body: '마지막 날을 놓치지 않게 알려드려요.',
            ),
            const _Bullet(
              icon: Icons.emoji_events_outlined,
              title: '결과 확정 대기',
              body: '기간이 끝나면 결과를 확인하라고 알려드려요.',
            ),
          ],
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _allow,
                child: const Text('알림 받기'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _busy ? null : _goNext,
                child: const Text('나중에'),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              '알림은 언제든 메뉴 → 설정에서 켜고 끌 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypo.body.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(color: AppColors.inkSub, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
