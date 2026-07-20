package com.hjson.tenk.domain.user;

import static org.assertj.core.api.Assertions.assertThat;

import com.hjson.tenk.domain.amount.Amount;
import com.hjson.tenk.domain.amount.AmountRepository;
import com.hjson.tenk.domain.auth.RefreshToken;
import com.hjson.tenk.domain.auth.RefreshTokenRepository;
import com.hjson.tenk.domain.badge.Badge;
import com.hjson.tenk.domain.badge.BadgeRepository;
import com.hjson.tenk.domain.badge.BadgeType;
import com.hjson.tenk.domain.badge.ChallengeBadge;
import com.hjson.tenk.domain.badge.ChallengeBadgeRepository;
import com.hjson.tenk.domain.challenge.Challenge;
import com.hjson.tenk.domain.challenge.ChallengeRepository;
import com.hjson.tenk.domain.media.LocalFileStorage;
import com.hjson.tenk.domain.media.MediaFile;
import com.hjson.tenk.domain.media.MediaFileRepository;
import com.hjson.tenk.support.IntegrationTestBase;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 탈퇴 계정 파기(hard delete) 배치의 E2E.
 *
 * <p>{@link WithdrawnUserPurgeService} 는 개인정보처리방침 §3("탈퇴 후 3개월 보관 후 파기")의
 * 구현체다. 개인정보 파기 의무와 직결되므로 두 가지를 회귀 가드한다.
 * <ul>
 *   <li><b>보관 기간 경계</b> — 탈퇴 직후 계정은 파기 대상이 아니고, {@code deletedDt} 가
 *       {@link WithdrawnUserPurgeService#RETENTION} 을 넘긴 계정만 대상이 된다.</li>
 *   <li><b>디스크 영상까지 삭제</b> — row 만 지우고 {@code uploads/} 의 mp4 가 남으면
 *       "DB 상 삭제됐지만 파일은 영구 잔존" 이 된다. 파일 삭제는 {@code deleteQuietly}
 *       best-effort 라 조용히 실패해도 아무도 모르는 지점이라 테스트가 유일한 감시다.</li>
 * </ul>
 *
 * <p>3개월을 기다릴 수 없으므로 {@code deletedDt} 를 reflection 으로 backdate 한다
 * (챌린지 상태를 만들 때 쓰는 것과 같은 수법 — {@code LocalDateTime.now()} 는 못 모킹).
 */
class WithdrawnUserPurgeIntegrationTest extends IntegrationTestBase {

    @Autowired WithdrawnUserPurgeService purgeService;
    @Autowired UserService userService;
    @Autowired UserRepository userRepository;
    @Autowired ChallengeRepository challengeRepository;
    @Autowired AmountRepository amountRepository;
    @Autowired MediaFileRepository mediaFileRepository;
    @Autowired ChallengeBadgeRepository challengeBadgeRepository;
    @Autowired RefreshTokenRepository refreshTokenRepository;
    @Autowired BadgeRepository badgeRepository;
    @Autowired LocalFileStorage storage;

    @Test
    @DisplayName("탈퇴 직후 계정은 보관 기간이 남아 파기 대상이 아니다")
    void freshlyWithdrawnUserIsNotPurgeable() {
        Long userId = seedUserWithData("purge-fresh");
        tx.executeWithoutResult(status -> userService.withdraw(userId));

        assertThat(purgeService.findPurgeableUserIds()).doesNotContain(userId);
    }

    @Test
    @DisplayName("탈퇴하지 않은 계정은 아무리 오래돼도 파기 대상이 아니다")
    void activeUserIsNeverPurgeable() {
        Long userId = seedUserWithData("purge-active");

        assertThat(purgeService.findPurgeableUserIds()).doesNotContain(userId);
    }

    @Test
    @DisplayName("보관 기간이 지난 탈퇴 계정은 파기 대상 목록에 잡힌다")
    void expiredWithdrawnUserIsPurgeable() {
        Long userId = seedWithdrawnUser("purge-expired");

        assertThat(purgeService.findPurgeableUserIds()).contains(userId);
    }

    @Test
    @DisplayName("purge 는 row 전부 + 디스크 영상 파일까지 지운다")
    void purgeDeletesEveryRowAndTheVideoFile() throws IOException {
        Long userId = seedWithdrawnUser("purge-full");
        List<String> filePaths = mediaFileRepository.findFilePathsByUserId(userId);
        assertThat(filePaths).hasSize(1);
        Path videoFile = storage.resolve(filePaths.getFirst());
        assertThat(Files.exists(videoFile)).isTrue(); // 시딩이 실제 파일을 만들었는지 선확인

        purgeService.purge(userId);

        assertThat(userRepository.findById(userId)).isEmpty();
        assertThat(countFor(userId)).isEqualTo(new Counts(0, 0, 0, 0, 0));
        assertThat(Files.exists(videoFile))
                .as("디스크 영상 파일이 남으면 DB 만 지워진 반쪽 파기가 된다")
                .isFalse();
    }

    @Test
    @DisplayName("purge 는 다른 계정의 데이터를 건드리지 않는다")
    void purgeIsScopedToTheTargetUser() {
        Long victim = seedWithdrawnUser("purge-target");
        Long bystander = seedUserWithData("purge-bystander");

        purgeService.purge(victim);

        assertThat(userRepository.findById(bystander)).isPresent();
        assertThat(countFor(bystander)).isEqualTo(new Counts(1, 1, 1, 1, 1));
    }

    // --- seeding -------------------------------------------------------------

    /** 파기 대상이 되는 모든 자식 데이터(챌린지·지출·영상·배지·RT) + 실제 디스크 파일까지 만든다. */
    private Long seedUserWithData(String providerUserId) {
        return tx.execute(status -> {
            User user = userRepository.save(User.create(
                    AuthProvider.KAKAO, providerUserId, providerUserId + "@example.com", "탈퇴예정"));
            Challenge challenge = challengeRepository.save(Challenge.create(
                    user, "파기 테스트", LocalDate.now(), LocalDate.now().plusDays(3), 10_000));
            Amount amount = amountRepository.save(Amount.spend(
                    challenge, "FOOD", "점심", 5_000, null, LocalDate.now().atTime(12, 0)));

            String relativePath = writeDummyVideo(providerUserId);
            mediaFileRepository.save(MediaFile.create(amount, relativePath, "test.mp4"));

            Badge badge = badgeRepository
                    .findByTypeAndConditionValue(BadgeType.CHALLENGE_SUCCESS, 1)
                    .orElseThrow(() -> new IllegalStateException(
                            "badge 마스터가 없다 — docs/schema.sql 의 INSERT 를 적용할 것"));
            challengeBadgeRepository.save(ChallengeBadge.create(challenge, badge));

            refreshTokenRepository.save(RefreshToken.issue(
                    user, "hash-" + providerUserId, LocalDateTime.now().plusDays(14)));
            return user.getId();
        });
    }

    /** 데이터 시딩 + 탈퇴 + {@code deletedDt} 를 보관 기간 밖으로 backdate. */
    private Long seedWithdrawnUser(String providerUserId) {
        Long userId = seedUserWithData(providerUserId);
        tx.executeWithoutResult(status -> {
            userService.withdraw(userId);
            User user = userRepository.findById(userId).orElseThrow();
            ReflectionTestUtils.setField(user, "deletedDt",
                    LocalDateTime.now().minus(WithdrawnUserPurgeService.RETENTION).minusDays(1));
        });
        return userId;
    }

    /** {@code uploads-test/} 아래에 실제 바이트를 가진 더미 mp4 를 만들고 상대경로를 돌려준다. */
    private String writeDummyVideo(String providerUserId) {
        String relativePath = "amounts/purge-test/" + providerUserId + ".mp4";
        try {
            Path target = storage.resolve(relativePath);
            Files.createDirectories(target.getParent());
            Files.write(target, new byte[] {0, 1, 2, 3});
        } catch (IOException e) {
            throw new IllegalStateException("더미 영상 파일 생성 실패", e);
        }
        return relativePath;
    }

    // --- assertions ----------------------------------------------------------

    private Counts countFor(Long userId) {
        return tx.execute(status -> new Counts(
                count("select count(*) from challenge where user_id = ?", userId),
                count("select count(*) from amount a join challenge c on a.challenge_id = c.challenge_id"
                        + " where c.user_id = ?", userId),
                count("select count(*) from media_file mf join amount a on mf.amount_id = a.amount_id"
                        + " join challenge c on a.challenge_id = c.challenge_id where c.user_id = ?", userId),
                count("select count(*) from challenge_badge cb"
                        + " join challenge c on cb.challenge_id = c.challenge_id where c.user_id = ?", userId),
                count("select count(*) from refresh_token where user_id = ?", userId)));
    }

    private int count(String sql, Long userId) {
        Object result = em.createNativeQuery(sql).setParameter(1, userId).getSingleResult();
        return ((Number) result).intValue();
    }

    private record Counts(int challenges, int amounts, int mediaFiles, int challengeBadges, int refreshTokens) {}
}
