package com.viegym.backend.health;

import com.viegym.backend.health.entity.ActivityLevel;
import com.viegym.backend.health.entity.Goal;
import com.viegym.backend.health.entity.Sex;
import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.Period;

/**
 * Công thức docs/04-business-rules.md §3 (Mifflin-St Jeor + chính sách mục tiêu đã chốt).
 * Không gọi database/HTTP/AI; ngày tính do nơi gọi truyền vào. Đổi hằng số nào ở đây thì
 * tăng {@link #FORMULA_VERSION} và cập nhật docs/11-health-calculation-rules.md cùng test.
 */
public final class HealthCalculator {
    public static final String FORMULA_VERSION = "MSJ-v1";
    public static final int MIN_AGE = 18;
    public static final int MAX_AGE = 80;

    // Độ chính xác cho phép chia không hết (BMI, fat); chỉ làm tròn ở bước cuối (BR-G06).
    private static final MathContext MC = MathContext.DECIMAL64;
    private static final BigDecimal KCAL_PER_G_PROTEIN_OR_CARB = BigDecimal.valueOf(4);
    private static final BigDecimal KCAL_PER_G_FAT = BigDecimal.valueOf(9);
    private static final BigDecimal PROTEIN_MAX_SHARE = new BigDecimal("0.35");
    private static final BigDecimal FAT_SHARE = new BigDecimal("0.25");

    private HealthCalculator() {
    }

    public record Input(Sex sex, int age, BigDecimal heightCm, BigDecimal weightKg,
                        ActivityLevel activityLevel, Goal goal) {
    }

    /** Đã làm tròn theo docs/04 §3.6: BMI 2 chữ số, còn lại 1 chữ số, HALF_UP. */
    public record Result(BigDecimal bmi, BigDecimal bmrKcal, BigDecimal tdeeKcal, BigDecimal targetKcal,
                         BigDecimal proteinG, BigDecimal carbsG, BigDecimal fatG, boolean kcalFloorApplied) {
    }

    /**
     * Năm tròn. Sinh 29/2 thì năm không nhuận tính đủ tuổi từ 1/3 (cách của {@link Period}).
     */
    public static int ageOn(LocalDate dateOfBirth, LocalDate date) {
        return Period.between(dateOfBirth, date).getYears();
    }

    public static Result calculate(Input in) {
        BigDecimal heightM = in.heightCm().movePointLeft(2);
        BigDecimal bmi = in.weightKg().divide(heightM.multiply(heightM), MC);

        BigDecimal bmr = BigDecimal.TEN.multiply(in.weightKg())
            .add(new BigDecimal("6.25").multiply(in.heightCm()))
            .subtract(BigDecimal.valueOf(5L * in.age()))
            .add(sexConstant(in.sex()));
        BigDecimal tdee = bmr.multiply(activityFactor(in.activityLevel()));

        BigDecimal target = tdee.add(goalDelta(in.goal()));
        BigDecimal floor = bmr.max(minimumKcal(in.sex()));
        boolean floorApplied = target.compareTo(floor) < 0;
        if (floorApplied) {
            target = floor;
        }

        BigDecimal proteinByWeight = proteinPerKg(in.goal()).multiply(in.weightKg());
        BigDecimal proteinCap = PROTEIN_MAX_SHARE.multiply(target).divide(KCAL_PER_G_PROTEIN_OR_CARB, MC);
        BigDecimal protein = proteinByWeight.min(proteinCap);
        BigDecimal fatKcal = FAT_SHARE.multiply(target);
        BigDecimal fat = fatKcal.divide(KCAL_PER_G_FAT, MC);
        // Dùng fatKcal chính xác thay vì fat_g × 9: fat_g đã bị cắt ở chữ số thứ 16 nên
        // nhân lại có thể làm carbs 181,25 thành 181,2499… rồi làm tròn sai.
        BigDecimal carbs = target
            .subtract(protein.multiply(KCAL_PER_G_PROTEIN_OR_CARB))
            .subtract(fatKcal)
            .divide(KCAL_PER_G_PROTEIN_OR_CARB, MC);
        // Trần protein 35% + fat 25% giữ carbs ≥ 40%; âm nghĩa là công thức bị sửa sai.
        if (carbs.signum() < 0) {
            throw new IllegalStateException("carbs_g âm: kiểm tra lại chính sách macro");
        }

        return new Result(round(bmi, 2), round(bmr, 1), round(tdee, 1), round(target, 1),
            round(protein, 1), round(carbs, 1), round(fat, 1), floorApplied);
    }

    private static BigDecimal sexConstant(Sex sex) {
        return switch (sex) {
            case MALE -> BigDecimal.valueOf(5);
            case FEMALE -> BigDecimal.valueOf(-161);
        };
    }

    private static BigDecimal activityFactor(ActivityLevel level) {
        return switch (level) {
            case SEDENTARY -> new BigDecimal("1.2");
            case LIGHT -> new BigDecimal("1.375");
            case MODERATE -> new BigDecimal("1.55");
            case ACTIVE -> new BigDecimal("1.725");
            case VERY_ACTIVE -> new BigDecimal("1.9");
        };
    }

    private static BigDecimal goalDelta(Goal goal) {
        return switch (goal) {
            case LOSE_WEIGHT -> BigDecimal.valueOf(-500);
            case MAINTAIN -> BigDecimal.ZERO;
            case GAIN_MUSCLE -> BigDecimal.valueOf(300);
        };
    }

    private static BigDecimal minimumKcal(Sex sex) {
        return switch (sex) {
            case MALE -> BigDecimal.valueOf(1500);
            case FEMALE -> BigDecimal.valueOf(1200);
        };
    }

    private static BigDecimal proteinPerKg(Goal goal) {
        return switch (goal) {
            case LOSE_WEIGHT -> new BigDecimal("2.0");
            case MAINTAIN -> new BigDecimal("1.6");
            case GAIN_MUSCLE -> new BigDecimal("1.8");
        };
    }

    private static BigDecimal round(BigDecimal value, int scale) {
        return value.setScale(scale, RoundingMode.HALF_UP);
    }
}
