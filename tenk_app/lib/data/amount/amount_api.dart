import 'dart:convert';

import 'package:dio/dio.dart';

import '../api/api_response.dart';
import 'amount.dart';

/// 백엔드 `/api/challenges/{id}/amounts/*` 호출. 모두 인증 필요.
///
/// 기록 추가는 multipart/form-data. `request` part는 JSON, `video` part는 파일.
/// 백엔드 컨트롤러가 `@RequestPart("request") AmountCreateRequest` + `@RequestPart("video") MultipartFile`로 받음.
class AmountApi {
  AmountApi({required Dio authDio}) : _dio = authDio;

  final Dio _dio;

  Future<Amount> record({
    required int challengeId,
    required bool noSpend,
    required DateTime dateTime,
    String? category,
    String? content,
    int? amount,
    String? videoPath,
  }) async {
    final requestJson = jsonEncode({
      'category': category,
      'content': content,
      'amount': amount,
      'noSpend': noSpend,
      'dateTime': _formatLocalDateTime(dateTime),
    });
    final parts = <String, dynamic>{
      // 백엔드가 `request` part의 Content-Type을 application/json으로 기대 → MultipartFile.fromString + contentType 명시.
      'request': MultipartFile.fromString(
        requestJson,
        contentType: DioMediaType('application', 'json'),
      ),
    };
    if (videoPath != null) {
      parts['video'] = await MultipartFile.fromFile(
        videoPath,
        contentType: DioMediaType('video', 'mp4'),
      );
    }
    final form = FormData.fromMap(parts);
    final res = await _dio.post(
      '/api/challenges/$challengeId/amounts',
      data: form,
    );
    return Amount.fromJson(unwrapData(res.data));
  }

  Future<List<Amount>> list(int challengeId) async {
    final res = await _dio.get('/api/challenges/$challengeId/amounts');
    return unwrapList(res.data).map(Amount.fromJson).toList(growable: false);
  }

  Future<void> delete({required int challengeId, required int amountId}) async {
    await _dio.delete('/api/challenges/$challengeId/amounts/$amountId');
  }

  /// 백엔드 `LocalDateTime`은 타임존 없는 `yyyy-MM-ddTHH:mm:ss`를 기대.
  /// `DateTime.toIso8601String()`은 UTC면 `Z`를 붙여 파서를 깨므로 직접 포맷한다.
  static String _formatLocalDateTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}T'
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
