package com.hjson.tenk.domain.user;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.domain.auth.RefreshTokenRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.regex.Pattern;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UserService {

    // 닉네임에서 거부할 유니코드 카테고리:
    //   \p{Cc} = Control      — null byte, 줄바꿈, 백스페이스 등 제어 문자
    //   \p{Cf} = Format       — zero-width(ZWSP/ZWNJ/ZWJ), BiDi override(LRE/RLE/PDF/LRO/RLO),
    //                           BiDi isolate, BOM, word joiner — 표시 위장·로그 인젝션 차단
    // 일반 이모지(\p{So}, surrogate pair)는 위 카테고리에 안 들어가서 그대로 허용된다.
    private static final Pattern NICKNAME_FORBIDDEN_CHARS = Pattern.compile("[\\p{Cc}\\p{Cf}]");

    private static final int NICKNAME_MAX_LENGTH = 50;

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;

    public User getActiveUser(Long userId) {
        return userRepository.findByIdAndDeletedFalse(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_NOT_FOUND));
    }

    @Transactional
    public void updateNickname(Long userId, String nickname) {
        User user = getActiveUser(userId);
        String normalized = validateAndNormalizeNickname(nickname);
        if (normalized.equals(user.getNickname())) {
            return; // 멱등 — 같은 값으로 PATCH 한 경우엔 1회 제한도 카운트하지 않는다
        }
        enforceDailyChangeLimit(user, LocalDate.now());
        user.changeNickname(normalized, LocalDateTime.now());
    }

    @Transactional
    public void withdraw(Long userId) {
        User user = getActiveUser(userId);
        if (user.isDeleted()) {
            throw new BusinessException(ErrorCode.USER_ALREADY_WITHDRAWN);
        }
        user.withdraw();
        refreshTokenRepository.revokeAllByUserId(userId);
    }

    private String validateAndNormalizeNickname(String raw) {
        if (raw == null) {
            throw new BusinessException(ErrorCode.USER_NICKNAME_INVALID);
        }
        String trimmed = raw.trim();
        if (trimmed.isEmpty() || trimmed.length() > NICKNAME_MAX_LENGTH) {
            throw new BusinessException(ErrorCode.USER_NICKNAME_INVALID);
        }
        if (NICKNAME_FORBIDDEN_CHARS.matcher(trimmed).find()) {
            throw new BusinessException(ErrorCode.USER_NICKNAME_INVALID);
        }
        return trimmed;
    }

    private void enforceDailyChangeLimit(User user, LocalDate today) {
        LocalDateTime last = user.getNicknameChangedDt();
        if (last == null) {
            return; // 한 번도 변경한 적 없으면 자유
        }
        if (!today.isAfter(last.toLocalDate())) {
            throw new BusinessException(ErrorCode.USER_NICKNAME_CHANGE_TOO_FREQUENT);
        }
    }
}
