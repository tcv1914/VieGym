package com.viegym.backend.weight;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** docs/05 §4. */
public final class WeightLogDtos {
    private WeightLogDtos() {
    }

    /** Không có userId: luôn ghi cho user hiện tại. Gửi lại cùng ngày thay cả cân nặng lẫn ghi chú. */
    public record SaveWeightLogRequest(
        @NotNull(message = "Vui lòng chọn ngày đo")
        LocalDate logDate,

        // Cùng khoảng với hồ sơ (docs/04 §3.1): kiểm tra dữ liệu nhập, không phải phân loại sức khỏe.
        @NotNull(message = "Vui lòng nhập cân nặng")
        @DecimalMin(value = "30.0", message = "Cân nặng từ 30 đến 300 kg")
        @DecimalMax(value = "300.0", message = "Cân nặng từ 30 đến 300 kg")
        @Digits(integer = 3, fraction = 1, message = "Cân nặng tối đa 1 chữ số thập phân")
        BigDecimal weightKg,

        @Size(max = 500, message = "Ghi chú tối đa 500 ký tự")
        String note
    ) {
        public SaveWeightLogRequest {
            note = note == null || note.isBlank() ? null : note.strip();
        }
    }

    public record WeightLogItem(UUID id, LocalDate logDate, BigDecimal weightKg, String note) {
    }

    public record WeightLogList(List<WeightLogItem> items) {
    }

    /** {@code created} chỉ để controller chọn 201/200 (BR-WL01), không nằm trong body. */
    public record SaveResult(WeightLogItem item, boolean created) {
    }
}
