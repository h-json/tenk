package com.hjson.tenk.support;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 통합 테스트 공통 베이스.
 * <p>설계 메모:
 * <ul>
 *   <li>로컬 MariaDB의 {@code tenk} 스키마를 그대로 사용한다. 매 테스트마다 비-마스터 테이블을
 *       비우므로 dev 데이터(로그인 사용자, 챌린지 등)는 테스트 실행 시 함께 날아간다.
 *       Flutter 앱은 카카오 재로그인으로 복구 가능.</li>
 *   <li>{@code @Transactional} 롤백을 쓰지 않는 이유: 배지 지급은 {@code AFTER_COMMIT}
 *       이벤트 리스너가 트리거하므로 트랜잭션이 실제로 커밋돼야 한다. 그래서 각 테스트는
 *       자기 트랜잭션을 직접 열고 닫는다 (TransactionTemplate).</li>
 *   <li>{@code badge} 마스터 9행은 {@code docs/schema.sql} 로 시드된 상태를 가정하고
 *       삭제하지 않는다.</li>
 * </ul>
 */
@SpringBootTest
@ActiveProfiles("test")
public abstract class IntegrationTestBase {

    @PersistenceContext
    protected EntityManager em;

    @Autowired
    protected TransactionTemplate tx;

    @BeforeEach
    void cleanDatabase() {
        tx.executeWithoutResult(status -> {
            em.createNativeQuery("DELETE FROM challenge_badge").executeUpdate();
            em.createNativeQuery("DELETE FROM media_file").executeUpdate();
            em.createNativeQuery("DELETE FROM amount").executeUpdate();
            em.createNativeQuery("DELETE FROM challenge").executeUpdate();
            em.createNativeQuery("DELETE FROM refresh_token").executeUpdate();
            // user 의 자식이라 반드시 user 보다 먼저 (feedback 과 달리 user_id 를 들고 있다).
            em.createNativeQuery("DELETE FROM inquiry").executeUpdate();
            em.createNativeQuery("DELETE FROM `user`").executeUpdate();
            // 계정과 무관한 익명 테이블이라 파기 배치는 안 건드리지만, 테스트 간에는 쌓이면 안 된다.
            em.createNativeQuery("DELETE FROM withdrawal_feedback").executeUpdate();
            em.createNativeQuery("DELETE FROM feedback").executeUpdate();
        });
    }
}
