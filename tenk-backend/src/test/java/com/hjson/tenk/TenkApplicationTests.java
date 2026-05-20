package com.hjson.tenk;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * 풀 컨텍스트 부팅이 깨지지 않는지 확인. {@code test} 프로파일을 박아 통합 테스트와 같은
 * 자격증명을 쓴다 — default(local) 로 떴을 때 IntegrationTestBase 와 프로파일이 갈리는 함정 방지.
 */
@SpringBootTest
@ActiveProfiles("test")
class TenkApplicationTests {

	@Test
	void contextLoads() {
	}

}
