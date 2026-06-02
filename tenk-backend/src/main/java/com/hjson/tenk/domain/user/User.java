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

    @Column(name = "email", length = 255)
    private String email;

    @Column(name = "nickname", nullable = false, length = 255)
    private String nickname;

    // 사용자가 직접 닉네임을 변경한 마지막 시각. NULL = 한 번도 변경 안 함 (가입 시점의 카카오 닉네임 그대로).
    // 하루 1회 제한은 UserService 에서 이 값과 LocalDate.now() 를 비교해 검증.
    @Column(name = "nickname_changed_dt")
    private LocalDateTime nicknameChangedDt;

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

    private User(AuthProvider provider, String providerUserId, String email, String nickname) {
        this.provider = provider;
        this.providerUserId = providerUserId;
        this.email = email;
        this.nickname = nickname;
        this.deleted = false;
    }

    public static User create(AuthProvider provider, String providerUserId, String email, String nickname) {
        return new User(provider, providerUserId, email, nickname);
    }

    public void updateEmail(String email) {
        if (email != null) {
            this.email = email;
        }
    }

    /**
     * 닉네임 변경. {@code now} 가 nicknameChangedDt 로 박혀 "하루 1회" 제한 산정 기준이 된다.
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
}
