package com.hjson.tenk.domain.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import com.hjson.tenk.domain.user.UserRepository;
import com.hjson.tenk.domain.user.WithdrawnUserPurgeService;
import com.hjson.tenk.security.JwtTokenProvider;
import com.hjson.tenk.security.KakaoTokenVerifier;
import com.hjson.tenk.security.KakaoTokenVerifier.KakaoUser;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class AuthServiceTest {

    @Mock UserRepository userRepository;
    @Mock RefreshTokenRepository refreshTokenRepository;
    @Mock KakaoTokenVerifier kakaoTokenVerifier;
    @Mock JwtTokenProvider jwtTokenProvider;
    @Mock WithdrawnUserPurgeService purgeService;

    @InjectMocks AuthService service;

    @BeforeEach
    void setUp() {
        given(jwtTokenProvider.issueAccessToken(anyLong())).willReturn("AT");
        given(jwtTokenProvider.issueRefreshTokenRaw()).willReturn("RT-raw");
        given(jwtTokenProvider.hash("RT-raw")).willReturn("RT-hash-new");
        given(jwtTokenProvider.accessTokenTtl()).willReturn(Duration.ofHours(1));
        given(jwtTokenProvider.refreshTokenTtl()).willReturn(Duration.ofDays(14));
    }

    private User userWithId(long id) {
        User u = User.create(AuthProvider.KAKAO, "kakao-id-" + id, "tester");
        ReflectionTestUtils.setField(u, "id", id);
        return u;
    }

    @Test
    void kakaoLogin_provisions_new_user_when_none_exists() {
        given(kakaoTokenVerifier.verifyAndFetch("kakao-AT"))
                .willReturn(new KakaoUser("kakao-id-200", "tester"));
        given(userRepository.findByProviderAndProviderUserId(AuthProvider.KAKAO, "kakao-id-200"))
                .willReturn(Optional.empty());
        User saved = userWithId(200L);
        given(userRepository.save(any(User.class))).willReturn(saved);

        AuthTokens tokens = service.kakaoLogin("kakao-AT");

        verify(userRepository).save(any(User.class));
        verify(refreshTokenRepository).save(any(RefreshToken.class));
        assertThat(tokens.userId()).isEqualTo(200L);
        assertThat(tokens.accessToken()).isEqualTo("AT");
        assertThat(tokens.refreshToken()).isEqualTo("RT-raw");
        assertThat(tokens.isNewUser()).isTrue();
    }

    @Test
    void kakaoLogin_preserves_nickname_for_existing_user() {
        User existing = userWithId(200L);
        // 사용자가 '내 정보' 에서 'mychoice' 로 변경한 상태라고 가정
        ReflectionTestUtils.setField(existing, "nickname", "mychoice");
        given(kakaoTokenVerifier.verifyAndFetch("kakao-AT"))
                .willReturn(new KakaoUser("kakao-id-200", "kakaonick"));
        given(userRepository.findByProviderAndProviderUserId(AuthProvider.KAKAO, "kakao-id-200"))
                .willReturn(Optional.of(existing));

        AuthTokens tokens = service.kakaoLogin("kakao-AT");

        assertThat(existing.getNickname()).isEqualTo("mychoice"); // 카카오 닉네임으로 덮어쓰지 않는다
        verify(userRepository, never()).save(any(User.class));
        assertThat(tokens.userId()).isEqualTo(200L);
        assertThat(tokens.isNewUser()).isFalse();
    }

    @Test
    void kakaoLogin_signals_restorable_when_existing_user_withdrawn() {
        User withdrawn = userWithId(200L);
        withdrawn.withdraw();
        given(kakaoTokenVerifier.verifyAndFetch("kakao-AT"))
                .willReturn(new KakaoUser("kakao-id-200", null));
        given(userRepository.findByProviderAndProviderUserId(AuthProvider.KAKAO, "kakao-id-200"))
                .willReturn(Optional.of(withdrawn));

        // 계정이 살아 있으면 "이미 탈퇴" 로 끝내지 않고 철회 가능 신호를 준다 (클라가 확인 다이얼로그를 띄운다).
        assertThatThrownBy(() -> service.kakaoLogin("kakao-AT"))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.USER_WITHDRAWAL_RESTORABLE);
    }

    @Test
    void restore_revives_withdrawn_account_and_issues_tokens() {
        User withdrawn = userWithId(200L);
        ReflectionTestUtils.setField(withdrawn, "nickname", "mychoice");
        withdrawn.withdraw();
        given(kakaoTokenVerifier.verifyAndFetch("kakao-AT"))
                .willReturn(new KakaoUser("kakao-id-200", "kakaonick"));
        given(userRepository.findByProviderAndProviderUserId(AuthProvider.KAKAO, "kakao-id-200"))
                .willReturn(Optional.of(withdrawn));

        AuthTokens tokens = service.restoreWithdrawnAccount("kakao-AT");

        assertThat(withdrawn.isDeleted()).isFalse();
        assertThat(withdrawn.getDeletedDt()).isNull();
        assertThat(withdrawn.getNickname()).isEqualTo("mychoice"); // 철회는 데이터를 건드리지 않는다
        verify(refreshTokenRepository).save(any(RefreshToken.class));
        assertThat(tokens.userId()).isEqualTo(200L);
        assertThat(tokens.isNewUser()).isFalse(); // 복구지 신규 가입이 아니다 — 닉네임 설정 화면이 뜨면 안 됨
    }

    @Test
    void restore_still_allowed_after_retention_elapsed_while_row_survives() {
        User withdrawn = userWithId(200L);
        withdrawn.withdraw();
        // 파기 배치가 아직 안 돈 상태 (보관 기간 경과). 사각지대를 만들지 않으려 철회를 허용한다.
        ReflectionTestUtils.setField(withdrawn, "deletedDt", LocalDateTime.now().minusMonths(6));
        given(kakaoTokenVerifier.verifyAndFetch("kakao-AT"))
                .willReturn(new KakaoUser("kakao-id-200", null));
        given(userRepository.findByProviderAndProviderUserId(AuthProvider.KAKAO, "kakao-id-200"))
                .willReturn(Optional.of(withdrawn));

        AuthTokens tokens = service.restoreWithdrawnAccount("kakao-AT");

        assertThat(withdrawn.isDeleted()).isFalse();
        assertThat(tokens.userId()).isEqualTo(200L);
    }

    @Test
    void rejoin_purges_old_account_then_creates_a_fresh_one() {
        User withdrawn = userWithId(200L);
        withdrawn.withdraw();
        given(kakaoTokenVerifier.verifyAndFetch("kakao-AT"))
                .willReturn(new KakaoUser("kakao-id-200", "kakaonick"));
        given(userRepository.findByProviderAndProviderUserId(AuthProvider.KAKAO, "kakao-id-200"))
                .willReturn(Optional.of(withdrawn));
        User created = userWithId(201L);
        given(userRepository.save(any(User.class))).willReturn(created);

        AuthTokens tokens = service.rejoinAfterWithdrawal("kakao-AT");

        // 파기가 먼저 — 안 그러면 (provider, provider_user_id) unique 로 새 계정 insert 가 막힌다
        InOrder order = inOrder(purgeService, userRepository);
        order.verify(purgeService).purgeImmediately(200L);
        order.verify(userRepository).save(any(User.class));
        assertThat(tokens.userId()).isEqualTo(201L);
        // 새 계정이므로 온보딩(연령→동의→닉네임)을 전부 다시 탄다
        assertThat(tokens.isNewUser()).isTrue();
        assertThat(tokens.consentRequired()).isTrue();
        assertThat(tokens.ageVerificationRequired()).isTrue();
    }

    @Test
    void rejoin_rejects_account_that_is_not_withdrawn() {
        User active = userWithId(200L);
        given(kakaoTokenVerifier.verifyAndFetch("kakao-AT"))
                .willReturn(new KakaoUser("kakao-id-200", null));
        given(userRepository.findByProviderAndProviderUserId(AuthProvider.KAKAO, "kakao-id-200"))
                .willReturn(Optional.of(active));

        assertThatThrownBy(() -> service.rejoinAfterWithdrawal("kakao-AT"))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.USER_NOT_WITHDRAWN);
        verify(purgeService, never()).purgeImmediately(anyLong());
    }

    @Test
    void rejoin_rejects_when_account_no_longer_exists() {
        given(kakaoTokenVerifier.verifyAndFetch("kakao-AT"))
                .willReturn(new KakaoUser("kakao-id-200", null));
        given(userRepository.findByProviderAndProviderUserId(AuthProvider.KAKAO, "kakao-id-200"))
                .willReturn(Optional.empty());

        // 이미 파기된 계정이면 재가입이 아니라 평범한 신규 가입 경로(kakaoLogin)로 가야 한다
        assertThatThrownBy(() -> service.rejoinAfterWithdrawal("kakao-AT"))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.USER_NOT_FOUND);
        verify(purgeService, never()).purgeImmediately(anyLong());
    }

    @Test
    void restore_rejects_account_that_is_not_withdrawn() {
        User active = userWithId(200L);
        given(kakaoTokenVerifier.verifyAndFetch("kakao-AT"))
                .willReturn(new KakaoUser("kakao-id-200", null));
        given(userRepository.findByProviderAndProviderUserId(AuthProvider.KAKAO, "kakao-id-200"))
                .willReturn(Optional.of(active));

        assertThatThrownBy(() -> service.restoreWithdrawnAccount("kakao-AT"))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.USER_NOT_WITHDRAWN);
    }

    @Test
    void restore_rejects_when_account_no_longer_exists() {
        given(kakaoTokenVerifier.verifyAndFetch("kakao-AT"))
                .willReturn(new KakaoUser("kakao-id-200", null));
        given(userRepository.findByProviderAndProviderUserId(AuthProvider.KAKAO, "kakao-id-200"))
                .willReturn(Optional.empty());

        // 보관 기간이 끝나 파기된 계정 — 되살릴 대상이 없다.
        assertThatThrownBy(() -> service.restoreWithdrawnAccount("kakao-AT"))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.USER_NOT_FOUND);
    }

    @Test
    void refresh_unknown_token_throws() {
        given(jwtTokenProvider.hash("missing")).willReturn("hash-missing");
        given(refreshTokenRepository.findByTokenHash("hash-missing")).willReturn(Optional.empty());

        assertThatThrownBy(() -> service.refresh("missing"))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.AUTH_REFRESH_TOKEN_INVALID);
    }

    @Test
    void refresh_revoked_token_throws() {
        User user = userWithId(200L);
        RefreshToken rt = RefreshToken.issue(user, "hash-old", LocalDateTime.now().plusDays(7));
        rt.revoke();
        given(jwtTokenProvider.hash("old-raw")).willReturn("hash-old");
        given(refreshTokenRepository.findByTokenHash("hash-old")).willReturn(Optional.of(rt));

        assertThatThrownBy(() -> service.refresh("old-raw"))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.AUTH_REFRESH_TOKEN_INVALID);
    }

    @Test
    void refresh_expired_token_throws() {
        User user = userWithId(200L);
        RefreshToken rt = RefreshToken.issue(user, "hash-old", LocalDateTime.now().minusMinutes(1));
        given(jwtTokenProvider.hash("old-raw")).willReturn("hash-old");
        given(refreshTokenRepository.findByTokenHash("hash-old")).willReturn(Optional.of(rt));

        assertThatThrownBy(() -> service.refresh("old-raw"))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.AUTH_REFRESH_TOKEN_INVALID);
    }

    @Test
    void refresh_rotates_token_on_success() {
        User user = userWithId(200L);
        RefreshToken rt = RefreshToken.issue(user, "hash-old", LocalDateTime.now().plusDays(7));
        given(jwtTokenProvider.hash("old-raw")).willReturn("hash-old");
        given(refreshTokenRepository.findByTokenHash("hash-old")).willReturn(Optional.of(rt));

        AuthTokens tokens = service.refresh("old-raw");

        assertThat(rt.isRevoked()).isTrue();
        verify(refreshTokenRepository).save(any(RefreshToken.class));
        assertThat(tokens.accessToken()).isEqualTo("AT");
        assertThat(tokens.refreshToken()).isEqualTo("RT-raw");
        assertThat(tokens.userId()).isEqualTo(200L);
        assertThat(tokens.isNewUser()).isFalse();
    }

    @Test
    void refresh_throws_when_user_already_withdrawn() {
        User user = userWithId(200L);
        user.withdraw();
        RefreshToken rt = RefreshToken.issue(user, "hash-old", LocalDateTime.now().plusDays(7));
        given(jwtTokenProvider.hash("old-raw")).willReturn("hash-old");
        given(refreshTokenRepository.findByTokenHash("hash-old")).willReturn(Optional.of(rt));

        assertThatThrownBy(() -> service.refresh("old-raw"))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.USER_ALREADY_WITHDRAWN);
    }

    @Test
    void logout_revokes_all_user_refresh_tokens() {
        service.logout(200L);
        verify(refreshTokenRepository).revokeAllByUserId(200L);
    }
}
