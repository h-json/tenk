import 'package:flutter/material.dart';

import '../../app/scopes.dart';
import '../../design/tokens.dart';

/// **첫 챌린지를 만든 직후** 알림을 권하는 바텀시트.
///
/// ⚠️ **온보딩(연령→동의→닉네임) 뒤에 세우지 말 것.** 예전엔 거기 있었는데, 그 시점의
/// 사용자는 챌린지가 0개라 [buildNotificationPlan] 이 **아무것도 예약하지 않는다** — 승인해도
/// 첫 챌린지를 만들기 전까지 알림이 한 개도 안 온다("켰는데 안 오네"). 챌린지가 생긴 뒤에
/// 물어야 승인이 곧 실제 예약으로 이어진다 (decisions.md "알림 권유 화면").
///
/// **왜 시스템 다이얼로그를 바로 띄우지 않나**: Android 13+ 는 두 번, iOS 는 한 번 거부하면
/// 그 다이얼로그가 다시 뜨지 않는다. 맥락 없이 물어 거부당하면 되돌릴 방법이 앱 설정 안내뿐이라,
/// 무엇을 알릴지 먼저 보여주고 원하는 사람만 시스템 다이얼로그로 보낸다.
///
/// **바깥 탭·드래그로는 닫히지 않는다** — 권유 기회가 유한한데 실수로 닫히면 '한 번만 띄운다'
/// 플래그만 소진된다. 시스템 back 은 막지 않는다(= '나중에' 와 같은 결과).
Future<void> showNotificationPriming(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => const _NotificationPrimingSheet(),
  );
}

class _NotificationPrimingSheet extends StatefulWidget {
  const _NotificationPrimingSheet();

  @override
  State<_NotificationPrimingSheet> createState() =>
      _NotificationPrimingSheetState();
}

class _NotificationPrimingSheetState extends State<_NotificationPrimingSheet> {
  bool _busy = false;

  Future<void> _allow() async {
    setState(() => _busy = true);
    // 거부해도 그냥 닫는다 — 여기서 붙잡으면 게이트가 된다. 나중에 설정에서 켤 수 있다.
    await NotificationScope.of(context).enableWithPermission();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        // 내용 높이대로 뜨되, 작은 화면·큰 글자에서 넘치면 스크롤한다.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // stretch 라 그냥 두면 아이콘 상자가 가로로 늘어난다.
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
              // "챌린지가 시작되면" 은 지울 수 없는 설명이다 — 시작일 전에는 리마인더를 걸지
              // 않으므로(notification_plan.dart `_isActiveOn`), 이 말이 없으면 내일 시작하는
              // 챌린지를 만든 사람이 "켰는데 오늘 안 왔다" 로 읽는다.
              const Text(
                '기록을 놓치지 않게, 챌린지가 시작되면 하루 한 번만 알려드려요.',
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
              const SizedBox(height: AppSpacing.xs),
              FilledButton(
                onPressed: _busy ? null : _allow,
                child: const Text('알림 받기'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('나중에'),
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
