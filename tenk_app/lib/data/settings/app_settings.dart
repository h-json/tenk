import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  AppSettings._(this._prefs, this._soundEnabled, this._hapticsEnabled);

  static const _soundKey = 'settings.soundEnabled';
  static const _hapticsKey = 'settings.hapticsEnabled';

  /// 최초 실행 기본값은 둘 다 켜짐 — 축하 연출이 앱의 페이오프라 기본이 무음이면
  /// 대부분의 사용자가 그 존재를 모른 채 지나간다.
  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings._(
      prefs,
      prefs.getBool(_soundKey) ?? true,
      prefs.getBool(_hapticsKey) ?? true,
    );
  }

  final SharedPreferences _prefs;
  bool _soundEnabled;
  bool _hapticsEnabled;

  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;

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
