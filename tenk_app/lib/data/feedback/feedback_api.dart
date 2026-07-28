import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 백엔드 `/api/feedback`. 인증 필요(authDio) — 토큰은 스팸 차단용 통과 조건이고,
/// **누가 보냈는지는 서버에 저장되지 않는다**(익명).
///
/// 진단 정보(앱 버전·플랫폼·OS)는 여기서 직접 모아 함께 보낸다. 화면이 조립하게 하면
/// 새 진입점이 생길 때마다 빠뜨리기 쉬워서 데이터 층에 묶어뒀다. 수집에 실패해도
/// 전송은 그대로 진행한다 — 부가 정보 때문에 의견이 안 가는 게 훨씬 나쁘다.
class FeedbackApi {
  FeedbackApi({required Dio authDio}) : _dio = authDio;

  final Dio _dio;

  /// [type] 은 서버 `FeedbackType` enum 코드. [replyEmail] 은 선택 —
  /// 적은 경우에만 답변 대상이 된다(빈 문자열은 서버가 null 로 정규화).
  Future<void> submit({
    required String type,
    required String content,
    String? replyEmail,
  }) async {
    final diagnostics = await _collectDiagnostics();
    await _dio.post('/api/feedback', data: {
      'type': type,
      'content': content,
      'replyEmail': replyEmail,
      ...diagnostics,
    });
  }

  Future<Map<String, String?>> _collectDiagnostics() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return {
        'appVersion': info.version,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'osVersion': Platform.operatingSystemVersion,
      };
    } catch (_) {
      return const {}; // 진단 정보 없이라도 의견은 보낸다.
    }
  }
}
