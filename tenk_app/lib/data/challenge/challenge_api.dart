import 'package:dio/dio.dart';

import '../api/api_response.dart';
import 'challenge.dart';

/// 백엔드 `/api/challenges/*` 호출. 모두 인증 필요 → [_dio]는 인터셉터가 부착된 authDio.
class ChallengeApi {
  ChallengeApi({required Dio authDio}) : _dio = authDio;

  final Dio _dio;

  Future<Challenge> create({
    String? name,
    required DateTime startDate,
    required DateTime endDate,
    required int targetAmount,
  }) async {
    final trimmed = name?.trim();
    final res = await _dio.post(
      '/api/challenges',
      data: {
        // 비우면 서버가 "챌린지 N" 기본값을 만든다 — 빈 값은 아예 전송하지 않음.
        if (trimmed != null && trimmed.isNotEmpty) 'name': trimmed,
        'startDate': _formatDate(startDate),
        'endDate': _formatDate(endDate),
        'targetAmount': targetAmount,
      },
    );
    return Challenge.fromJson(unwrapData(res.data));
  }

  /// 이름 변경 (결과 확정 전까지만 서버가 허용 — 확정 후엔 CHALLENGE_ALREADY_FINISHED).
  Future<Challenge> rename(int challengeId, String name) async {
    final res = await _dio.patch(
      '/api/challenges/$challengeId',
      data: {'name': name.trim()},
    );
    return Challenge.fromJson(unwrapData(res.data));
  }

  Future<List<Challenge>> list({bool activeOnly = false}) async {
    final res = await _dio.get(
      '/api/challenges',
      queryParameters: {'activeOnly': activeOnly},
    );
    return unwrapList(res.data)
        .map(Challenge.fromJson)
        .toList(growable: false);
  }

  Future<Challenge> getOne(int challengeId) async {
    final res = await _dio.get('/api/challenges/$challengeId');
    return Challenge.fromJson(unwrapData(res.data));
  }

  Future<Challenge> finalize(int challengeId) async {
    final res = await _dio.post('/api/challenges/$challengeId/finalize');
    return Challenge.fromJson(unwrapData(res.data));
  }

  Future<void> delete(int challengeId) async {
    await _dio.delete('/api/challenges/$challengeId');
  }

  /// 백엔드 `LocalDate`는 `yyyy-MM-dd`를 기대. `DateTime.toIso8601String()`은 시각·타임존이 붙어
  /// 파서가 깨질 수 있으므로 직접 포맷.
  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }
}
