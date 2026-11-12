package com.viegym.backend.ai;

import com.fasterxml.jackson.annotation.JsonFormat;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

/**
 * Context gửi ai-service (BR-AI03). Chỉ dữ liệu của user đang đăng nhập; không email, tên, token,
 * id nội bộ. Thiếu dữ liệu → {@code null}/rỗng kèm trạng thái, không điền số giả.
 */
public record AiContext(LocalDate today, String timezone, String weekday, Profile profile, Targets targets,
                        MealPlan todayMealPlan, List<Workout> recentWorkouts, List<Schedule> upcomingSchedules) {

    /** {@code status}: READY hoặc MISSING (khi đó các trường khác null). */
    public record Profile(String status, String sex, Integer age, BigDecimal heightCm, BigDecimal weightKg,
                          String activityLevel, String goal, BigDecimal bmi) {
        public static final Profile MISSING = new Profile("MISSING", null, null, null, null, null, null, null);
    }

    /** Mục tiêu hiện tại (NUT-BR09). */
    public record Targets(BigDecimal kcal, BigDecimal proteinG, BigDecimal carbsG, BigDecimal fatG,
                          Instant calculatedAt) {
    }

    public record Nutrients(BigDecimal kcal, BigDecimal proteinG, BigDecimal carbsG, BigDecimal fatG) {
    }

    /**
     * {@code dataQuality}: SOURCED (nguồn), ESTIMATED (ước lượng), DEMO (minh họa — không dùng tư vấn,
     * docs/20). {@code remaining} null khi chưa có mục tiêu; âm = vượt.
     */
    public record MealEntry(String mealType, String food, BigDecimal servings, String servingDescription,
                            BigDecimal kcal, BigDecimal proteinG, BigDecimal carbsG, BigDecimal fatG,
                            String dataQuality) {
    }

    public record MealPlan(int entryCount, List<MealEntry> entries, Nutrients totals, Nutrients remaining) {
    }

    public record Workout(LocalDate date, String workoutName, String programName, int exerciseCount, int setCount,
                          int totalReps, BigDecimal totalVolumeKg) {
    }

    public record Schedule(LocalDate date, @JsonFormat(pattern = "HH:mm") LocalTime startTime, String workoutName,
                           String programName) {
    }
}
