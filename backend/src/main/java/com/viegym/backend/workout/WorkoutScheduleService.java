package com.viegym.backend.workout;

import com.viegym.backend.auth.entity.User;
import com.viegym.backend.auth.repository.UserRepository;
import com.viegym.backend.common.exception.ApiException;
import com.viegym.backend.workout.dto.ScheduleDtos.CreateScheduleRequest;
import com.viegym.backend.workout.dto.ScheduleDtos.DayRef;
import com.viegym.backend.workout.dto.ScheduleDtos.ScheduleDetail;
import com.viegym.backend.workout.dto.ScheduleDtos.ScheduleItem;
import com.viegym.backend.workout.dto.ScheduleDtos.ScheduleList;
import com.viegym.backend.workout.dto.ScheduleDtos.UpdateScheduleRequest;
import com.viegym.backend.workout.entity.ScheduleStatus;
import com.viegym.backend.workout.entity.WorkoutDay;
import com.viegym.backend.workout.entity.WorkoutExercise;
import com.viegym.backend.workout.entity.WorkoutSchedule;
import com.viegym.backend.workout.repository.WorkoutDayRepository;
import com.viegym.backend.workout.repository.WorkoutLogRepository;
import com.viegym.backend.workout.repository.WorkoutScheduleRepository;
import java.time.Clock;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.time.temporal.TemporalAdjusters;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * UC05. Lịch là ngày (DATE theo múi giờ user, BR-G04) + giờ tùy chọn, không phải thời điểm UTC,
 * nên không có chuyện lệch ngày khi đổi múi giờ hiển thị. Ghi lịch khóa hàng users như giáo án.
 */
@Service
public class WorkoutScheduleService {
    /** docs/05 §7. */
    public static final int MAX_RANGE_DAYS = 62;
    /** Giới hạn MVP: một tuần tối đa 35 lịch, trả trọn không cần phân trang (docs/16 §4). */
    public static final int MAX_PER_DAY = 5;

    private final UserRepository userRepository;
    private final WorkoutDayRepository dayRepository;
    private final WorkoutScheduleRepository scheduleRepository;
    private final WorkoutProgramService programService;
    private final WorkoutLogRepository logRepository;
    private final Clock clock;

    public WorkoutScheduleService(UserRepository userRepository, WorkoutDayRepository dayRepository,
                                  WorkoutScheduleRepository scheduleRepository, WorkoutProgramService programService,
                                  WorkoutLogRepository logRepository, Clock clock) {
        this.userRepository = userRepository;
        this.dayRepository = dayRepository;
        this.scheduleRepository = scheduleRepository;
        this.programService = programService;
        this.logRepository = logRepository;
        this.clock = clock;
    }

    /** Khoảng đóng [from, to]; không gửi gì = tuần hiện tại (thứ Hai–Chủ nhật) theo múi giờ user. */
    @Transactional(readOnly = true)
    public ScheduleList list(UUID userId, LocalDate from, LocalDate to, ScheduleStatus status) {
        if (from == null && to == null) {
            from = weekStart(today(findUser(userId)));
            to = from.plusDays(6);
        } else if (from == null || to == null) {
            throw ApiException.validation(from == null ? "from" : "to", "Cần gửi cả from và to");
        }
        if (to.isBefore(from)) {
            throw ApiException.validation("to", "Ngày kết thúc phải từ ngày bắt đầu trở đi");
        }
        if (ChronoUnit.DAYS.between(from, to) + 1 > MAX_RANGE_DAYS) {
            throw ApiException.validation("to", "Khoảng ngày tối đa " + MAX_RANGE_DAYS + " ngày");
        }
        List<WorkoutSchedule> schedules = status == null
            ? scheduleRepository.findInRange(userId, from, to)
            : scheduleRepository.findInRange(userId, from, to, status);
        Map<UUID, UUID> logIds = logIds(schedules.stream().filter(s -> s.getStatus() == ScheduleStatus.COMPLETED)
            .map(WorkoutSchedule::getId).toList());
        return new ScheduleList(from, to, schedules.stream().map(s -> toItem(s, logIds.get(s.getId()))).toList());
    }

    @Transactional(readOnly = true)
    public ScheduleDetail get(UUID userId, UUID id) {
        return toDetail(scheduleRepository.findOwned(id, userId).orElseThrow(WorkoutScheduleService::notFound));
    }

    @Transactional
    public ScheduleDetail create(UUID userId, CreateScheduleRequest request) {
        User user = lockUser(userId);
        // BR-W03: chỉ buổi thuộc giáo án của chính user; buổi của người khác hay của mẫu → 404.
        WorkoutDay day = dayRepository.findOwned(request.workoutDayId(), userId).orElseThrow(() ->
            new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy buổi tập trong giáo án của bạn"));
        if (day.isArchived()) {
            throw new ApiException(HttpStatus.CONFLICT, "INVALID_STATE",
                "Buổi này đã bị gỡ khỏi giáo án, hãy chọn buổi khác");
        }
        checkExercisesUsable(day);
        checkNotPast(request.scheduledDate(), today(user));
        checkDailyLimit(userId, request.scheduledDate());

        WorkoutSchedule schedule = new WorkoutSchedule(userId, day, request.scheduledDate(), request.startTime(),
            normalizeNote(request.note()), now());
        scheduleRepository.saveAndFlush(schedule);
        return toDetail(schedule);
    }

    /**
     * Dời lịch hoặc hủy (BR-W04). Không nhận COMPLETED. Lịch đã COMPLETED/CANCELLED → 409.
     * Khi hủy chỉ đổi trạng thái; ngày/giờ/ghi chú trong body được bỏ qua.
     */
    @Transactional
    public ScheduleDetail update(UUID userId, UUID id, UpdateScheduleRequest request) {
        User user = lockUser(userId);
        if (request.status() == ScheduleStatus.COMPLETED) {
            throw ApiException.validation("status", "Hoàn thành buổi tập bằng cách ghi nhận buổi tập");
        }
        WorkoutSchedule schedule = scheduleRepository.findOwnedForUpdate(id, userId)
            .orElseThrow(WorkoutScheduleService::notFound);
        if (schedule.getStatus() != ScheduleStatus.SCHEDULED) {
            throw new ApiException(HttpStatus.CONFLICT, "INVALID_STATE", schedule.getStatus() == ScheduleStatus.CANCELLED
                ? "Lịch này đã bị hủy" : "Buổi tập này đã hoàn thành");
        }
        Instant now = now();
        if (request.status() == ScheduleStatus.CANCELLED) {
            schedule.cancel(now);
        } else {
            LocalDate date = request.scheduledDate();
            if (!date.equals(schedule.getScheduledDate())) {
                checkNotPast(date, today(user));
                checkDailyLimit(userId, date);
            }
            schedule.reschedule(date, request.startTime(), normalizeNote(request.note()), now);
        }
        scheduleRepository.flush();
        return toDetail(schedule);
    }

    /** Thứ Hai của tuần chứa {@code date}. */
    public static LocalDate weekStart(LocalDate date) {
        return date.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
    }

    private void checkExercisesUsable(WorkoutDay day) {
        Map<String, String> inactive = new LinkedHashMap<>();
        List<WorkoutExercise> exercises = day.getExercises();
        for (int j = 0; j < exercises.size(); j++) {
            if (!exercises.get(j).getExercise().isActive()) {
                inactive.put("exercises[" + j + "].exerciseId", exercises.get(j).getExercise().getName());
            }
        }
        if (!inactive.isEmpty()) {
            throw WorkoutProgramService.exerciseInactive(inactive);
        }
    }

    private static void checkNotPast(LocalDate date, LocalDate today) {
        if (date.isBefore(today)) {
            throw ApiException.validation("scheduledDate", "Không xếp lịch vào ngày đã qua");
        }
    }

    private void checkDailyLimit(UUID userId, LocalDate date) {
        long count = scheduleRepository.countByUserIdAndScheduledDateAndStatusNot(userId, date,
            ScheduleStatus.CANCELLED);
        if (count >= MAX_PER_DAY) {
            throw ApiException.validation("scheduledDate", "Mỗi ngày tối đa " + MAX_PER_DAY + " buổi tập");
        }
    }

    private static String normalizeNote(String note) {
        return note == null || note.isBlank() ? null : note.strip();
    }

    private User lockUser(UUID userId) {
        return userRepository.findForUpdate(userId).orElseThrow(WorkoutScheduleService::userNotFound);
    }

    private User findUser(UUID userId) {
        return userRepository.findById(userId).orElseThrow(WorkoutScheduleService::userNotFound);
    }

    private LocalDate today(User user) {
        return LocalDate.now(clock.withZone(ZoneId.of(user.getTimezone())));
    }

    private Instant now() {
        return clock.instant().truncatedTo(ChronoUnit.MICROS);
    }

    private static ScheduleItem toItem(WorkoutSchedule s, UUID workoutLogId) {
        return new ScheduleItem(s.getId(), s.getScheduledDate(), s.getStartTime(), s.getStatus(), s.getNote(),
            dayRef(s.getWorkoutDay()), workoutLogId);
    }

    /** {@code workoutLogId} cho phép app xác minh sau khi mất mạng lúc ghi buổi tập (docs/18 §4). */
    private ScheduleDetail toDetail(WorkoutSchedule s) {
        WorkoutDay day = s.getWorkoutDay();
        UUID logId = s.getStatus() == ScheduleStatus.COMPLETED ? logIds(List.of(s.getId())).get(s.getId()) : null;
        return new ScheduleDetail(s.getId(), s.getScheduledDate(), s.getStartTime(), s.getStatus(), s.getNote(),
            dayRef(day), logId, programService.toExerciseItems(day));
    }

    private Map<UUID, UUID> logIds(List<UUID> scheduleIds) {
        if (scheduleIds.isEmpty()) {
            return Map.of();
        }
        Map<UUID, UUID> result = new HashMap<>();
        logRepository.logIdsBySchedule(scheduleIds).forEach(r -> result.put((UUID) r[0], (UUID) r[1]));
        return result;
    }

    private static DayRef dayRef(WorkoutDay day) {
        return new DayRef(day.getId(), day.getName(), day.getProgram().getId(), day.getProgram().getName(),
            day.isArchived());
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy lịch tập");
    }

    private static ApiException userNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy tài khoản");
    }
}
