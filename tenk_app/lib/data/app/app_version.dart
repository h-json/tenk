import 'package:flutter/foundation.dart';

/// 클라 버전을 서버 정책과 비교한 결과. `unknown` 은 서버 확인 실패 시 fail-open 값.
enum AppVersionStatus { latest, updateAvailable, updateRequired, unknown }

/// `GET /api/app/version` 응답 + fail-open 기본값.
@immutable
class AppVersionInfo {
  const AppVersionInfo({
    required this.status,
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.storeUrl,
  });

  final AppVersionStatus status;
  final String? latestVersion;
  final String? minSupportedVersion;
  final String? storeUrl;

  bool get updateRequired => status == AppVersionStatus.updateRequired;
  bool get updateAvailable => status == AppVersionStatus.updateAvailable;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      status: _statusFrom(json['status'] as String?),
      latestVersion: json['latestVersion'] as String?,
      minSupportedVersion: json['minSupportedVersion'] as String?,
      storeUrl: json['storeUrl'] as String?,
    );
  }

  static AppVersionStatus _statusFrom(String? raw) {
    switch (raw) {
      case 'UPDATE_REQUIRED':
        return AppVersionStatus.updateRequired;
      case 'UPDATE_AVAILABLE':
        return AppVersionStatus.updateAvailable;
      case 'LATEST':
        return AppVersionStatus.latest;
      default:
        return AppVersionStatus.unknown;
    }
  }

  /// 서버 확인 실패 시 사용 — 어떤 게이트도 걸지 않는다(사용자를 잠그지 않는다).
  static const AppVersionInfo unknown = AppVersionInfo(
    status: AppVersionStatus.unknown,
    latestVersion: null,
    minSupportedVersion: null,
    storeUrl: null,
  );
}
