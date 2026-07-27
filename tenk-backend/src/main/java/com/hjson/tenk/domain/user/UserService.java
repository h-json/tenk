package com.hjson.tenk.domain.user;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.domain.auth.RefreshTokenRepository;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.Period;
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

    /**
     * 닉네임 재변경 대기 시간. 마지막 변경 시각 기준 <b>정확히 24시간</b>이며, 날짜(자정) 기준이 아니다.
     * 앱 안내문("변경 후 24시간 동안은 다시 변경할 수 없어요")과 같은 값이어야 한다.
     * {@code UserResponse.computeAvailableFrom} 이 같은 값으로 "다시 가능해지는 시각"을 계산한다.
     */
    private static final Duration NICKNAME_CHANGE_COOLDOWN = Duration.ofHours(24);

    /** 이용 가능 최소 연령. 이용약관(terms.html)의 "만 14세 미만은 서비스 이용 대상이 아닙니다" 와 같은 값이어야 한다. */
    private static final int MINIMUM_AGE = 14;

    /** 생년월일 하한 — 오타·장난 입력 컷. 이보다 이른 날짜는 유효한 값으로 보지 않는다. */
    private static final LocalDate EARLIEST_BIRTH_DATE = LocalDate.of(1900, 1, 1);

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final WithdrawnUserPurgeService purgeService;
    private final WithdrawalFeedbackRepository withdrawalFeedbackRepository;

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
        LocalDateTime now = LocalDateTime.now();
        enforceChangeCooldown(user, now);
        user.changeNickname(normalized, now);
    }

    /**
     * 필수 동의(이용약관 + 개인정보 수집·이용)를 기록한다. 클라이언트가 두 항목을 모두 체크한 뒤
     * 호출하며, 서버는 미동의 항목만 현재 시각으로 스탬프한다 (이미 동의한 시각은 보존).
     */
    @Transactional
    public void agreeConsents(Long userId) {
        User user = getActiveUser(userId);
        user.agreeToRequiredConsents(LocalDateTime.now());
    }

    /**
     * 연령 확인. 클라이언트가 생년월일을 받아 호출하고, 서버가 {@link #MINIMUM_AGE} 를 판정한다.
     *
     * <p><b>만 14세 미만이면 계정을 즉시 파기하고 거부한다.</b> 카카오 로그인 시점에 이미 이메일·닉네임이
     * 프로비저닝돼 있어 "거부만" 하면 이용 대상이 아닌 미성년자의 개인정보가 서버에 남는다. 파기는
     * 트랜잭션 롤백에 휩쓸리지 않도록 {@link WithdrawnUserPurgeService#purgeImmediately} (REQUIRES_NEW) 로 한다.
     */
    @Transactional
    public void verifyAge(Long userId, LocalDate birthDate) {
        User user = getActiveUser(userId);
        LocalDate today = LocalDate.now();
        if (birthDate == null || birthDate.isAfter(today) || birthDate.isBefore(EARLIEST_BIRTH_DATE)) {
            throw new BusinessException(ErrorCode.USER_BIRTH_DATE_INVALID);
        }
        if (Period.between(birthDate, today).getYears() < MINIMUM_AGE) {
            purgeService.purgeImmediately(userId);
            throw new BusinessException(ErrorCode.USER_UNDER_MINIMUM_AGE);
        }
        user.verifyAge(birthDate);
    }

    /**
     * 성별 설정. {@code null} 이면 미입력으로 되돌린다 — 선택 수집 항목이라 <b>철회 경로를 항상 열어둔다</b>.
     * 서비스 기능은 이 값을 쓰지 않으므로 검증할 것도, 실패할 것도 없다.
     */
    @Transactional
    public void updateGender(Long userId, Gender gender) {
        getActiveUser(userId).changeGender(gender);
    }

    /**
     * 회원 탈퇴 (soft delete + RT 일괄 무효화).
     *
     * <p>{@code reason} 은 <b>선택</b>이다 — null 이면 아무것도 기록하지 않고 그대로 탈퇴시킨다.
     * 사유를 필수로 만들지 말 것: 탈퇴가 가입보다 어려워지면 안 된다. 기록은 계정과 연결되지 않는
     * 익명 테이블({@link WithdrawalFeedback})에 남으므로 계정 파기 후에도 통계로 남는다.
     */
    @Transactional
    public void withdraw(Long userId, WithdrawalReason reason, String detail) {
        User user = getActiveUser(userId);
        if (user.isDeleted()) {
            throw new BusinessException(ErrorCode.USER_ALREADY_WITHDRAWN);
        }
        if (reason != null) {
            withdrawalFeedbackRepository.save(WithdrawalFeedback.of(reason, detail));
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

    private void enforceChangeCooldown(User user, LocalDateTime now) {
        LocalDateTime last = user.getNicknameChangedDt();
        if (last == null) {
            return; // 한 번도 변경한 적 없으면 자유
        }
        if (now.isBefore(last.plus(NICKNAME_CHANGE_COOLDOWN))) {
            throw new BusinessException(ErrorCode.USER_NICKNAME_CHANGE_TOO_FREQUENT);
        }
    }
}
