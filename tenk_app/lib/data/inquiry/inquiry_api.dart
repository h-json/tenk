import 'package:dio/dio.dart';

/// 백엔드 `/api/inquiry`. 인증 필요(authDio).
///
/// **[FeedbackApi] 와 계약이 반대다** — 이쪽은 서버가 **계정과 연결해 저장**한다. 열람·정정·삭제
/// 요구는 "누구의 데이터인가"가 특정돼야 처리할 수 있어서, 익명 폼으로는 애초에 성립하지 않는다.
/// 그래서 [replyEmail] 도 **필수**다 (의견에서는 선택).
///
/// 진단 정보를 붙이지 않는 것도 의도다. 의견은 "어디서 뭐가 깨졌나"를 알아야 고칠 수 있지만
/// 문의는 사람이 읽고 답장하는 글이라 앱 버전·OS 가 필요 없다 — 필요 없는 정보를 개인정보 테이블에
/// 같이 쌓지 않는다.
class InquiryApi {
  InquiryApi({required Dio authDio}) : _dio = authDio;

  final Dio _dio;

  /// [type] 은 서버 `InquiryType` enum 코드.
  Future<void> submit({
    required String type,
    required String content,
    required String replyEmail,
  }) async {
    await _dio.post('/api/inquiry', data: {
      'type': type,
      'content': content,
      'replyEmail': replyEmail,
    });
  }
}
