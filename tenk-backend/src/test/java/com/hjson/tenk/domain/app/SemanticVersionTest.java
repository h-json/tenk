package com.hjson.tenk.domain.app;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class SemanticVersionTest {

    @Test
    @DisplayName("major/minor/patch 를 숫자로 비교한다 (문자열 비교 아님)")
    void comparesNumerically() {
        assertThat(SemanticVersion.parse("1.0.0").compareTo(SemanticVersion.parse("1.0.1"))).isNegative();
        // 문자열 비교라면 "2" < "10" 이 뒤집혀 틀림 — 숫자 비교여야 통과
        assertThat(SemanticVersion.parse("1.2.0").compareTo(SemanticVersion.parse("1.10.0"))).isNegative();
        assertThat(SemanticVersion.parse("2.0.0").compareTo(SemanticVersion.parse("1.9.9"))).isPositive();
        assertThat(SemanticVersion.parse("1.0.0").compareTo(SemanticVersion.parse("1.0.0"))).isZero();
    }

    @Test
    @DisplayName("빌드/프리릴리스 접미사와 자릿수 차이를 무시한다")
    void ignoresSuffixAndLength() {
        assertThat(SemanticVersion.parse("1.0.0+3").compareTo(SemanticVersion.parse("1.0.0"))).isZero();
        assertThat(SemanticVersion.parse("1.0").compareTo(SemanticVersion.parse("1.0.0"))).isZero();
        assertThat(SemanticVersion.parse("1.0.0-beta").compareTo(SemanticVersion.parse("1.0.0"))).isZero();
    }

    @Test
    @DisplayName("null/blank/비숫자는 예외 — 호출부가 fail-open 하도록 신호")
    void rejectsGarbage() {
        assertThatThrownBy(() -> SemanticVersion.parse(null)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> SemanticVersion.parse("")).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> SemanticVersion.parse("abc")).isInstanceOf(IllegalArgumentException.class);
    }
}
