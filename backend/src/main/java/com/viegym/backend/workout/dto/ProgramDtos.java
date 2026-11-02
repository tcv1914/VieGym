package com.viegym.backend.workout.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;

/** Request/response của /workout-programs (docs/05 §6). */
public final class ProgramDtos {
    public static final int MAX_DAYS = 7;
    public static final int MAX_EXERCISES_PER_DAY = 15;

    private ProgramDtos() {
    }

    /**
     * POST: {@code templateId} (sao chép mẫu) hoặc {@code name} + {@code days} (tự tạo), không cả hai.
     * PUT: {@code name} + {@code days} + {@code version}. Không có userId/isTemplate: lấy từ token và server.
     * {@code activate}: POST null = không kích hoạt; PUT null = giữ nguyên trạng thái.
     */
    public record ProgramRequest(
        UUID templateId,

        @Size(max = 100, message = "Tên giáo án tối đa 100 ký tự")
        String name,

        @Size(max = 1000, message = "Mô tả tối đa 1000 ký tự")
        String description,

        Boolean activate,

        Integer version,

        @Size(min = 1, max = MAX_DAYS, message = "Giáo án có từ 1 đến " + MAX_DAYS + " buổi")
        List<@Valid @NotNull(message = "Buổi không hợp lệ") DayRequest> days
    ) {
    }

    /** {@code id}: chỉ ở PUT, buổi có sẵn muốn giữ (lịch đã xếp vẫn trỏ vào nó). */
    public record DayRequest(
        UUID id,

        @NotBlank(message = "Vui lòng nhập tên buổi")
        @Size(max = 100, message = "Tên buổi tối đa 100 ký tự")
        String name,

        @NotNull(message = "Buổi cần ít nhất một bài")
        @Size(min = 1, max = MAX_EXERCISES_PER_DAY,
            message = "Mỗi buổi có từ 1 đến " + MAX_EXERCISES_PER_DAY + " bài")
        List<@Valid @NotNull(message = "Bài không hợp lệ") ExerciseRequest> exercises
    ) {
    }

    /** Khoảng giá trị là giới hạn kỹ thuật (docs/03 §5), không phải khuyến nghị luyện tập. */
    public record ExerciseRequest(
        @NotNull(message = "Vui lòng chọn bài tập")
        UUID exerciseId,

        @NotNull(message = "Vui lòng nhập số hiệp")
        @Min(value = 1, message = "Số hiệp từ 1 đến 10")
        @Max(value = 10, message = "Số hiệp từ 1 đến 10")
        Integer targetSets,

        @NotNull(message = "Vui lòng nhập số lần")
        @Min(value = 1, message = "Số lần từ 1 đến 100")
        @Max(value = 100, message = "Số lần từ 1 đến 100")
        Integer targetReps,

        @NotNull(message = "Vui lòng nhập thời gian nghỉ")
        @Min(value = 0, message = "Thời gian nghỉ từ 0 đến 600 giây")
        @Max(value = 600, message = "Thời gian nghỉ từ 0 đến 600 giây")
        Integer restSeconds
    ) {
    }

    public record ProgramList(List<ProgramSummary> items) {
    }

    public record ProgramSummary(UUID id, String name, String description, boolean isTemplate, boolean isActive,
                                 int dayCount) {
    }

    /** Chỉ có buổi chưa archive. {@code version} gửi lại khi PUT. */
    public record ProgramDetail(UUID id, String name, String description, boolean isTemplate, boolean isActive,
                                UUID sourceTemplateId, int version, List<DayItem> days) {
    }

    public record DayItem(UUID id, int dayOrder, String name, List<ExerciseItem> exercises) {
    }

    /** {@code exerciseActive = false}: bài đã bị ẩn, app đánh dấu cần thay (422 khi lưu/xếp lịch). */
    public record ExerciseItem(UUID id, int orderNo, UUID exerciseId, String exerciseName, boolean exerciseActive,
                               String thumbnailUrl, int targetSets, int targetReps, int restSeconds) {
    }
}
