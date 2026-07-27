package com.hjson.tenk.domain.user.dto;

import com.hjson.tenk.domain.user.WithdrawalFeedback;
import com.hjson.tenk.domain.user.WithdrawalReason;
import jakarta.validation.constraints.Size;

/**
 * 회원 탈퇴 요청. <b>두 필드 모두 선택</b>이고 body 자체를 생략해도 된다 —
 * 사유를 필수로 만들면 탈퇴가 가입보다 어려워진다.
 *
 * @param reason 탈퇴 사유 코드. null 이면 기록하지 않는다.
 * @param detail '기타' 를 고른 경우의 자유 서술. 다른 사유와 함께 오면 엔티티가 버린다.
 */
public record WithdrawRequest(
        WithdrawalReason reason,
        @Size(max = WithdrawalFeedback.DETAIL_MAX_LENGTH, message = "자세한 내용은 200자까지 쓸 수 있어요.")
        String detail
) {}
