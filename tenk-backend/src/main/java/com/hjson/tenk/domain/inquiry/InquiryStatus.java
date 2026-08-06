package com.hjson.tenk.domain.inquiry;

/**
 * 문의 처리 상태. <b>관리자 UI 는 없다</b> — TESTER 승격·앱 버전 정책과 같이 SQL 로 운영한다.
 *
 * <pre>
 * UPDATE inquiry SET status='DONE', handled_dt=NOW() WHERE inquiry_id=?;
 * </pre>
 *
 * <p>이 컬럼이 하는 일은 <b>리마인드를 멈추는 것 하나뿐</b>이다 — {@code PENDING} 이 남아 있으면
 * 매일 저녁 6시에 다시 알린다. <b>파기 기준이 아니다</b>: 문의는 답변 여부와 무관하게
 * <b>회원 탈퇴 시까지</b> 보관하고 계정이 파기될 때 함께 지워진다 (2026-08-06 변경 —
 * 그 전에는 "답변 후 3개월" 배치가 있었다).
 */
public enum InquiryStatus {

    /** 아직 답변하지 않음. 매일 리마인드 대상. */
    PENDING,

    /** 답변 완료. 리마인드에서 빠질 뿐 데이터는 계정과 함께 남는다. */
    DONE
}
