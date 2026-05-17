package com.hjson.manwon.domain.media;

import com.hjson.manwon.domain.amount.Amount;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MediaFileRepository extends JpaRepository<MediaFile, Long> {

    List<MediaFile> findByAmount(Amount amount);

    void deleteByAmount(Amount amount);
}
