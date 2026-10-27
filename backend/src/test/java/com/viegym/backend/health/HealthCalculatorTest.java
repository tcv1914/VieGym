package com.viegym.backend.health;

import static org.assertj.core.api.Assertions.assertThat;

import com.viegym.backend.health.HealthCalculator.Input;
import com.viegym.backend.health.HealthCalculator.Result;
import com.viegym.backend.health.entity.ActivityLevel;
import com.viegym.backend.health.entity.Goal;
import com.viegym.backend.health.entity.Sex;
import java.math.BigDecimal;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

/**
 * Giá trị mong đợi tính tay theo docs/04-business-rules.md §3 (không gọi lại code để ra expected).
 * Không cần Spring hay database.
 */
class HealthCalculatorTest {

    // H01 — docs/04 §3.7 ca 1, khớp kich-ban-demo.md.
    @Test
    void demoCaseMaleGainMuscle() {
        Result r = calc(Sex.MALE, 22, "170", "65", ActivityLevel.MODERATE, Goal.GAIN_MUSCLE);
        // BMI 65 / 1,7² = 22,4913…; BMR 650 + 1062,5 − 110 + 5; TDEE × 1,55; +300.
        assertResult(r, "22.49", "1607.5", "2491.6", "2791.6", "117.0", "406.4", "77.5", false);
    }

    // H01 — docs/04 §3.7 ca 2: protein chạm trần 35%.
    @Test
    void proteinCapCaseFemaleLoseWeight() {
        Result r = calc(Sex.FEMALE, 80, "100", "300", ActivityLevel.SEDENTARY, Goal.LOSE_WEIGHT);
        // protein = min(2,0 × 300 = 600; 0,35 × 3176,8 / 4 = 277,97).
        assertResult(r, "300.00", "3064.0", "3676.8", "3176.8", "278.0", "317.7", "88.2", false);
    }

    @Test
    void femaleTargetRaisedToFloor() {
        Result r = calc(Sex.FEMALE, 80, "150", "40", ActivityLevel.SEDENTARY, Goal.LOSE_WEIGHT);
        // BMR 400 + 937,5 − 400 − 161 = 776,5; TDEE 931,8; −500 = 431,8 < max(776,5; 1200).
        // protein min(80; 105) = 80; fat 300 / 9 = 33,33…; carbs (1200 − 320 − 300) / 4 = 145.
        assertResult(r, "17.78", "776.5", "931.8", "1200.0", "80.0", "145.0", "33.3", true);
    }

    @Test
    void maleTargetRaisedToFloorAndCarbsRoundHalfUp() {
        Result r = calc(Sex.MALE, 30, "160", "50", ActivityLevel.SEDENTARY, Goal.LOSE_WEIGHT);
        // BMR 500 + 1000 − 150 + 5 = 1355; TDEE 1626; −500 = 1126 < 1500.
        // carbs (1500 − 400 − 375) / 4 = 181,25 → HALF_UP 181,3 (HALF_EVEN sẽ ra 181,2).
        assertResult(r, "19.53", "1355.0", "1626.0", "1500.0", "100.0", "181.3", "41.7", true);
    }

    // H02 — nam 30 tuổi, 180 cm, 80 kg: BMR = 800 + 1125 − 150 + 5 = 1780.
    @ParameterizedTest
    @CsvSource({
        "SEDENTARY,   2136.0",
        "LIGHT,       2447.5",
        "MODERATE,    2759.0",
        "ACTIVE,      3070.5",
        "VERY_ACTIVE, 3382.0",
    })
    void activityFactors(ActivityLevel level, String expectedTdee) {
        Result r = calc(Sex.MALE, 30, "180", "80", level, Goal.MAINTAIN);
        assertThat(r.bmrKcal()).isEqualByComparingTo("1780");
        assertThat(r.tdeeKcal()).isEqualByComparingTo(expectedTdee);
        assertThat(r.targetKcal()).isEqualByComparingTo(expectedTdee);
    }

    // H03 — cùng người trên, MODERATE (TDEE 2759): delta và hệ số protein theo mục tiêu.
    @ParameterizedTest
    @CsvSource({
        "LOSE_WEIGHT, 2259.0, 160.0",
        "MAINTAIN,    2759.0, 128.0",
        "GAIN_MUSCLE, 3059.0, 144.0",
    })
    void goalDeltaAndProtein(Goal goal, String expectedTarget, String expectedProtein) {
        Result r = calc(Sex.MALE, 30, "180", "80", ActivityLevel.MODERATE, goal);
        assertThat(r.targetKcal()).isEqualByComparingTo(expectedTarget);
        assertThat(r.proteinG()).isEqualByComparingTo(expectedProtein);
        assertThat(r.kcalFloorApplied()).isFalse();
    }

    // H04
    @ParameterizedTest
    @CsvSource({
        "2004-10-27, 2026-10-26, 21",
        "2004-10-27, 2026-10-27, 22",
        // Sinh 29/2: năm không nhuận đủ tuổi từ 1/3.
        "2008-02-29, 2026-02-28, 17",
        "2008-02-29, 2026-03-01, 18",
        "2008-02-29, 2028-02-29, 20",
    })
    void ageInWholeYears(LocalDate dateOfBirth, LocalDate on, int expected) {
        assertThat(HealthCalculator.ageOn(dateOfBirth, on)).isEqualTo(expected);
    }

    @Test
    void macrosAddUpToTarget() {
        Result r = calc(Sex.MALE, 22, "170", "65", ActivityLevel.MODERATE, Goal.GAIN_MUSCLE);
        BigDecimal kcalFromMacros = r.proteinG().multiply(BigDecimal.valueOf(4))
            .add(r.carbsG().multiply(BigDecimal.valueOf(4)))
            .add(r.fatG().multiply(BigDecimal.valueOf(9)));
        // Mỗi macro lệch tối đa 0,05 g do làm tròn → tổng lệch tối đa 0,05 × (4 + 4 + 9) = 0,85 kcal.
        assertThat(kcalFromMacros.subtract(r.targetKcal()).abs()).isLessThanOrEqualTo(new BigDecimal("0.85"));
    }

    private static Result calc(Sex sex, int age, String heightCm, String weightKg, ActivityLevel level, Goal goal) {
        return HealthCalculator.calculate(
            new Input(sex, age, new BigDecimal(heightCm), new BigDecimal(weightKg), level, goal));
    }

    private static void assertResult(Result r, String bmi, String bmr, String tdee, String target,
                                     String protein, String carbs, String fat, boolean floorApplied) {
        // So sánh cả scale: giá trị lưu DB/trả API phải đúng số chữ số thập phân.
        assertThat(r.bmi()).isEqualTo(new BigDecimal(bmi));
        assertThat(r.bmrKcal()).isEqualTo(new BigDecimal(bmr));
        assertThat(r.tdeeKcal()).isEqualTo(new BigDecimal(tdee));
        assertThat(r.targetKcal()).isEqualTo(new BigDecimal(target));
        assertThat(r.proteinG()).isEqualTo(new BigDecimal(protein));
        assertThat(r.carbsG()).isEqualTo(new BigDecimal(carbs));
        assertThat(r.fatG()).isEqualTo(new BigDecimal(fat));
        assertThat(r.kcalFloorApplied()).isEqualTo(floorApplied);
    }
}
