package com.hjson.tenk.domain.challenge.dto;

import static org.assertj.core.api.Assertions.assertThat;

import com.hjson.tenk.domain.challenge.Challenge;
import com.hjson.tenk.domain.challenge.ChallengeStats;
import com.hjson.tenk.domain.user.AuthProvider;
import com.hjson.tenk.domain.user.User;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

/**
 * 응답의 <b>wire format</b> 고정.
 *
 * <p>클라이언트는 {@code currentStreak}/{@code noSpendDays} 를 이 이름 그대로 읽어 알림 문구에 쓴다.
 * 필드 이름이 바뀌면 컴파일은 통과하고 테스트도 대부분 통과하는데 <b>앱에서만 조용히 0 으로 떨어진다</b>
 * (구버전 서버 대비 폴백이 있어서 예외도 안 난다). 단위 테스트가 못 덮는 그 구간을 여기서 막는다 —
 * {@code amount.category} 전환 때 같은 이유로 가드를 세웠던 것과 같은 패턴.
 */
class ChallengeResponseWireFormatTest {

    @Test
    @DisplayName("진행 지표가 JSON 에 camelCase 숫자로 실린다")
    void exposesStatsAsJsonNumbers() {
        User user = User.create(AuthProvider.KAKAO, "kakao-wire", "tester");
        Challenge challenge = Challenge.create(
                user, "와이어 테스트", LocalDate.now(), LocalDate.now().plusDays(5), 10_000);

        ChallengeResponse response = ChallengeResponse.of(
                challenge, 3_000L, LocalDate.now(), new ChallengeStats(4, 2), List.of());

        String json = new ObjectMapper().writeValueAsString(response);

        assertThat(json).contains("\"currentStreak\":4");
        assertThat(json).contains("\"noSpendDays\":2");
    }
}
