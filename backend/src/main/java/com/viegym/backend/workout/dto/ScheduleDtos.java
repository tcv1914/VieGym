package com.viegym.backend.workout.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.viegym.backend.workout.dto.ProgramDtos.ExerciseItem;
import com.viegym.backend.workout.entity.ScheduleStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

/** Request/response của /workout-schedules (docs/05 §7). */
public final class ScheduleDtos {
    private ScheduleDtos() {
    }

    public record CreateScheduleRequest(
        @NotNull(message = "Vui lòng chọn buổi tập")
        UUID workoutDayId,

        @NotNull(message = "Vui lòng chọn ngày")
        LocalDate scheduledDate,

        /** Giờ địa phương theo múi giờ user, "HH:mm"; null = cả ngày. */
        @JsonFormat(pattern = "HH:mm")
        LocalTime startTime,

        @Size(max = 500, message = "Ghi chú tối đa 500 ký tự")
        String note
    ) {
    }

    /** Thay toàn bộ ngày/giờ/ghi chú; {@code status} chỉ SCHEDULED (giữ) hoặc CANCELLED (BR-W04). */
    public record UpdateScheduleRequest(
        @NotNull(message = "Vui lòng chọn ngày")
        LocalDate scheduledDate,

        @JsonFormat(pattern = "HH:mm")
        LocalTime startTime,

        @Size(max = 500, message = "Ghi chú tối đa 500 ký tự")
        String note,

        @NotNull(message = "Vui lòng gửi trạng thái")
        ScheduleStatus status
    ) {
    }

    public record ScheduleList(LocalDate from, LocalDate to, List<ScheduleItem> items) {
    }

    /** {@code workoutLogId}: id log khi lịch đã COMPLETED (ngày 8), còn lại null. */
    public record ScheduleItem(UUID id, LocalDate scheduledDate, @JsonFormat(pattern = "HH:mm") LocalTime startTime,
                               ScheduleStatus status, String note, DayRef workoutDay, UUID workoutLogId) {
    }

    /** {@code archived}: buổi đã bị gỡ khỏi giáo án nhưng lịch này vẫn tập được (BR-W07). */
    public record DayRef(UUID id, String name, UUID programId, String programName, boolean archived) {
    }

    /** Bài lấy từ buổi hiện tại của giáo án (không phải snapshot; snapshot ở log ngày 8). */
    public record ScheduleDetail(UUID id, LocalDate scheduledDate, @JsonFormat(pattern = "HH:mm") LocalTime startTime,
                                 ScheduleStatus status, String note, DayRef workoutDay, UUID workoutLogId,
                                 List<ExerciseItem> exercises) {
    }
}
