import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/legal_config.dart';

/// 문의 메일 앱을 연다. **의견 보내기(앱 내 폼)와 역할이 다르다** —
/// 이쪽은 답변이 필요한 문의와 개인정보 열람·삭제 요구를 접수하는 창구다.
/// 개인정보처리방침·이용약관에 같은 주소를 고지해뒀으므로, 앱 안에서도 닿을 수 있어야 한다.
///
/// 메일 앱이 없거나 열지 못하면 **주소를 클립보드에 복사**하고 그 사실을 알린다 —
/// 아무 일도 일어나지 않는 버튼은 창구가 없는 것과 같다.
///
/// ⚠️ Android 11+ 는 `AndroidManifest.xml` 의 `<queries>` 에 `mailto` scheme 선언이 없으면
/// 이 호출이 조용히 실패한다 (패키지 가시성 제한).
Future<void> openSupportEmail(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri(
    scheme: 'mailto',
    path: supportEmail,
    // Uri.queryParameters 는 공백을 '+' 로 인코딩해 메일 제목에 그대로 보이는 클라이언트가 있어
    // 직접 조립한다.
    query: 'subject=${Uri.encodeComponent('[TenK] 문의')}',
  );

  bool ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (ok) return;

  await Clipboard.setData(const ClipboardData(text: supportEmail));
  messenger.showSnackBar(
    const SnackBar(content: Text('메일 앱을 열 수 없어 주소를 복사했어요: $supportEmail')),
  );
}
