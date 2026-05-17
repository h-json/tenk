package com.hjson.manwon.security;

import com.hjson.manwon.domain.user.User;
import com.hjson.manwon.domain.user.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.oauth2.client.userinfo.DefaultOAuth2UserService;
import org.springframework.security.oauth2.client.userinfo.OAuth2UserRequest;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class CustomOAuth2UserService extends DefaultOAuth2UserService {

    private final UserRepository userRepository;

    @Override
    @Transactional
    public OAuth2User loadUser(OAuth2UserRequest userRequest) throws OAuth2AuthenticationException {
        OAuth2User oAuth2User = super.loadUser(userRequest);
        String registrationId = userRequest.getClientRegistration().getRegistrationId();

        OAuth2UserInfo info = OAuth2UserInfoFactory.of(registrationId, oAuth2User.getAttributes());
        if (info.getProviderUserId() == null || info.getProviderUserId().isBlank()) {
            throw new OAuth2AuthenticationException(
                    new OAuth2Error("invalid_user_info"),
                    "공급자 사용자 ID를 확인할 수 없습니다.");
        }

        User user = userRepository
                .findByProviderAndProviderUserId(info.getProvider(), info.getProviderUserId())
                .map(existing -> {
                    if (existing.isDeleted()) {
                        throw new OAuth2AuthenticationException(
                                new OAuth2Error("withdrawn_user"),
                                "탈퇴한 사용자입니다.");
                    }
                    existing.updateProfile(info.getEmail(), info.getNickname());
                    return existing;
                })
                .orElseGet(() -> userRepository.save(User.create(
                        info.getProvider(),
                        info.getProviderUserId(),
                        info.getEmail(),
                        info.getNickname() == null ? "user-" + info.getProviderUserId() : info.getNickname()
                )));

        return new CustomOAuth2User(user, oAuth2User.getAttributes());
    }
}
