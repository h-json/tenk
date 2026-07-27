package com.hjson.tenk.domain.user;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
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
 * 탈퇴할 때 사용자가 선택한 이유. <b>어느 계정이 남겼는지는 저장하지 않는다.</b>
 *
 * <p>{@code user_id} 를 일부러 두지 않은 게 이 테이블의 핵심이다. 계정과 연결하지 않으면
 * 개인정보가 아니라 <b>익명정보</b>라서 ① 개인정보처리방침 수집표에 항목을 늘리지 않아도 되고
 * ② 보관 기간 논쟁 없이 계속 보존할 수 있으며 ③ 계정이 파기된 뒤에도 통계가 남는다.
 * <b>여기에 user 참조나 식별 가능한 값을 추가하지 말 것</b> — 그 순간 위 셋이 전부 무너진다.
 *
 * <p>{@link #detail} 은 '기타' 를 고른 사용자가 직접 쓴 텍스트라 본인 정보가 섞일 수 있다.
 * 그래서 입력 화면에서 "개인정보는 적지 말아 주세요" 를 고지하고 길이를 제한한다.
 */
@Getter
@Entity
@Table(name = "withdrawal_feedback")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@jakarta.persistence.EntityListeners(AuditingEntityListener.class)
public class WithdrawalFeedback {

    public static final int DETAIL_MAX_LENGTH = 200;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "withdrawal_feedback_id")
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(name = "reason_code", nullable = false, length = 30)
    private WithdrawalReason reason;

    @Column(name = "detail", length = DETAIL_MAX_LENGTH)
    private String detail;

    @CreatedDate
    @Column(name = "created_dt", nullable = false, updatable = false)
    private LocalDateTime createdDt;

    private WithdrawalFeedback(WithdrawalReason reason, String detail) {
        this.reason = reason;
        this.detail = detail;
    }

    /**
     * 사유 1건 기록. {@code detail} 은 trim 후 빈 값이면 null 로 정규화하고 길이를 잘라낸다.
     * 자유 서술은 '기타' 를 고른 경우에만 의미가 있으므로 다른 사유와 함께 오면 버린다
     * (칩만 바꾸고 입력칸이 남아 있던 값이 딸려오는 케이스).
     */
    public static WithdrawalFeedback of(WithdrawalReason reason, String detail) {
        return new WithdrawalFeedback(reason, normalizeDetail(reason, detail));
    }

    private static String normalizeDetail(WithdrawalReason reason, String detail) {
        if (reason != WithdrawalReason.ETC || detail == null) {
            return null;
        }
        String trimmed = detail.trim();
        if (trimmed.isEmpty()) {
            return null;
        }
        return trimmed.length() > DETAIL_MAX_LENGTH ? trimmed.substring(0, DETAIL_MAX_LENGTH) : trimmed;
    }
}
