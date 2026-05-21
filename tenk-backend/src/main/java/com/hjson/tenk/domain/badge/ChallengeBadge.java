package com.hjson.tenk.domain.badge;

import com.hjson.tenk.domain.challenge.Challenge;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

/**
 * 한 챌린지 안에서 획득한 배지. 같은 사용자가 챌린지 A 와 B 에서 같은 type/condition 의 배지를
 * 얻으면 행이 두 개 생긴다 (각 챌린지에 1:1 로 붙음). 유저 단위 누적(=업적)은 별도 테이블로 추후 추가.
 */
@Getter
@Entity
@Table(
        name = "challenge_badge",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_challenge_badge",
                columnNames = {"challenge_id", "badge_id"}
        )
)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
public class ChallengeBadge {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "challenge_badge_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "challenge_id", nullable = false)
    private Challenge challenge;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "badge_id", nullable = false)
    private Badge badge;

    @CreatedDate
    @Column(name = "created_dt", nullable = false, updatable = false)
    private LocalDateTime createdDt;

    private ChallengeBadge(Challenge challenge, Badge badge) {
        this.challenge = challenge;
        this.badge = badge;
    }

    public static ChallengeBadge create(Challenge challenge, Badge badge) {
        return new ChallengeBadge(challenge, badge);
    }
}
