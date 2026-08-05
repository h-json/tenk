/// 법적 고지 문서 URL. 백엔드가 static 으로 서빙하며 (SecurityConfig PERMIT_ALL),
/// 가입 동의 화면·로그인 화면에서 [url_launcher] 로 외부 브라우저에 띄운다.
///
/// API base URL 과 무관한 고정 도메인 — 문서는 배포 서버에서만 서빙되므로 로컬/에뮬레이터
/// 빌드에서도 이 배포 주소를 그대로 연다.
const String termsUrl = 'https://tenk.hjson248.com/terms.html';
const String privacyPolicyUrl = 'https://tenk.hjson248.com/privacy.html';

/// 문의처 이메일 = **받는 주소**. [privacy.html] 보호책임자 항목 / [terms.html] 문의처 조항 /
/// [delete-account.html] 에 적힌 값과 반드시 같아야 한다 — 고지한 창구와 앱이 여는 창구가
/// 다르면 안 된다. 서비스 전용 계정이며 개발자 개인 메일이 아니다.
///
/// ⚠️ **보내는 주소와 다르다.** 서버가 문의·의견 도착 알림을 쏠 때 쓰는 SMTP 발신 계정은
/// `system.tenk@`(`spring.mail.username`)이고, 그 알림이 도착하는 곳이자 사용자가 메일을 보낼
/// 곳이 이 `support.tenk@`(`tenk.notify.mail.to`)다. 둘을 같은 값으로 합치지 말 것.
///
/// 앱 안에는 두 창구가 있고 **이 주소는 어느 쪽도 아닌 세 번째 경로**다:
/// '고객센터 → 문의하기'(계정 연결)와 '고객센터 → 의견 보내기'(익명) 폼이 앱 안을 담당하고,
/// 이 주소는 **앱에 들어올 수 없는 사람**(탈퇴 후·로그인 불가·설치 전)을 위해 문서에 고지된
/// 창구다. 그래서 폼이 생겼다고 지우면 안 된다.
const String supportEmail = 'support.tenk@gmail.com';
