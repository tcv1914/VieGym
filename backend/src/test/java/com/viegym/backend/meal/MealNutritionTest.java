package com.viegym.backend.meal;

import static org.assertj.core.api.Assertions.assertThat;

import com.viegym.backend.meal.dto.MealDtos.Nutrients;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

/** Phép cộng thực đơn (plan ngày 10 §4, NUT-BR02/03/07). */
class MealNutritionTest {
    private static BigDecimal d(String value) {
        return new BigDecimal(value);
    }

    private static MealNutrition foodA(String servings) {
        return MealNutrition.of(d(servings), d("200"), d("10"), d("30"), d("4"));
    }

    private static MealNutrition foodB(String servings) {
        return MealNutrition.of(d(servings), d("100"), d("5"), d("15"), d("2"));
    }

    private static void assertNutrients(Nutrients n, String kcal, String protein, String carbs, String fat) {
        assertThat(n.kcal()).isEqualByComparingTo(kcal);
        assertThat(n.proteinG()).isEqualByComparingTo(protein);
        assertThat(n.carbsG()).isEqualByComparingTo(carbs);
        assertThat(n.fatG()).isEqualByComparingTo(fat);
        assertThat(n.kcal().scale()).isEqualTo(2);
    }

    @Test
    void fixtureFromPlan() {
        // A×1.5 + B×2 → 500/25/75/10; đổi A thành 1 phần → 400/20/60/8; xóa B → 200/10/30/4.
        assertNutrients(foodA("1.5").plus(foodB("2")).rounded(), "500", "25", "75", "10");
        assertNutrients(foodA("1").plus(foodB("2")).rounded(), "400", "20", "60", "8");
        assertNutrients(MealNutrition.ZERO.plus(foodA("1")).rounded(), "200", "10", "30", "4");
    }

    @Test
    void roundsOnlyTheFinalSum() {
        // Mỗi mục 0.5 × 0.01 = 0.005 → hiển thị 0.01; tổng chính xác 0.01, không phải 0.01 + 0.01.
        MealNutrition item = MealNutrition.of(d("0.5"), d("0.01"), d("0.01"), d("0.01"), d("0.01"));
        assertNutrients(item.rounded(), "0.01", "0.01", "0.01", "0.01");
        assertNutrients(item.plus(item).rounded(), "0.01", "0.01", "0.01", "0.01");
        // HALF_UP: 0.125 → 0.13.
        assertThat(MealNutrition.of(d("0.25"), d("0.5"), d("0"), d("0"), d("0")).rounded().kcal())
            .isEqualByComparingTo("0.13");
    }

    @Test
    void remainingKeepsNegativeWhenOverTarget() {
        MealNutrition target = new MealNutrition(d("2000.0"), d("100.0"), d("250.0"), d("60.0"));
        assertNutrients(foodA("1.5").plus(foodB("2")).remainingOf(target).rounded(), "1500", "75", "175", "50");
        assertNutrients(foodA("12").remainingOf(target).rounded(), "-400", "-20", "-110", "12");
    }
}
