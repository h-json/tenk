import 'package:flutter/foundation.dart';

import '../challenge/challenge.dart';
import '../challenge/challenge_api.dart';
import '../settings/app_settings.dart';
import 'notification_plan.dart';
import 'notification_prefs.dart';
import 'notification_service.dart';

/// 알림 재예약의 **유일한 진입점**. 화면·설정·앱 복귀가 전부 [rescheduleAll] 하나만 부른다.
///
/// **전량 취소 후 다시 건다.** 부분 갱신을 하면 취소·중복의 경우의 수가 폭발하고, 어차피
/// 계획을 세우는 건 순수 함수라 매번 다시 만드는 비용이 사실상 없다 (CLAUDE.md "알림").
///
/// `AppSettings` 에 리스너를 붙이지 않는 게 의도다 — 설정을 바꾼 쪽이 이 메서드를 명시적으로
/// 부른다. 구독을 붙이는 순간 그 Scope 가 "화면 간 공유 상태"가 되어 상태 관리 라이브러리
/// 도입 트리거(decisions.md "Flutter 상태 관리 재검토")에 걸린다.
class NotificationScheduler {
  NotificationScheduler({
    required NotificationService service,
    required ChallengeApi challengeApi,
    required AppSettings settings,
  }) : _service = service,
       _challengeApi = challengeApi,
       _settings = settings;

  final NotificationService _service;
  final ChallengeApi _challengeApi;
  final AppSettings _settings;

  bool _running = false;

  NotificationPrefs get prefs => _settings.notifications;

  /// 설정을 저장하고 곧바로 재예약한다. 저장만 하고 재예약을 잊으면 토글이 고장 난 것으로 보인다.
  Future<void> updatePrefs(NotificationPrefs value) async {
    await _settings.setNotifications(value);
    await rescheduleAll();
  }

  /// 기록을 남긴 직후 호출 — 오늘 리마인더를 걷어낸다.
  Future<void> onRecordSaved() async {
    await _settings.markRecordedNow();
    await rescheduleAll();
  }

  /// 전량 취소 후 현재 상태로 다시 예약한다.
  ///
  /// [challenges] 를 주면 그걸 쓰고(목록 화면이 방금 받은 응답 재사용), 없으면 직접 조회한다.
  /// **실패해도 조용히 넘긴다** — 알림은 부가 기능이라 이것 때문에 화면이 깨지면 안 된다.
  Future<void> rescheduleAll({List<Challenge>? challenges}) async {
    if (_running) return; // 포그라운드 복귀와 목록 로드가 겹칠 수 있다
    _running = true;
    try {
      await _service.cancelAll();
      final current = prefs;
      if (!current.enabled) return;
      // 권한이 없으면 예약해도 뜨지 않는다 — 시스템 설정에서 껐을 수 있다.
      if (!await _service.hasPermission()) return;

      final list = challenges ?? await _challengeApi.list();
      final plan = buildNotificationPlan(
        challenges: list,
        prefs: current,
        now: DateTime.now(),
        lastRecordedDate: _settings.lastRecordedDate,
      );
      for (final item in plan) {
        await _service.schedule(item);
      }
      if (kDebugMode) {
        debugPrint('[Notification] scheduled ${plan.length} item(s)');
      }
    } catch (e) {
      // 네트워크 실패·플랫폼 예외 모두 여기로. 다음 재예약 시점에 다시 시도된다.
      if (kDebugMode) debugPrint('[Notification] reschedule skipped: $e');
    } finally {
      _running = false;
    }
  }

  /// 권한을 요청하고, 승인되면 마스터를 켜고 예약까지 마친다. 승인 여부를 돌려준다.
  Future<bool> enableWithPermission() async {
    final granted = await _service.requestPermission();
    if (!granted) return false;
    await updatePrefs(prefs.copyWith(enabled: true));
    return true;
  }
}
