package com.viegym.backend.health.dto;

import com.viegym.backend.health.entity.ActivityLevel;
import com.viegym.backend.health.entity.Goal;
import com.viegym.backend.health.entity.Sex;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * docs/04-business-rules.md §3.1. Tuổi 18–80 và "không ở tương lai" kiểm tra ở service vì
 * phụ thuộc ngày hôm nay theo múi giờ user. Không có userId/BMI/kcal: client không gửi kết quả.
 */
public record HealthProfileRequest(
    @NotNull(message = "Vui lòng chọn giới tính")
    Sex sex,

    @NotNull(message = "Vui lòng nhập ngày sinh")
    LocalDate dateOfBirth,

    @NotNull(message = "Vui lòng nhập chiều cao")
    @DecimalMin(value = "100.0", message = "Chiều cao từ 100 đến 250 cm")
    @DecimalMax(value = "250.0", message = "Chiều cao từ 100 đến 250 cm")
    @Digits(integer = 3, fraction = 1, message = "Chiều cao tối đa 1 chữ số thập phân")
    BigDecimal heightCm,

    @NotNull(message = "Vui lòng nhập cân nặng")
    @DecimalMin(value = "30.0", message = "Cân nặng từ 30 đến 300 kg")
    @DecimalMax(value = "300.0", message = "Cân nặng từ 30 đến 300 kg")
    @Digits(integer = 3, fraction = 1, message = "Cân nặng tối đa 1 chữ số thập phân")
    BigDecimal weightKg,

    @NotNull(message = "Vui lòng chọn mức vận động")
    ActivityLevel activityLevel,

    @NotNull(message = "Vui lòng chọn mục tiêu")
    Goal goal
) {
}
