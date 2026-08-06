package com.hjson.tenk.admin;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 관리자 패널 설정.
 *
 * <p><b>{@code account} 는 yaml 이 진실의 원천이다</b> — 부팅할 때마다 그 계정을 만들거나(없으면)
 * 비밀번호 해시를 다시 맞춘다({@code AdminAccountInitializer}). 이 프로젝트의 다른 자격증명
 * (jwt secret · SMTP 앱 비밀번호 · 텔레그램 토큰)과 같은 방식이고, private 레포 전제다.
 *
 * <p>그래서 <b>패널에 비밀번호 변경 화면을 두지 않았다</b> — 뒀다면 다음 재부팅에 yaml 값으로
 * 되돌아가 "바꿨는데 안 바뀐다"가 된다. 비밀번호를 바꾸려면 여기 값을 고치고 재시작할 것.
 *
 * <p>계정이 여러 명이 되면 그때 이 규칙을 다시 볼 것 — 테이블({@code admin_user})은 이미 여러 행을
 * 담을 수 있게 돼 있고, 부팅 동기화 대상은 <b>여기 적힌 그 한 계정뿐</b>이라 손으로 추가한 다른
 * 행은 건드리지 않는다.
 *
 * @param enabled 패널 활성화 여부. 꺼두면 보안 체인이 등록되지 않아 {@code /admin/**} 이 401 로 끊긴다.
 * @param account 부팅 시 보장할 계정. {@code enabled} 라도 비어 있으면 아무 계정도 만들지 않는다.
 * @param baseUrl 알림 본문에 넣을 패널 주소 (예 {@code https://tenk.hjson248.com}). 서버는 자기 공개
 *                주소를 알 수 없고 알림은 요청 밖(스케줄러)에서도 나가므로 설정으로 받는다.
 *                비우면 링크 없이 안내만 나간다 — <b>알림이 실패하지는 않는다</b>.
 */
@ConfigurationProperties(prefix = "tenk.admin")
public record AdminProperties(boolean enabled, Account account, String baseUrl) {

    public AdminProperties {
        if (account == null) {
            account = new Account(null, null);
        }
    }

    /** @return 패널 링크. 설정이 없으면 {@code null} — 호출부가 링크 줄을 통째로 생략한다. */
    public String panelUrl(String path) {
        if (baseUrl == null || baseUrl.isBlank()) {
            return null;
        }
        String trimmed = baseUrl.trim();
        String base = trimmed.endsWith("/") ? trimmed.substring(0, trimmed.length() - 1) : trimmed;
        return base + path;
    }

    /** @param password <b>평문</b>. 저장은 BCrypt 해시로만 된다. */
    public record Account(String email, String password) {
        public boolean isUsable() {
            return email != null && !email.isBlank()
                    && password != null && !password.isBlank();
        }
    }
}
