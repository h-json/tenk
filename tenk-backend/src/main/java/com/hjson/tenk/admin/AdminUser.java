package com.hjson.tenk.admin;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

/**
 * 관리자 패널 로그인 계정. <b>{@code user} 테이블과 일부러 분리했다.</b>
 *
 * <p>운영자 자격증명과 이용자 계정은 <b>생명주기가 아예 다르다</b>. 이용자 계정은
 * 가입 → 동의 → 연령 확인 → 탈퇴 → 1개월 후 파기라는 규제 파이프라인을 타고, 그 불변식들이
 * {@code user} 의 컬럼·배치·게이트에 박혀 있다. 운영자는 그중 어느 것도 타지 않는다.
 *
 * <p>⚠️ <b>관리자를 {@code user} 행으로 만들지 말 것.</b> 구체적으로 이런 일이 벌어진다:
 * <ul>
 *   <li>{@code (provider, provider_user_id)} 가 NOT NULL + UNIQUE 라 <b>가짜 공급자 값</b>이
 *       필요해진다 — {@code AuthProvider.TEST} 가 정확히 그렇게 생겼다가 지금 {@code @Deprecated}
 *       잔재로 남아 있다.</li>
 *   <li>그 행은 그때부터 이용자용 불변식에 전부 참여한다 — 동의 미완({@code consentRequired}),
 *       연령 미확인({@code ageVerificationRequired}), 파기 배치 스캔 대상, 사용자 통계 오염.</li>
 *   <li>{@code user.email} 은 2026-07-26 에 <b>수집 자체를 접으며 DROP 한 컬럼</b>이다
 *       (schema.sql 에 되돌릴 때의 체크리스트까지 붙어 있다). 운영자용으로 되살리면 그 결정이
 *       흐려지고 다음 사람이 "이메일을 수집한다"로 읽는다.</li>
 * </ul>
 *
 * <p>나중에 <b>이용자용 자체 계정(이메일+비밀번호)</b>이 생기면 그때 {@code user} 에 컬럼을 추가한다 —
 * 그 시점엔 privacy.html 수집표·Play 데이터 안전 갱신이 어차피 함께 따라오므로 지금 미리 넣어도
 * 그 작업이 면제되지 않는다. 두 테이블은 중복이 아니라 <b>성격이 다른 것</b>이다.
 *
 * <p>{@code UserRole.ADMIN} 과도 별개 축이다 — 저쪽은 <i>이용자</i> 계정에 관리 권한을 줄 때의
 * 자리이고, 이 테이블은 패널 로그인 수단이다.
 */
@Getter
@Entity
@Table(name = "admin_user")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
public class AdminUser {

    public static final int EMAIL_MAX_LENGTH = 100;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "admin_user_id")
    private Long id;

    /** 로그인 ID. 이용자 이메일이 아니라 <b>운영자 연락처</b>라 개인정보 수집표의 대상이 아니다. */
    @Column(name = "email", nullable = false, unique = true, length = EMAIL_MAX_LENGTH)
    private String email;

    /** BCrypt 해시. <b>평문을 저장하지 말 것</b> — 계정 생성은 {@code AdminAccountInitializer} 를 거친다. */
    @Column(name = "password_hash", nullable = false, length = 100)
    private String passwordHash;

    @CreatedDate
    @Column(name = "created_dt", nullable = false, updatable = false)
    private LocalDateTime createdDt;

    /** 마지막 로그인 시각. 계정이 실제로 쓰이는지, 낯선 시각에 로그인이 있었는지 보는 최소 단서다. */
    @Column(name = "last_login_dt")
    private LocalDateTime lastLoginDt;

    private AdminUser(String email, String passwordHash) {
        this.email = email;
        this.passwordHash = passwordHash;
    }

    /** @param passwordHash 이미 인코딩된 해시. 평문을 넘기지 않도록 호출부가 책임진다. */
    public static AdminUser of(String email, String passwordHash) {
        return new AdminUser(email.trim().toLowerCase(), passwordHash);
    }

    public void changePasswordHash(String passwordHash) {
        this.passwordHash = passwordHash;
    }

    public void markLoggedIn(LocalDateTime now) {
        this.lastLoginDt = now;
    }
}
