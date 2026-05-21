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
            em.createNativeQuery("DELETE FROM `user`").executeUpdate();
        });
    }
}
