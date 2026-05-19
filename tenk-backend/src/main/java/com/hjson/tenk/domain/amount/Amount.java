package com.hjson.tenk.domain.amount;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
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
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

/**
 * 지출/무지출 기록.
 *
 * <p>날짜 의미 구분:
 * <ul>
 *   <li>{@code spentDt}: 사용자가 고른 "지출이 발생한 일시" (배지·집계의 기준 — 날짜만 추출해서 사용).
 *       날짜 부분은 챌린지 기간 안이어야 함.</li>
 *   <li>{@code createdDt}: 서버 자동 기록(JPA Auditing). 감사 용도이며 도메인 로직에서 직접 쓰지 않는다.</li>
 * </ul>
 */
@Getter
@Entity
@Table(name = "amount")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
public class Amount {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "amount_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "challenge_id", nullable = false)
    private Challenge challenge;

    @Column(name = "category", length = 255)
    private String category;

    @Column(name = "content", length = 255)
    private String content;

    @Column(name = "amount", nullable = false)
    private int amount;

    @Column(name = "is_no_spend", nullable = false)
    private boolean noSpend;

    @Column(name = "spent_dt", nullable = false)
    private LocalDateTime spentDt;

    @CreatedDate
    @Column(name = "created_dt", nullable = false, updatable = false)
    private LocalDateTime createdDt;

    private Amount(Challenge challenge, String category, String content, int amount, boolean noSpend, LocalDateTime spentDt) {
        this.challenge = challenge;
        this.category = category;
        this.content = content;
        this.amount = amount;
        this.noSpend = noSpend;
        this.spentDt = spentDt;
    }

    public static Amount spend(Challenge challenge, String category, String content, int amount, LocalDateTime spentDt) {
        validateDateInChallenge(challenge, spentDt);
        if (amount <= 0) {
            throw new BusinessException(ErrorCode.AMOUNT_INVALID_SPEND_VALUE);
        }
        if (isBlank(category) || isBlank(content)) {
            throw new BusinessException(ErrorCode.AMOUNT_CATEGORY_CONTENT_REQUIRED);
        }
        return new Amount(challenge, category, content, amount, false, spentDt);
    }

    public static Amount noSpend(Challenge challenge, LocalDateTime spentDt) {
        validateDateInChallenge(challenge, spentDt);
        return new Amount(challenge, null, null, 0, true, spentDt);
    }

    public void update(String category, String content, int amount) {
        if (this.noSpend) {
            if (amount != 0) {
                throw new BusinessException(ErrorCode.AMOUNT_INVALID_NO_SPEND_VALUE);
            }
            this.category = null;
            this.content = null;
            this.amount = 0;
            return;
        }
        if (amount <= 0) {
            throw new BusinessException(ErrorCode.AMOUNT_INVALID_SPEND_VALUE);
        }
        if (isBlank(category) || isBlank(content)) {
            throw new BusinessException(ErrorCode.AMOUNT_CATEGORY_CONTENT_REQUIRED);
        }
        this.category = category;
        this.content = content;
        this.amount = amount;
    }

    private static void validateDateInChallenge(Challenge challenge, LocalDateTime dt) {
        if (dt == null || !challenge.containsDate(dt.toLocalDate())) {
            throw new BusinessException(ErrorCode.AMOUNT_DATE_OUT_OF_RANGE);
        }
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
