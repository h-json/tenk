package com.hjson.tenk.domain.challenge;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.regex.Pattern;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import com.hjson.tenk.domain.user.User;

@Getter
@Entity
@Table(name = "challenge")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
public class Challenge {

    /** 시작일·종료일 포함 최대 30일 (양끝 포함). */
    public static final int MAX_DURATION_DAYS = 30;

    public static final int NAME_MAX_LENGTH = 100;

    /** 제어 문자(\p{Cc}) + 형식 문자(\p{Cf}) 거부 — 닉네임과 동일 정책. */
    private static final Pattern NAME_FORBIDDEN_CHARS = Pattern.compile("[\\p{Cc}\\p{Cf}]");

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "challenge_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "name", nullable = false, length = NAME_MAX_LENGTH)
    private String name;

    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;

    @Column(name = "target_amount", nullable = false)
    private int targetAmount;

    @Enumerated(EnumType.STRING)
    @Column(name = "result", length = 20)
    private ChallengeResult result;

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

    private Challenge(User user, String name, LocalDate startDate, LocalDate endDate, int targetAmount) {
        validatePeriod(startDate, endDate);
        this.user = user;
        this.name = validateAndNormalizeName(name);
        this.startDate = startDate;
        this.endDate = endDate;
        this.targetAmount = targetAmount;
        this.deleted = false;
    }

    public static Challenge create(User user, String name, LocalDate startDate, LocalDate endDate, int targetAmount) {
        return new Challenge(user, name, startDate, endDate, targetAmount);
    }

    /** 결과 확정 전까지만 호출 (게이트는 서비스 책임). 같은 값이어도 멱등하게 통과. */
    public void rename(String name) {
        this.name = validateAndNormalizeName(name);
    }

    /** 종료일이 지난 다음 날부터 "종료"로 본다 (종료일 당일은 아직 진행 중). */
    public boolean isFinished(LocalDate today) {
        return today.isAfter(endDate);
    }

    /** 시작일에 도달하면 시작된 것으로 본다 (시작일 당일 = 진행 중). */
    public boolean isStarted(LocalDate today) {
        return !today.isBefore(startDate);
    }

    public boolean containsDate(LocalDate date) {
        return !date.isBefore(startDate) && !date.isAfter(endDate);
    }

    public void markResult(ChallengeResult result) {
        if (this.result != null) {
            throw new BusinessException(ErrorCode.CHALLENGE_ALREADY_FINISHED);
        }
        this.result = result;
    }

    public void softDelete() {
        this.deleted = true;
        this.deletedDt = LocalDateTime.now();
    }

    private static String validateAndNormalizeName(String raw) {
        if (raw == null) {
            throw new BusinessException(ErrorCode.CHALLENGE_NAME_INVALID);
        }
        String trimmed = raw.trim();
        if (trimmed.isEmpty() || trimmed.length() > NAME_MAX_LENGTH) {
            throw new BusinessException(ErrorCode.CHALLENGE_NAME_INVALID);
        }
        if (NAME_FORBIDDEN_CHARS.matcher(trimmed).find()) {
            throw new BusinessException(ErrorCode.CHALLENGE_NAME_INVALID);
        }
        return trimmed;
    }

    private static void validatePeriod(LocalDate startDate, LocalDate endDate) {
        if (startDate == null || endDate == null) {
            throw new BusinessException(ErrorCode.CHALLENGE_PERIOD_INVALID);
        }
        if (startDate.isBefore(LocalDate.now())) {
            throw new BusinessException(ErrorCode.CHALLENGE_PERIOD_INVALID);
        }
        if (endDate.isBefore(startDate)) {
            throw new BusinessException(ErrorCode.CHALLENGE_PERIOD_INVALID);
        }
        long inclusiveDays = ChronoUnit.DAYS.between(startDate, endDate) + 1;
        if (inclusiveDays > MAX_DURATION_DAYS) {
            throw new BusinessException(ErrorCode.CHALLENGE_PERIOD_INVALID);
        }
    }
}
