package com.hjson.tenk.domain.media;

import com.hjson.tenk.domain.amount.Amount;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MediaFileRepository extends JpaRepository<MediaFile, Long> {

    List<MediaFile> findByAmount(Amount amount);

    void deleteByAmount(Amount amount);

    /// 계정 파기 배치용 — 해당 유저의 모든 영상 상대경로 (디스크 파일 삭제 대상).
    @Query("select mf.filePath from MediaFile mf where mf.amount.challenge.user.id = :userId")
    List<String> findFilePathsByUserId(@Param("userId") Long userId);

    /// 계정 파기 배치용 — 해당 유저의 모든 media_file row 벌크 삭제. amount 삭제 전에 호출.
    @Modifying
    @Query("delete from MediaFile mf where mf.amount.id in "
            + "(select a.id from Amount a where a.challenge.id in "
            + "(select c.id from Challenge c where c.user.id = :userId))")
    void deleteByUserId(@Param("userId") Long userId);

    /// 다운로드 컨트롤러 전용 — 소유자 검증을 위해 amount → challenge → user 까지 한 번에 끌어온다.
    /// 트랜잭션 밖에서 `mediaFile.getAmount().getChallenge().getUser().getId()` 체이닝이 풀리는 LAZY 함정
    /// 회피용 ([MediaController](../MediaController.java) 다운로드 경로 회귀 가드).
    @Query("""
        select mf from MediaFile mf
        join fetch mf.amount a
        join fetch a.challenge c
        join fetch c.user
        where mf.id = :id
    """)
    Optional<MediaFile> findByIdWithAmountChallengeUser(@Param("id") Long id);
}
