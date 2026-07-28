import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/api_response.dart';
import 'app_version.dart';

/// 백엔드 `/api/app/*` (버전 게이트). 인증 불필요 — 로그인 전 부팅 시점에 호출하므로 rawDio 사용.
///
/// 최신/권장/강제 판정은 **서버가 진실의 원천**(재배포 없이 SQL 로 정책을 바꾸기 위함).
/// 클라는 상태만 받아 화면을 분기하고, 버전 비교(semver)를 자체적으로 하지 않는다.
class AppApi {
  AppApi({required Dio rawDio}) : _dio = rawDio;

  final Dio _dio;

  String? _cachedVersion;
  AppVersionInfo? _lastKnown;

  /// 이미 읽어둔 현재 버전 (없으면 null). 동기라 첫 프레임에 그대로 그릴 수 있다.
  String? get cachedVersion => _cachedVersion;

  /// **마지막으로 성공한** 버전 판정. 앱 시작 때 SessionGate 가 채우므로 메뉴 등 이후 화면은
  /// 같은 걸 다시 묻지 않고 이 값을 첫 프레임에 그대로 쓴다 (버전 정책은 릴리스 때만 바뀌므로
  /// 한 세션 동안 stale 해도 무해하고, 콜드 스타트마다 다시 확인한다).
  ///
  /// 실패(unknown)는 캐시하지 않아 여기 null 로 남는다 — 그 자체가 "재확인 대상" 표시다.
  AppVersionInfo? get lastKnownVersion => _lastKnown;

  /// 현재 앱 버전(예 "1.0.0"). pubspec `version` 의 이름 부분 (빌드번호 제외).
  Future<String> currentVersion() async {
    return _cachedVersion ??= (await PackageInfo.fromPlatform()).version;
  }

  /// 버전 게이트 상태 조회. 네트워크·서버 오류 시 [AppVersionInfo.unknown] 으로 fail-open —
  /// 서버가 안 붙는다고 앱을 잠그지 않는다.
  Future<AppVersionInfo> checkVersion() async {
    try {
      final version = await currentVersion();
      final platform = Platform.isIOS ? 'ios' : 'android';
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/app/version',
        queryParameters: {'platform': platform, 'currentVersion': version},
      );
      return _lastKnown = AppVersionInfo.fromJson(unwrapData(res.data));
    } catch (_) {
      return AppVersionInfo.unknown; // 캐시하지 않는다 — 다음 기회에 다시 확인하기 위해.
    }
  }
}
