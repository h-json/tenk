package com.hjson.tenk.domain.user;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDate;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

@Getter
@Entity
@Table(
        name = "user",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_user_provider",
                columnNames = {"provider", "provider_user_id"}
        )
)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@jakarta.persistence.EntityListeners(AuditingEntityListener.class)
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_id")
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(name = "provider", nullable = false, length = 20)
    private AuthProvider provider;

    @Column(name = "provider_user_id", nullable = false, length = 255)
    private String providerUserId;

    // 이메일은 수집하지 않는다 (2026-07-26). 카카오 '카카오계정(이메일)' 동의항목은 개인 개발자
    // 일반 앱에선 '권한 없음'이라 애초에 내려오지 않았고, 서비스 기능 어디에도 쓰이지 않아
    // (표시 한 곳뿐이었음) 비즈 앱 전환으로 받아올 이유가 없다고 판단 — 개인정보 최소수집 원칙.
    // 컬럼도 DROP 했다. 되살릴 거면 schema.sql·privacy.html·Play 데이터 안전을 함께 갱신할 것.

    @Column(name = "nickname", nullable = false, length = 255)
    private String nickname;

    // 사용자가 직접 닉네임을 변경한 마지막 시각. NULL = 한 번도 변경 안 함 (가입 시점의 카카오 닉네임 그대로).
    // 24시간 1회 제한은 UserService 가 이 값 + NICKNAME_CHANGE_COOLDOWN 과 현재 시각을 비교해 검증.
    @Column(name = "nickname_changed_dt")
    private LocalDateTime nicknameChangedDt;

    // 필수 동의 시각. NULL = 아직 동의 안 함 → 클라이언트가 동의 화면으로 게이트.
    // 이용약관/개인정보 수집·이용 동의를 각각 기록 (감사·약관 개정 재동의 대비 분리 보관).
    @Column(name = "terms_agreed_dt")
    private LocalDateTime termsAgreedDt;

    @Column(name = "privacy_agreed_dt")
    private LocalDateTime privacyAgreedDt;

    // 연령 확인 화면에서 사용자가 입력한 생년월일. NULL = 아직 연령 확인 안 함 → 클라이언트가 연령 확인 화면으로 게이트.
    // 만 14세 미만 값은 애초에 저장되지 않는다 (UserService.verifyAge 가 계정을 즉시 파기하고 거부).
    @Column(name = "birth_date")
    private LocalDate birthDate;

    // 성별 — 선택 입력. NULL = 미입력(정상 상태). 서비스 기능에는 쓰이지 않고 통계 목적으로만 보관한다.
    // '내 정보' 화면에서만 입력·해제하며 가입 흐름에서는 묻지 않는다.
    @Enumerated(EnumType.STRING)
    @Column(name = "gender", length = 10)
    private Gender gender;

    // 계정 권한. 기본 USER, 내부 테스터만 DB 에서 TESTER 로 승격(테스트 데이터 시딩 권한).
    // 앱에는 승격 경로가 없다 — SQL 로 직접 부여한다.
    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false, length = 20)
    private UserRole role = UserRole.USER;

    @CreatedDate
    @Column(name = "created_dt", nullable = false, updatable = false)
    private LocalDateTime createdDt;

    @LastModifiedDate
    @Column(name = "updated_dt", nullable = false)
    private LocalDateTime updatedDt;

    @Column(name = "is_deleted", nullable = false)
    private boolean deleted;

    @Column(name = "deleted_dt")
    private LocalDateTime deletedDt;

    private User(AuthProvider provider, String providerUserId, String nickname) {
        this.provider = provider;
        this.providerUserId = providerUserId;
        this.nickname = nickname;
        this.deleted = false;
    }

    public static User create(AuthProvider provider, String providerUserId, String nickname) {
        return new User(provider, providerUserId, nickname);
    }

    /**
     * 닉네임 변경. {@code now} 가 nicknameChangedDt 로 박혀 "24시간 1회" 제한 산정 기준이 된다.
     * 기존 닉네임과 동일하면 no-op — 가입 화면에서 카카오 닉네임 그대로 두고 '확인' 누른 케이스가
     * 의도치 않게 1회 변경으로 카운트되는 걸 막는다.
     */
    public void changeNickname(String nickname, LocalDateTime now) {
        if (nickname == null || nickname.isBlank()) {
            return;
        }
        if (nickname.equals(this.nickname)) {
            return;
        }
        this.nickname = nickname;
        this.nicknameChangedDt = now;
    }

    public void withdraw() {
        this.deleted = true;
        this.deletedDt = LocalDateTime.now();
    }

    /**
     * 필수 동의(이용약관 + 개인정보 수집·이용)를 기록한다. 이미 동의한 항목은 최초 동의 시각을
     * 보존하기 위해 덮어쓰지 않는다 (멱등). 신규 동의 항목만 {@code now} 로 스탬프.
     */
    public void agreeToRequiredConsents(LocalDateTime now) {
        if (this.termsAgreedDt == null) {
            this.termsAgreedDt = now;
        }
        if (this.privacyAgreedDt == null) {
            this.privacyAgreedDt = now;
        }
    }

    /** 필수 동의를 모두 마쳤는지. false 면 클라이언트가 동의 화면으로 게이트한다. */
    public boolean hasAgreedToRequiredConsents() {
        return termsAgreedDt != null && privacyAgreedDt != null;
    }

    /**
     * 연령 확인 결과(생년월일)를 기록한다. 최소 연령 검증은 {@link UserService#verifyAge} 가 하고,
     * 여기까지 온 값은 이미 이용 가능 연령임이 확인된 값이다.
     */
    public void verifyAge(LocalDate birthDate) {
        this.birthDate = birthDate;
    }

    /** 연령 확인을 마쳤는지. false 면 클라이언트가 연령 확인 화면으로 게이트한다. */
    public boolean hasVerifiedAge() {
        return birthDate != null;
    }

    /** 성별 설정. {@code null} 을 넘기면 미입력으로 되돌린다 (수집 철회 경로 — 막지 말 것). */
    public void changeGender(Gender gender) {
        this.gender = gender;
    }
}
