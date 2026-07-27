package com.hjson.tenk.domain.auth;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
import com.hjson.tenk.domain.user.WithdrawnUserPurgeService;
import com.hjson.tenk.security.JwtTokenProvider;
import com.hjson.tenk.security.KakaoTokenVerifier;
import com.hjson.tenk.security.KakaoTokenVerifier.KakaoUser;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final KakaoTokenVerifier kakaoTokenVerifier;
    private final JwtTokenProvider jwtTokenProvider;
    // 재가입 시 옛 계정을 즉시 파기하는 용도. REQUIRES_NEW 프록시를 타야 하므로 반드시 주입받아 호출한다.
    private final WithdrawnUserPurgeService purgeService;

    @Transactional
    public AuthTokens kakaoLogin(String kakaoAccessToken) {
        KakaoUser kakao = kakaoTokenVerifier.verifyAndFetch(kakaoAccessToken);
        ProvisionResult provisioned = provisionUser(kakao);
        return issueTokens(provisioned.user(), provisioned.isNewUser());
    }

    /**
     * 탈퇴 철회 후 로그인. 보관 기간이라 아직 물리 삭제되지 않은 계정을 되살리고 그대로 토큰을 발급한다.
     *
     * <p>철회 가능 여부는 <b>계정 row 의 생존</b>으로만 판단한다 — 보관 기간(1개월)이 지났어도 새벽 파기
     * 배치가 아직 안 돌았으면 철회를 허용한다. 배치 타이밍에 따라 사용자 경험이 갈리지 않게 하려는 의도이고,
     * 어긋나는 폭은 최대 하루다.
     */
    @Transactional
    public AuthTokens restoreWithdrawnAccount(String kakaoAccessToken) {
        User user = requireWithdrawnUser(kakaoTokenVerifier.verifyAndFetch(kakaoAccessToken));
        user.restoreFromWithdrawal();
        return issueTokens(user, false);
    }

    /**
     * 탈퇴 계정을 <b>버리고 새로 가입</b>. 유예 기간 중 돌아온 사용자가 "새로 시작하기" 를 고른 경로다.
     *
     * <p>철회와 재가입 중 무엇을 원하는지는 사용자만 안다 — 기록을 되찾으러 온 사람과 리셋하러 온 사람이
     * 반반이라, 어느 한쪽을 강요하면 나머지 절반에게는 서비스가 아니라 방해가 된다. 특히 <b>유예 기간이
     * 끝날 때까지 재가입을 막는 흐름은 만들지 않는다</b> — 옛 계정을 그 자리에서 파기해 곧바로 가입시킨다.
     *
     * <p>파기는 {@code REQUIRES_NEW} 라 이 트랜잭션과 별개로 <b>먼저 커밋</b>된다. 그래야 같은
     * {@code (provider, provider_user_id)} unique 키로 새 계정을 insert 할 수 있다. 되돌릴 수 없는
     * 삭제이므로 클라이언트가 확인을 한 번 더 받은 뒤 호출한다.
     */
    @Transactional
    public AuthTokens rejoinAfterWithdrawal(String kakaoAccessToken) {
        KakaoUser kakao = kakaoTokenVerifier.verifyAndFetch(kakaoAccessToken);
        User withdrawn = requireWithdrawnUser(kakao);
        purgeService.purgeImmediately(withdrawn.getId());
        return issueTokens(userRepository.save(newUserOf(kakao)), true);
    }

    private User requireWithdrawnUser(KakaoUser kakao) {
        User user = userRepository
                .findByProviderAndProviderUserId(AuthProvider.KAKAO, kakao.providerUserId())
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_NOT_FOUND));
        if (!user.isDeleted()) {
            throw new BusinessException(ErrorCode.USER_NOT_WITHDRAWN);
        }
        return user;
    }

    @Transactional
    public AuthTokens refresh(String refreshTokenRaw) {
        String hash = jwtTokenProvider.hash(refreshTokenRaw);
        RefreshToken stored = refreshTokenRepository.findByTokenHash(hash)
                .orElseThrow(() -> new BusinessException(ErrorCode.AUTH_REFRESH_TOKEN_INVALID));
        if (!stored.isUsable(LocalDateTime.now())) {
            throw new BusinessException(ErrorCode.AUTH_REFRESH_TOKEN_INVALID);
        }
        User user = stored.getUser();
        if (user.isDeleted()) {
            throw new BusinessException(ErrorCode.USER_ALREADY_WITHDRAWN);
        }
        stored.revoke();
        return issueTokens(user, false);
    }

    @Transactional
    public void logout(Long userId) {
        refreshTokenRepository.revokeAllByUserId(userId);
    }

    /**
     * 이미 프로비저닝된 사용자에게 AT/RT 를 발급한다. 카카오 검증을 거치지 않는 경로
     * (테스트 로그인 등)에서 토큰 발급 로직을 중복하지 않도록 노출한 진입점.
     */
    @Transactional
    public AuthTokens issueTokensFor(User user, boolean isNewUser) {
        return issueTokens(user, isNewUser);
    }

    private ProvisionResult provisionUser(KakaoUser kakao) {
        return userRepository
                .findByProviderAndProviderUserId(AuthProvider.KAKAO, kakao.providerUserId())
                .map(existing -> {
                    if (existing.isDeleted()) {
                        // 계정이 아직 살아 있으므로 사용자가 철회로 수습할 수 있다 — 클라이언트가 이 코드를
                        // 트리거로 철회 확인을 받고 /api/auth/kakao/restore 를 호출한다.
                        throw new BusinessException(ErrorCode.USER_WITHDRAWAL_RESTORABLE);
                    }
                    // 재로그인 시 갱신하는 값이 없다. nickname 은 사용자가 '내 정보' 에서 바꾼 값을
                    // 카카오 닉네임으로 덮어쓰지 않기 위해 두고, email 은 아예 수집하지 않는다.
                    return new ProvisionResult(existing, false);
                })
                .orElseGet(() -> new ProvisionResult(userRepository.save(newUserOf(kakao)), true));
    }

    private User newUserOf(KakaoUser kakao) {
        return User.create(
                AuthProvider.KAKAO,
                kakao.providerUserId(),
                kakao.nickname() == null ? "kakao-" + kakao.providerUserId() : kakao.nickname()
        );
    }

    private AuthTokens issueTokens(User user, boolean isNewUser) {
        String accessToken = jwtTokenProvider.issueAccessToken(user.getId());
        String refreshTokenRaw = jwtTokenProvider.issueRefreshTokenRaw();
        LocalDateTime expiresDt = LocalDateTime.now().plus(jwtTokenProvider.refreshTokenTtl());
        refreshTokenRepository.save(RefreshToken.issue(user, jwtTokenProvider.hash(refreshTokenRaw), expiresDt));
        return new AuthTokens(
                accessToken,
                refreshTokenRaw,
                jwtTokenProvider.accessTokenTtl().toSeconds(),
                user.getId(),
                user.getNickname(),
                isNewUser,
                !user.hasAgreedToRequiredConsents(),
                !user.hasVerifiedAge()
        );
    }

    private record ProvisionResult(User user, boolean isNewUser) {}
}
