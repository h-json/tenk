import 'package:dio/dio.dart';

/// 백엔드 `ApiResponse.error` envelope을 풀어 사용자 친화적 메시지로 변환한 예외.
class ApiException implements Exception {
  const ApiException(this.code, this.message);

  final String? code;
  final String message;

  @override
  String toString() => message;
}

/// 서버 envelope이 없을 때 쓰는 폴백 문구.
///
/// dio의 `message`와 Dart 예외의 `toString()`은 영문이라 **그대로 노출하면 한국어 화면이 영문으로 덮인다**.
/// 그래서 원문은 절대 쓰지 않고 원인별 한국어로 갈아끼운다. 원인을 뭉뚱그리지 않는 이유는
/// "인터넷이 끊긴 것"과 "서버가 느린 것"에 대해 사용자가 할 수 있는 행동이 다르기 때문.
const String networkErrorMessage = '인터넷 연결을 확인해 주세요.';
const String timeoutErrorMessage = '응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.';
const String unknownErrorMessage = '일시적인 오류가 발생했어요. 잠시 후 다시 시도해 주세요.';

/// 백엔드 응답이 `{success:false, error:{code,message}}`이면 그 안의 message를 꺼내고,
/// 그 외에는 위 폴백 문구로 바꾼다. UI에서 catch한 객체를 그대로 던져넣어도 안전.
///
/// 한국어 메시지를 자체적으로 들고 있는 예외(`GalException`·`VideoComposeFailed`·
/// `WithdrawnAccountException` 등)는 호출부가 `on XxxException catch`로 **먼저** 잡는다 —
/// 여기까지 흘러오는 건 정체를 모르는 예외뿐이라 원문을 버려도 잃는 정보가 없다.
ApiException toApiException(Object error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map<String, dynamic>) {
      final err = body['error'];
      if (err is Map<String, dynamic>) {
        return ApiException(
          err['code'] as String?,
          (err['message'] as String?) ?? unknownErrorMessage,
        );
      }
    }
    return ApiException(null, _messageForDioType(error.type));
  }
  return const ApiException(null, unknownErrorMessage);
}

String _messageForDioType(DioExceptionType type) => switch (type) {
      // 인증서 오류도 연결 문제로 묶는다 — 공용 와이파이의 캡티브 포털이 흔한 원인이라
      // 사용자가 취할 행동("연결을 확인")이 연결 실패와 같다.
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate =>
        networkErrorMessage,
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        timeoutErrorMessage,
      // 사용자가 스스로 취소한 것이라 실패로 알리지 않는다.
      // (정상 흐름이면 호출부가 `CancelToken.isCancel`로 먼저 걸러낸다.)
      DioExceptionType.cancel => '요청을 취소했어요.',
      DioExceptionType.badResponse ||
      DioExceptionType.unknown =>
        unknownErrorMessage,
    };
