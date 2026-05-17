package com.hjson.manwon.security;

import com.hjson.manwon.common.exception.BusinessException;
import com.hjson.manwon.common.exception.ErrorCode;
import com.hjson.manwon.domain.user.AuthProvider;
import java.util.Map;

public final class OAuth2UserInfoFactory {

    private OAuth2UserInfoFactory() {}

    public static OAuth2UserInfo of(String registrationId, Map<String, Object> attributes) {
        return switch (registrationId.toLowerCase()) {
            case "google" -> new GoogleUserInfo(attributes);
            case "kakao" -> new KakaoUserInfo(attributes);
            case "naver" -> new NaverUserInfo(attributes);
            default -> throw new BusinessException(
                    ErrorCode.UNAUTHORIZED,
                    "지원하지 않는 로그인 공급자입니다: " + registrationId);
        };
    }

    static final class GoogleUserInfo implements OAuth2UserInfo {
        private final Map<String, Object> attributes;

        GoogleUserInfo(Map<String, Object> attributes) {
            this.attributes = attributes;
        }

        @Override public AuthProvider getProvider() { return AuthProvider.GOOGLE; }
        @Override public String getProviderUserId() { return (String) attributes.get("sub"); }
        @Override public String getEmail() { return (String) attributes.get("email"); }
        @Override public String getNickname() {
            Object name = attributes.get("name");
            return name != null ? name.toString() : getEmail();
        }
    }

    static final class KakaoUserInfo implements OAuth2UserInfo {
        private final Map<String, Object> attributes;

        KakaoUserInfo(Map<String, Object> attributes) {
            this.attributes = attributes;
        }

        @Override public AuthProvider getProvider() { return AuthProvider.KAKAO; }

        @Override public String getProviderUserId() {
            Object id = attributes.get("id");
            return id != null ? id.toString() : null;
        }

        @Override
        @SuppressWarnings("unchecked")
        public String getEmail() {
            Map<String, Object> account = (Map<String, Object>) attributes.get("kakao_account");
            return account != null ? (String) account.get("email") : null;
        }

        @Override
        @SuppressWarnings("unchecked")
        public String getNickname() {
            Map<String, Object> account = (Map<String, Object>) attributes.get("kakao_account");
            if (account != null) {
                Map<String, Object> profile = (Map<String, Object>) account.get("profile");
                if (profile != null && profile.get("nickname") != null) {
                    return profile.get("nickname").toString();
                }
            }
            return "kakao-" + getProviderUserId();
        }
    }

    static final class NaverUserInfo implements OAuth2UserInfo {
        private final Map<String, Object> response;

        @SuppressWarnings("unchecked")
        NaverUserInfo(Map<String, Object> attributes) {
            this.response = (Map<String, Object>) attributes.get("response");
        }

        @Override public AuthProvider getProvider() { return AuthProvider.NAVER; }
        @Override public String getProviderUserId() { return response != null ? (String) response.get("id") : null; }
        @Override public String getEmail() { return response != null ? (String) response.get("email") : null; }

        @Override public String getNickname() {
            if (response == null) {
                return null;
            }
            Object nickname = response.get("nickname");
            if (nickname != null) {
                return nickname.toString();
            }
            Object name = response.get("name");
            return name != null ? name.toString() : getEmail();
        }
    }
}
