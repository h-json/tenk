import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_kind.dart';

/// 플랫폼 알림 래퍼 — **예약을 거는 손**이다. 무엇을 언제 걸지는 [NotificationScheduler] 가 정한다.
///
/// 로컬 알림만 쓴다 (FCM 없음). 이유는 decisions.md "알림 기능" 결정 1 —
/// 서버 발신이 필요한 알림이 0개고, iOS 푸시는 유료 계정이 있어야 하며, Firebase 를 넣으면
/// Play 데이터 안전의 "SDK 0개 / 기기 ID 미수집" 답안을 다시 짜야 한다.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  /// 앱 시작 시 1회. 타임존 DB 로드 → 플러그인 초기화 → Android 채널 3개 생성.
  ///
  /// 채널을 미리 만들어 두는 건 **첫 알림을 기다리지 않고 시스템 설정에 항목이 보이게** 하려는 것이다.
  /// 사용자가 앱 설정에서 껐다 켜는 것과 시스템 설정에서 종류별로 끄는 것이 같은 목록을 봐야 한다.
  Future<void> init() async {
    if (_ready) return;

    tz_data.initializeTimeZones();
    // 기기 타임존을 따라간다 — "매일 밤 9시" 는 사용자의 벽시계 기준이어야 한다.
    // 실패해도 알림 때문에 앱이 죽으면 안 되므로 서울로 폴백한다 (한국 전용 앱 + DST 없음).
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // 권한은 여기서 요청하지 않는다 — 프라이밍 화면·설정 토글이 맥락과 함께 물어본다.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      for (final kind in NotificationKind.values) {
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            kind.channelId,
            kind.channelName,
            description: kind.channelDescription,
            importance: Importance.defaultImportance,
          ),
        );
      }
    }
    _ready = true;
  }

  /// 시스템 권한을 요청한다. 승인되면 true.
  ///
  /// ⚠️ **Android 13+ 는 한 번 거부하면 시스템 다이얼로그가 다시 뜨지 않는다** — 그때부터는 계속
  /// false 가 돌아오므로, 호출부는 "설정에서 켜주세요" 안내로 갈아타야 한다.
  Future<bool> requestPermission() async {
    await init();
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  /// 지금 알림을 띄울 수 있는 상태인가. 판정을 못 하는 플랫폼에선 true 로 본다(막지 않는다).
  Future<bool> hasPermission() async {
    await init();
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// 계획 하나를 실제로 예약한다. **이미 지난 시각은 조용히 건너뛴다** — 재예약이 전량 취소 후
  /// 다시 걸기라서, 오늘 9시가 지난 뒤 앱을 열면 오늘 것이 과거가 되는 게 정상이다.
  Future<void> schedule(ScheduledNotification item) async {
    await init();
    final when = tz.TZDateTime.from(item.at, tz.local);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id: item.id,
      title: item.title,
      body: item.body,
      scheduledDate: when,
      // ⚠️ inexact 고정. 정확한 알람은 알람시계·캘린더 앱 전용 권한이라 TenK 은 자격이 없다
      // (CLAUDE.md "알림" — SCHEDULE_EXACT_ALARM/USE_EXACT_ALARM 을 선언하지 말 것).
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          item.kind.channelId,
          item.kind.channelName,
          channelDescription: item.kind.channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
