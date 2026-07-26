package com.hjson.tenk.domain.auth;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
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

    @Transactional
    public AuthTokens kakaoLogin(String kakaoAccessToken) {
        KakaoUser kakao = kakaoTokenVerifier.verifyAndFetch(kakaoAccessToken);
        ProvisionResult provisioned = provisionUser(kakao);
        return issueTokens(provisioned.user(), provisioned.isNewUser());
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
                        throw new BusinessException(ErrorCode.USER_ALREADY_WITHDRAWN);
                    }
                    // 재로그인 시 갱신하는 값이 없다. nickname 은 사용자가 '내 정보' 에서 바꾼 값을
                    // 카카오 닉네임으로 덮어쓰지 않기 위해 두고, email 은 아예 수집하지 않는다.
                    return new ProvisionResult(existing, false);
                })
                .orElseGet(() -> new ProvisionResult(
                        userRepository.save(User.create(
                                AuthProvider.KAKAO,
                                kakao.providerUserId(),
                                kakao.nickname() == null ? "kakao-" + kakao.providerUserId() : kakao.nickname()
                        )),
                        true
                ));
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
