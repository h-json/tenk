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
      return AppVersionInfo.fromJson(unwrapData(res.data));
    } catch (_) {
      return AppVersionInfo.unknown;
    }
  }
}
