package com.viegym.backend.dashboard;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.viegym.backend.health.entity.Goal;
import com.viegym.backend.meal.dto.MealDtos.Nutrients;
import com.viegym.backend.workout.entity.ScheduleStatus;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

/** Response của GET /dashboard (docs/05 §11, docs/25). Mọi khối luôn có mặt; thiếu dữ liệu → null/0/rỗng. */
public final class DashboardDtos {
    private DashboardDtos() {
    }

    public record DashboardView(LocalDate date, String timezone, Health health, Nutrition nutrition,
                                Training training, Instant generatedAt) {
    }

    /**
     * {@code hasProfile=false} → các trường còn lại null. {@code latestWeightLog} luôn null cho tới
     * khi có nhật ký cân nặng (ngày 13).
     */
    public record Health(boolean hasProfile, BigDecimal weightKg, BigDecimal heightCm, BigDecimal bmi, Goal goal,
                         WeightLogRef latestWeightLog) {
    }

    public record WeightLogRef(LocalDate logDate, BigDecimal weightKg) {
    }

    /**
     * Lấy nguyên từ thực đơn ngày (docs/23 §3). {@code targets}/{@code remaining} null khi chưa có
     * mục tiêu; {@code remaining} âm = vượt. Mục tiêu là mục tiêu hiện tại (NUT-BR09).
     */
    public record Nutrition(int entryCount, Nutrients totals, Nutrients targets, Nutrients remaining,
                            Instant targetsCalculatedAt) {
    }

    /**
     * {@code today}: lịch của {@code date} (kể cả đã hủy). {@code week}: tuần thứ Hai–Chủ nhật chứa
     * {@code date}. {@code next}: buổi SCHEDULED sớm nhất từ hôm nay <b>thực</b> trong 30 ngày, không
     * phụ thuộc {@code date}.
     */
    public record Training(List<ScheduleRef> today, WeekStats week, ScheduleRef next) {
    }

    public record ScheduleRef(UUID scheduleId, LocalDate scheduledDate,
                              @JsonFormat(pattern = "HH:mm") LocalTime startTime, String name, String programName,
                              ScheduleStatus status, UUID workoutLogId) {
    }

    /**
     * {@code scheduled} = số lịch không hủy (mẫu số); {@code completed} ⊂ scheduled;
     * {@code cancelled} chỉ để hiển thị, không vào mẫu số.
     */
    public record WeekStats(LocalDate from, LocalDate to, int scheduled, int completed, int cancelled) {
    }
}
