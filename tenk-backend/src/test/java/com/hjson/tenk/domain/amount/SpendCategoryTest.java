package com.hjson.tenk.domain.amount;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.hjson.tenk.common.exception.BusinessException;
import com.hjson.tenk.common.exception.ErrorCode;
import org.junit.jupiter.api.Test;

class SpendCategoryTest {

    @Test
    void from_maps_valid_code() {
        assertThat(SpendCategory.from("FOOD")).isEqualTo(SpendCategory.FOOD);
        assertThat(SpendCategory.from("ETC")).isEqualTo(SpendCategory.ETC);
    }

    /// null·공백을 예외가 아니라 null 로 돌려주는 게 이 메서드의 계약이다.
    /// 여기서 던져버리면 "카테고리를 안 보냄"이 AMOUNT_CATEGORY_CONTENT_REQUIRED 대신
    /// AMOUNT_CATEGORY_INVALID 로 나가 에러 코드가 바뀐다 (Amount.spend 가 미입력을 먼저 걸러낸다).
    @Test
    void from_returns_null_for_blank_so_missing_stays_distinct_from_invalid() {
        assertThat(SpendCategory.from(null)).isNull();
        assertThat(SpendCategory.from("")).isNull();
        assertThat(SpendCategory.from("   ")).isNull();
    }

    @Test
    void from_rejects_unknown_code() {
        // 소문자·한글 라벨·옛 자유 텍스트 모두 코드가 아니다.
        assertThatThrownBy(() -> SpendCategory.from("food"))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.AMOUNT_CATEGORY_INVALID);
        assertThatThrownBy(() -> SpendCategory.from("식비"))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.AMOUNT_CATEGORY_INVALID);
        assertThatThrownBy(() -> SpendCategory.from("카페"))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode").isEqualTo(ErrorCode.AMOUNT_CATEGORY_INVALID);
    }

    /// 저장·전송 키는 name() 이고 label 은 표시 전용이다. 코드를 바꾸면 기존 row 가 매핑을 잃는다.
    @Test
    void codes_are_the_stable_key_not_labels() {
        assertThat(SpendCategory.FOOD.name()).isEqualTo("FOOD");
        assertThat(SpendCategory.FOOD.getLabel()).isEqualTo("식비");
        assertThat(SpendCategory.values()).hasSize(9);
    }
}
