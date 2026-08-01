import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notification/notification_prefs.dart';

/// 앱 동작 환경 설정 — 효과음·진동 on/off.
///
/// 값이 필요한 쪽이 **재생 직전에 동기로 읽는다.** 구독(리스너)이 없어서 화면 간
/// 공유 상태가 아니고, 그래서 Scope 하나로 충분하다 — Riverpod 도입 트리거에
/// 걸리지 않는다 (CLAUDE.md "레이어 규칙", decisions.md "배지 획득 연출").
///
/// 햅틱은 [HapticFeedback] 을 직접 부르지 말고 여기 헬퍼를 경유할 것. 토글이
/// "진동"이라고 말하는 이상 앱의 모든 진동이 함께 꺼져야 하고, 호출부마다
/// `if (enabled)` 를 복붙하면 새 호출부에서 빠진다.
class AppSettings {
  AppSettings._(
      this._prefs, this._soundEnabled, this._hapticsEnabled, this._notifications);

  static const _soundKey = 'settings.soundEnabled';
  static const _hapticsKey = 'settings.hapticsEnabled';
  static const _notiEnabledKey = 'settings.notifications.enabled';
  static const _notiReminderKey = 'settings.notifications.reminder';
  static const _notiDeadlineKey = 'settings.notifications.deadline';
  static const _notiFinalizeKey = 'settings.notifications.finalize';
  static const _notiHourKey = 'settings.notifications.reminderHour';
  static const _notiMinuteKey = 'settings.notifications.reminderMinute';
  static const _lastRecordedKey = 'settings.lastRecordedDate';

  /// 최초 실행 기본값은 효과음·진동 둘 다 켜짐 — 축하 연출이 앱의 페이오프라 기본이 무음이면
  /// 대부분의 사용자가 그 존재를 모른 채 지나간다.
  ///
  /// **알림 마스터만 기본 꺼짐**이다. 시스템 권한이 곧 opt-in 이라 승인 전에 켜 두면
  /// "켜져 있는데 안 온다" 가 된다.
  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings._(
      prefs,
      prefs.getBool(_soundKey) ?? true,
      prefs.getBool(_hapticsKey) ?? true,
      NotificationPrefs(
        enabled: prefs.getBool(_notiEnabledKey) ?? false,
        reminderEnabled: prefs.getBool(_notiReminderKey) ?? true,
        deadlineEnabled: prefs.getBool(_notiDeadlineKey) ?? true,
        finalizeEnabled: prefs.getBool(_notiFinalizeKey) ?? true,
        reminderHour:
            prefs.getInt(_notiHourKey) ?? NotificationPrefs.defaultReminderHour,
        reminderMinute: prefs.getInt(_notiMinuteKey) ??
            NotificationPrefs.defaultReminderMinute,
      ),
    );
  }

  final SharedPreferences _prefs;
  bool _soundEnabled;
  bool _hapticsEnabled;
  NotificationPrefs _notifications;

  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  NotificationPrefs get notifications => _notifications;

  /// 마지막으로 기록을 남긴 날짜. "오늘 이미 기록했으면 오늘 리마인더는 건너뛴다" 판정에만 쓴다.
  ///
  /// 서버에 묻지 않고 로컬에 두는 이유: **기록은 앱 안에서만 일어나므로** 이 값이 곧 사실이고,
  /// 챌린지마다 상세를 다시 부르는 것보다 훨씬 싸다. 재설치하면 잃지만 그날 리마인더가 한 번 더
  /// 뜨는 정도라 무해하다.
  DateTime? get lastRecordedDate {
    final raw = _prefs.getString(_lastRecordedKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> markRecordedNow() async {
    final now = DateTime.now();
    await _prefs.setString(
      _lastRecordedKey,
      DateTime(now.year, now.month, now.day).toIso8601String(),
    );
  }

  Future<void> setNotifications(NotificationPrefs value) async {
    _notifications = value;
    await _prefs.setBool(_notiEnabledKey, value.enabled);
    await _prefs.setBool(_notiReminderKey, value.reminderEnabled);
    await _prefs.setBool(_notiDeadlineKey, value.deadlineEnabled);
    await _prefs.setBool(_notiFinalizeKey, value.finalizeEnabled);
    await _prefs.setInt(_notiHourKey, value.reminderHour);
    await _prefs.setInt(_notiMinuteKey, value.reminderMinute);
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    await _prefs.setBool(_soundKey, value);
  }

  Future<void> setHapticsEnabled(bool value) async {
    _hapticsEnabled = value;
    await _prefs.setBool(_hapticsKey, value);
  }

  void selectionClick() {
    if (_hapticsEnabled) HapticFeedback.selectionClick();
  }

  void mediumImpact() {
    if (_hapticsEnabled) HapticFeedback.mediumImpact();
  }

  void heavyImpact() {
    if (_hapticsEnabled) HapticFeedback.heavyImpact();
  }
}
