package com.hjson.tenk.domain.amount.dto;

import com.hjson.tenk.domain.amount.Amount;
import com.hjson.tenk.domain.media.MediaFile;
import java.time.LocalDateTime;
import java.util.List;

public record AmountResponse(
        Long amountId,
        Long challengeId,
        String category,
        String content,
        int amount,
        boolean noSpend,
        String memo,
        LocalDateTime spentDt,
        LocalDateTime createdDt,
        List<MediaFileSummary> mediaFiles
) {
    /// 응답의 `category` 는 **enum 이 아니라 코드 문자열**로 내보낸다 — 클라이언트가 코드를 받아
    /// 라벨·아이콘으로 매핑하는 계약이라 wire format 을 바꾸지 않기 위함.
    public static AmountResponse of(Amount amount, List<MediaFile> mediaFiles) {
        return new AmountResponse(
                amount.getId(),
                amount.getChallenge().getId(),
                amount.getCategory() == null ? null : amount.getCategory().name(),
                amount.getContent(),
                amount.getAmount(),
                amount.isNoSpend(),
                amount.getMemo(),
                amount.getSpentDt(),
                amount.getCreatedDt(),
                mediaFiles.stream().map(MediaFileSummary::from).toList()
        );
    }

    public record MediaFileSummary(Long fileId, String filePath, String originalName) {
        public static MediaFileSummary from(MediaFile mediaFile) {
            return new MediaFileSummary(mediaFile.getId(), mediaFile.getFilePath(), mediaFile.getOriginalName());
        }
    }
}
