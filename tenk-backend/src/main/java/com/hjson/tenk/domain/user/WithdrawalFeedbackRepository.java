package com.hjson.tenk.domain.user;

import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 탈퇴 사유 저장소. 익명 데이터라 계정 파기 배치
 * ({@link WithdrawnUserPurgeService})의 삭제 대상이 아니다 — 지우지 말 것.
 */
public interface WithdrawalFeedbackRepository extends JpaRepository<WithdrawalFeedback, Long> {
}
