/// 법적 고지 문서 URL. 백엔드가 static 으로 서빙하며 (SecurityConfig PERMIT_ALL),
/// 가입 동의 화면·로그인 화면에서 [url_launcher] 로 외부 브라우저에 띄운다.
///
/// API base URL 과 무관한 고정 도메인 — 문서는 배포 서버에서만 서빙되므로 로컬/에뮬레이터
/// 빌드에서도 이 배포 주소를 그대로 연다.
const String termsUrl = 'https://tenk.hjson248.com/terms.html';
const String privacyPolicyUrl = 'https://tenk.hjson248.com/privacy.html';

/// 문의처 이메일. **[privacy.html] 개인정보 보호책임자 항목 / [terms.html] 문의처 조항에 적힌
/// 주소와 반드시 같은 값**이어야 한다 — 고지한 창구와 앱이 여는 창구가 다르면 안 된다.
/// (일반적인 의견은 앱 안의 '의견 보내기'로 받는다. 여기는 답변이 필요한 문의·개인정보 요구용.)
const String supportEmail = 'h.json248@gmail.com';
