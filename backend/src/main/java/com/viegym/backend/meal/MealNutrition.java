package com.viegym.backend.meal;

import com.viegym.backend.meal.dto.MealDtos.Nutrients;
import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * Cộng dinh dưỡng bằng BigDecimal ở độ chính xác lưu trữ (NUT-BR07): mỗi mục = servings × snapshot
 * (chính xác, 4 chữ số lẻ), tổng cộng các giá trị chưa làm tròn, chỉ làm tròn HALF_UP 2 chữ số khi
 * trả về. Không suy kcal từ macro.
 */
public record MealNutrition(BigDecimal kcal, BigDecimal protein, BigDecimal carbs, BigDecimal fat) {
    public static final MealNutrition ZERO = new MealNutrition(BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO,
        BigDecimal.ZERO);
    static final int SCALE = 2;

    /** Dinh dưỡng của một mục: servings × giá trị một khẩu phần. */
    public static MealNutrition of(BigDecimal servings, BigDecimal kcalPerServing, BigDecimal proteinPerServing,
                                   BigDecimal carbsPerServing, BigDecimal fatPerServing) {
        return new MealNutrition(servings.multiply(kcalPerServing), servings.multiply(proteinPerServing),
            servings.multiply(carbsPerServing), servings.multiply(fatPerServing));
    }

    public MealNutrition plus(MealNutrition other) {
        return new MealNutrition(kcal.add(other.kcal), protein.add(other.protein), carbs.add(other.carbs),
            fat.add(other.fat));
    }

    /** target − this; giữ số âm khi vượt mục tiêu, không kẹp về 0. */
    public MealNutrition remainingOf(MealNutrition target) {
        return new MealNutrition(target.kcal.subtract(kcal), target.protein.subtract(protein),
            target.carbs.subtract(carbs), target.fat.subtract(fat));
    }

    public Nutrients rounded() {
        return new Nutrients(round(kcal), round(protein), round(carbs), round(fat));
    }

    static BigDecimal round(BigDecimal value) {
        return value.setScale(SCALE, RoundingMode.HALF_UP);
    }
}
