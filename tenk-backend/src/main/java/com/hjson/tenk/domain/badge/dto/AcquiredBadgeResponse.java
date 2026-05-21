package com.hjson.tenk.domain.badge.dto;

import com.hjson.tenk.domain.badge.BadgeType;
import com.hjson.tenk.domain.badge.ChallengeBadge;
import java.time.LocalDateTime;

/** 챌린지 응답에 인라인되는 한 챌린지 안에서 획득한 배지 1건. */
public record AcquiredBadgeResponse(
        Long challengeBadgeId,
        Long badgeId,
        BadgeType type,
        int conditionValue,
        String iconPath,
        LocalDateTime acquiredDt
) {
    public static AcquiredBadgeResponse from(ChallengeBadge cb) {
        return new AcquiredBadgeResponse(
                cb.getId(),
                cb.getBadge().getId(),
                cb.getBadge().getType(),
                cb.getBadge().getConditionValue(),
                cb.getBadge().getIconPath(),
                cb.getCreatedDt());
    }
}
