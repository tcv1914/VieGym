package com.viegym.backend.exercise;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class SearchTextTest {
    @Test
    void removesVietnameseMarksAndCase() {
        assertThat(SearchText.normalize("Đẩy ngực với tạ đơn")).isEqualTo("day nguc voi ta don");
        assertThat(SearchText.normalize("ĐẨY NGỰC")).isEqualTo("day nguc");
        assertThat(SearchText.normalize("Hít đất (Push-up)")).isEqualTo("hit dat (push-up)");
    }

    @Test
    void trimsAndCollapsesWhitespace() {
        assertThat(SearchText.normalize("  day \t  nguc  ")).isEqualTo("day nguc");
        assertThat(SearchText.normalize("   ")).isEmpty();
        assertThat(SearchText.normalize(null)).isEmpty();
    }

    @Test
    void sameResultForComposedAndDecomposedInput() {
        // Bàn phím có thể gửi "ự" dựng sẵn (U+1EF1) hoặc "u" + dấu tổ hợp.
        assertThat(SearchText.normalize("ngực")).isEqualTo(SearchText.normalize("ngực"))
            .isEqualTo("nguc");
    }

    @Test
    void escapesLikeWildcards() {
        assertThat(SearchText.escapeLike("50%_a\\b")).isEqualTo("50\\%\\_a\\\\b");
        assertThat(SearchText.escapeLike("day nguc")).isEqualTo("day nguc");
    }
}
