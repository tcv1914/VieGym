package com.viegym.backend.workout.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Request/response của /workout-logs (docs/05 §8, docs/18). */
public final class LogDtos {
    public static final int MAX_EXERCISES = 20;
    public static final int MAX_SETS = 20;

    private LogDtos() {
    }

    /**
     * Không nhận userId, tên bài, tên buổi hay tổng: server lấy từ lịch/thư viện và tự tính.
     * {@code setNo}/{@code orderNo} do server đánh theo thứ tự mảng (BR-W08).
     */
    public record CreateLogRequest(
        @NotNull(message = "Vui lòng chọn buổi tập")
        UUID scheduleId,

        /** Thời điểm thực tế, có offset hoặc Z; tùy chọn. */
        Instant startedAt,

        Instant endedAt,

        @Size(max = 1000, message = "Ghi chú tối đa 1000 ký tự")
        String note,

        @NotEmpty(message = "Cần ghi ít nhất một bài với một hiệp")
        @Size(max = MAX_EXERCISES, message = "Tối đa " + MAX_EXERCISES + " bài mỗi buổi")
        List<@Valid @NotNull(message = "Bài tập không hợp lệ") LogExerciseRequest> exercises
    ) {
    }

    public record LogExerciseRequest(
        @NotNull(message = "Vui lòng chọn bài tập")
        UUID exerciseId,

        @NotEmpty(message = "Cần ít nhất một hiệp")
        @Size(max = MAX_SETS, message = "Tối đa " + MAX_SETS + " hiệp mỗi bài")
        List<@Valid @NotNull(message = "Hiệp không hợp lệ") SetRequest> sets
    ) {
    }

    /** Mức tạ bắt buộc: bỏ trống không được hiểu là 0 (0 = không dùng tạ ngoài). */
    public record SetRequest(
        @NotNull(message = "Vui lòng nhập số lần")
        @Min(value = 1, message = "Số lần từ 1 đến 1000")
        @Max(value = 1000, message = "Số lần từ 1 đến 1000")
        Integer reps,

        @NotNull(message = "Vui lòng nhập mức tạ (0 nếu không dùng tạ)")
        @DecimalMin(value = "0", message = "Mức tạ từ 0 đến 999,99 kg")
        @DecimalMax(value = "999.99", message = "Mức tạ từ 0 đến 999,99 kg")
        @Digits(integer = 3, fraction = 2, message = "Mức tạ tối đa 2 chữ số thập phân")
        BigDecimal weightKg
    ) {
    }

    public record SetItem(int setNo, int reps, BigDecimal weightKg) {
    }

    public record LogExerciseItem(int orderNo, UUID exerciseId, String exerciseName, List<SetItem> sets) {
    }

    /**
     * {@code totalVolumeKg} = Σ reps × weightKg, chỉ tính tạ ngoài: bài không tạ có volume 0
     * nhưng vẫn được tính vào {@code totalReps}.
     */
    public record LogDetail(UUID id, UUID scheduleId, LocalDate workoutDate, String workoutName, String programName,
                            Instant startedAt, Instant endedAt, String note, Instant createdAt, int exerciseCount,
                            int setCount, int totalReps, BigDecimal totalVolumeKg, List<LogExerciseItem> exercises) {
    }

    public record LogSummary(UUID id, UUID scheduleId, LocalDate workoutDate, String workoutName, String programName,
                             Instant startedAt, Instant endedAt, int exerciseCount, int setCount, int totalReps,
                             BigDecimal totalVolumeKg) {
    }
}
