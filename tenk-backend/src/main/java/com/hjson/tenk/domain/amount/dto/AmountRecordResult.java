package com.hjson.tenk.domain.amount.dto;

import com.hjson.tenk.domain.amount.Amount;
import com.hjson.tenk.domain.media.MediaFile;
import java.util.List;

/// 지출/무지출 기록 추가 응답. {@code removedNoSpendCount} 는 지출 등록 과정에서 같은 날 무지출 row 가
/// 자동 삭제된 건수 (정상 흐름에선 0 또는 1). 클라이언트가 사용자에게 "오늘 무지출 기록이 취소되었어요" 같은
/// 안내를 띄울 때 참고. 무지출 자체 등록 시에는 항상 0.
public record AmountRecordResult(
        AmountResponse amount,
        int removedNoSpendCount
) {
    public static AmountRecordResult of(Amount amount, List<MediaFile> mediaFiles, int removedNoSpendCount) {
        return new AmountRecordResult(AmountResponse.of(amount, mediaFiles), removedNoSpendCount);
    }
}
