package com.hjson.tenk.security;

import com.hjson.tenk.common.config.AuthProperties;
import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

@Slf4j
@Component
public class KakaoTokenVerifier {

    private static final String TOKEN_INFO_URI = "https://kapi.kakao.com/v1/user/access_token_info";
    private static final String USER_ME_URI = "https://kapi.kakao.com/v2/user/me";
    private static final ParameterizedTypeReference<Map<String, Object>> MAP_TYPE =
            new ParameterizedTypeReference<>() {};

    private final RestClient client;
    private final long expectedAppId;

    public KakaoTokenVerifier(AuthProperties properties) {
        this.client = RestClient.builder().build();
        this.expectedAppId = properties.kakao().appId();
    }

    public KakaoUser verifyAndFetch(String kakaoAccessToken) {
        verifyAppId(kakaoAccessToken);
        Map<String, Object> me = call(USER_ME_URI, kakaoAccessToken, ErrorCode.AUTH_KAKAO_USERINFO_FAILED);
        return KakaoUser.from(me);
    }

    private void verifyAppId(String kakaoAccessToken) {
        Map<String, Object> info = call(TOKEN_INFO_URI, kakaoAccessToken, ErrorCode.AUTH_KAKAO_TOKEN_INVALID);
        Object appId = info.get("app_id");
        if (appId == null || !String.valueOf(appId).equals(String.valueOf(expectedAppId))) {
            throw new BusinessException(ErrorCode.AUTH_KAKAO_APP_MISMATCH);
        }
    }

    private Map<String, Object> call(String uri, String bearerToken, ErrorCode failureCode) {
        try {
            return client.get()
                    .uri(uri)
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + bearerToken)
                    .retrieve()
                    .body(MAP_TYPE);
        } catch (RestClientResponseException e) {
            if (e.getStatusCode().value() == 401) {
                throw new BusinessException(ErrorCode.AUTH_KAKAO_TOKEN_INVALID);
            }
            // ⚠️ 응답 body 를 찍지 말 것 — /v2/user/me 응답에는 닉네임 등 프로필이 들어 있어
            //    실패 로그가 개인정보 보관소가 된다. 어느 호출이 어떤 상태로 실패했는지면 충분하다.
            log.warn("Kakao API {} failed: status={}", uri, e.getStatusCode());
            throw new BusinessException(failureCode);
        } catch (Exception e) {
            log.warn("Kakao API {} call error", uri, e);
            throw new BusinessException(failureCode);
        }
    }

    /**
     * 카카오에서 받아 쓰는 값. <b>이메일은 의도적으로 읽지 않는다</b> (2026-07-26) —
     * '카카오계정(이메일)' 동의항목은 개인 개발자 일반 앱에서 '권한 없음'이고, 서비스 기능에도
     * 쓰이지 않아 비즈 앱 전환으로 받아올 이유가 없다고 판단했다 (개인정보 최소수집).
     * 되살릴 거면 {@code kakao_account.email} 파싱 + User 컬럼 + privacy.html 을 함께 되돌릴 것.
     */
    public record KakaoUser(String providerUserId, String nickname) {

        @SuppressWarnings("unchecked")
        static KakaoUser from(Map<String, Object> attributes) {
            Object id = attributes.get("id");
            if (id == null) {
                throw new BusinessException(ErrorCode.AUTH_KAKAO_USERINFO_FAILED);
            }
            String providerUserId = id.toString();

            Map<String, Object> account = (Map<String, Object>) attributes.get("kakao_account");
            String nickname = null;
            if (account != null) {
                Map<String, Object> profile = (Map<String, Object>) account.get("profile");
                if (profile != null && profile.get("nickname") != null) {
                    nickname = profile.get("nickname").toString();
                }
            }
            return new KakaoUser(providerUserId, nickname);
        }
    }
}
