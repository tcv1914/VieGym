package com.viegym.backend.meal.dto;

import com.viegym.backend.food.entity.DataQuality;
import com.viegym.backend.meal.entity.MealType;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Request/response của /meal-plans (docs/05 §10, docs/23). */
public final class MealDtos {
    private MealDtos() {
    }

    /**
     * Không nhận kcal/macro hay userId: dinh dưỡng lấy từ món trên server (BR-N04); trường lạ
     * trong body bị bỏ qua.
     */
    public record AddEntryRequest(
        @NotNull(message = "Vui lòng chọn ngày")
        LocalDate date,

        @NotNull(message = "Vui lòng chọn bữa")
        MealType mealType,

        @NotNull(message = "Vui lòng chọn món")
        UUID foodId,

        @NotNull(message = "Vui lòng nhập số khẩu phần")
        @DecimalMin(value = "0", inclusive = false, message = "Số khẩu phần phải lớn hơn 0")
        @DecimalMax(value = "20", message = "Số khẩu phần tối đa 20")
        @Digits(integer = 2, fraction = 2, message = "Số khẩu phần tối đa 2 chữ số thập phân")
        BigDecimal servings) {
    }

    /** Cả hai tùy chọn, ít nhất một (kiểm tra ở service). */
    public record UpdateEntryRequest(
        MealType mealType,

        @DecimalMin(value = "0", inclusive = false, message = "Số khẩu phần phải lớn hơn 0")
        @DecimalMax(value = "20", message = "Số khẩu phần tối đa 20")
        @Digits(integer = 2, fraction = 2, message = "Số khẩu phần tối đa 2 chữ số thập phân")
        BigDecimal servings) {
    }

    /** kcal và gram đạm/bột đường/béo, làm tròn 2 chữ số khi trả về (NUT-BR07). */
    public record Nutrients(BigDecimal kcal, BigDecimal proteinG, BigDecimal carbsG, BigDecimal fatG) {
    }

    /**
     * Một mục món. {@code *PerServing} là snapshot lúc thêm (để app xem trước khi sửa số phần);
     * {@code kcal}/{@code proteinG}/... = servings × snapshot.
     */
    public record EntryItem(UUID id, UUID foodId, String foodName, MealType mealType, String servingDescription,
                            BigDecimal servingSize, String servingUnit, BigDecimal servings,
                            BigDecimal kcalPerServing, BigDecimal proteinPerServingG,
                            BigDecimal carbsPerServingG, BigDecimal fatPerServingG, BigDecimal kcal,
                            BigDecimal proteinG, BigDecimal carbsG, BigDecimal fatG, DataQuality dataQuality,
                            Instant createdAt) {
    }

    /**
     * Thực đơn cả ngày, cũng là response của POST/PUT/DELETE để app cập nhật tổng ngay.
     * {@code targets}/{@code remaining} null khi chưa có mục tiêu (UC07-A8); {@code remaining} âm =
     * vượt (A7). Mục tiêu là mục tiêu <b>hiện tại</b>, tính lúc {@code targetsCalculatedAt}
     * (NUT-BR09), kể cả khi xem ngày cũ.
     */
    public record MealPlanView(LocalDate date, int entryCount, Map<MealType, List<EntryItem>> meals,
                               Map<MealType, Nutrients> mealTotals, Nutrients totals, Nutrients targets,
                               Nutrients remaining, Instant targetsCalculatedAt) {
    }
}
