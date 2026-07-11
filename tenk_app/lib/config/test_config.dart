/// 테스트 전용 기능(카카오 우회 로그인 + 데이터 시딩) 게이팅.
///
/// 빌드 시 `--dart-define=TEST_LOGIN_KEY=...` 로 주입한다. 값은 백엔드 `tenk.test.login-key`
/// 와 같아야 한다. 키가 비어 있으면(=일반/프로덕션 빌드) 테스트 UI 를 전부 숨긴다 —
/// 백엔드 `tenk.test.enabled` 토글과 함께 클라/서버 이중 잠금.
const String testLoginKey = String.fromEnvironment('TEST_LOGIN_KEY', defaultValue: '');

/// 이 빌드에서 테스트 도구(로그인 버튼·시딩 버튼)를 노출할지.
bool get testToolsEnabled => testLoginKey.isNotEmpty;
