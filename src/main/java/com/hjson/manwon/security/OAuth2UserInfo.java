package com.hjson.manwon.security;

import com.hjson.manwon.domain.user.AuthProvider;

public interface OAuth2UserInfo {

    AuthProvider getProvider();

    String getProviderUserId();

    String getEmail();

    String getNickname();
}
