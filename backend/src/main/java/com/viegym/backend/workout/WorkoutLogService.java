package com.viegym.backend.workout;

import com.viegym.backend.auth.entity.User;
import com.viegym.backend.auth.repository.UserRepository;
import com.viegym.backend.common.exception.ApiException;
import com.viegym.backend.common.web.PageResponse;
import com.viegym.backend.exercise.entity.Exercise;
import com.viegym.backend.exercise.repository.ExerciseRepository;
import com.viegym.backend.workout.dto.LogDtos.CreateLogRequest;
import com.viegym.backend.workout.dto.LogDtos.LogDetail;
import com.viegym.backend.workout.dto.LogDtos.LogExerciseItem;
import com.viegym.backend.workout.dto.LogDtos.LogExerciseRequest;
import com.viegym.backend.workout.dto.LogDtos.LogSummary;
import com.viegym.backend.workout.dto.LogDtos.SetItem;
import com.viegym.backend.workout.dto.LogDtos.SetRequest;
import com.viegym.backend.workout.entity.ScheduleStatus;
import com.viegym.backend.workout.entity.WorkoutDay;
import com.viegym.backend.workout.entity.WorkoutExercise;
import com.viegym.backend.workout.entity.WorkoutLog;
import com.viegym.backend.workout.entity.WorkoutLogExercise;
import com.viegym.backend.workout.entity.WorkoutSchedule;
import com.viegym.backend.workout.entity.WorkoutSetLog;
import com.viegym.backend.workout.repository.WorkoutLogRepository;
import com.viegym.backend.workout.repository.WorkoutScheduleRepository;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * UC06 — ghi nhận buổi tập (docs/18). Tạo log + bài + hiệp và chuyển lịch sang COMPLETED trong
 * cùng một giao dịch (BR-W05). Khóa hàng users rồi hàng lịch, cùng thứ tự với sửa/hủy lịch ngày 7,
 * nên hủy và hoàn thành cùng một lịch chạy tuần tự, không thể cùng thành công.
 */
@Service
public class WorkoutLogService {
    /** Đồng hồ điện thoại có thể lệch máy chủ một chút. */
    static final Duration CLOCK_SKEW = Duration.ofMinutes(5);
    static final Duration MAX_DURATION = Duration.ofHours(24);
    static final int MAX_RANGE_DAYS = 366;
    static final int MAX_PAGE_SIZE = 100;
    private static final LocalDate MIN_DATE = LocalDate.of(2000, 1, 1);
    private static final LocalDate MAX_DATE = LocalDate.of(9999, 12, 31);

    private final UserRepository userRepository;
    private final WorkoutScheduleRepository scheduleRepository;
    private final WorkoutLogRepository logRepository;
    private final ExerciseRepository exerciseRepository;
    private final Clock clock;

    public WorkoutLogService(UserRepository userRepository, WorkoutScheduleRepository scheduleRepository,
                             WorkoutLogRepository logRepository, ExerciseRepository exerciseRepository, Clock clock) {
        this.userRepository = userRepository;
        this.scheduleRepository = scheduleRepository;
        this.logRepository = logRepository;
        this.exerciseRepository = exerciseRepository;
        this.clock = clock;
    }

    @Transactional
    public LogDetail create(UUID userId, CreateLogRequest request) {
        User user = userRepository.findForUpdate(userId).orElseThrow(WorkoutLogService::userNotFound);
        WorkoutSchedule schedule = scheduleRepository.findOwnedForUpdate(request.scheduleId(), userId)
            .orElseThrow(WorkoutLogService::scheduleNotFound);

        // Gửi lặp (bấm hai lần, gửi lại sau khi mất mạng): không tạo log thứ hai, trả id log hiện có
        // để app mở ra (BR-W06). Kiểm tra trước trạng thái vì lịch đã COMPLETED từ lần gửi đầu.
        logRepository.findByScheduleId(schedule.getId()).ifPresent(existing -> {
            throw new ApiException(HttpStatus.CONFLICT, "WORKOUT_ALREADY_LOGGED",
                "Buổi tập này đã được ghi nhận", null, Map.of("workoutLogId", existing.getId()));
        });
        switch (schedule.getStatus()) {
            case CANCELLED -> throw invalidState("Lịch này đã bị hủy, không ghi nhận được");
            // Không xảy ra nếu mọi đường ghi COMPLETED đều đi qua đây; không trả thành công giả.
            case COMPLETED -> throw invalidState("Buổi tập đã hoàn thành nhưng không tìm thấy kết quả");
            case SCHEDULED -> {
            }
        }
        // BR-W09: lịch tương lai không ghi được; muốn tập sớm thì dời lịch về hôm nay trước.
        if (schedule.getScheduledDate().isAfter(today(user))) {
            throw invalidState("Chưa tới ngày của buổi tập này. Hãy dời lịch về hôm nay nếu muốn tập sớm.");
        }
        Instant now = now();
        checkTimes(request.startedAt(), request.endedAt(), now);

        WorkoutDay day = schedule.getWorkoutDay();
        Map<UUID, Exercise> exercises = loadExercises(request.exercises(), day);

        WorkoutLog log = new WorkoutLog(userId, schedule.getId(), schedule.getScheduledDate(), day.getName(),
            day.getProgram().getName(), truncate(request.startedAt()), truncate(request.endedAt()),
            normalizeNote(request.note()), now);
        int orderNo = 1;
        for (LogExerciseRequest item : request.exercises()) {
            WorkoutLogExercise logExercise = log.addExercise(exercises.get(item.exerciseId()), orderNo++, now);
            int setNo = 1;
            for (SetRequest set : item.sets()) {
                logExercise.addSet(setNo++, set.reps(), set.weightKg().setScale(2, RoundingMode.UNNECESSARY), now);
            }
        }
        logRepository.save(log);
        schedule.complete(now);
        // Lộ lỗi ràng buộc ngay trong giao dịch này: lỗi thì rollback cả log lẫn trạng thái lịch.
        logRepository.flush();
        return toDetail(log);
    }

    @Transactional(readOnly = true)
    public LogDetail get(UUID userId, UUID id) {
        return toDetail(logRepository.findOwned(id, userId).orElseThrow(WorkoutLogService::logNotFound));
    }

    /** Khoảng đóng [from, to] theo ngày tập; thiếu một đầu = không giới hạn đầu đó. */
    @Transactional(readOnly = true)
    public PageResponse<LogSummary> list(UUID userId, LocalDate from, LocalDate to, int page, int size) {
        if (page < 0) {
            throw ApiException.validation("page", "Số trang phải từ 0");
        }
        if (size < 1 || size > MAX_PAGE_SIZE) {
            throw ApiException.validation("size", "Kích thước trang phải từ 1 đến " + MAX_PAGE_SIZE);
        }
        if (from != null && to != null) {
            if (to.isBefore(from)) {
                throw ApiException.validation("to", "Ngày kết thúc phải từ ngày bắt đầu trở đi");
            }
            if (ChronoUnit.DAYS.between(from, to) + 1 > MAX_RANGE_DAYS) {
                throw ApiException.validation("to", "Khoảng ngày tối đa " + MAX_RANGE_DAYS + " ngày");
            }
        }
        Page<WorkoutLog> logs = logRepository.findPage(userId, from == null ? MIN_DATE : from,
            to == null ? MAX_DATE : to, PageRequest.of(page, size));
        Map<UUID, Totals> totals = totals(logs.getContent().stream().map(WorkoutLog::getId).toList());
        return PageResponse.of(logs, l -> {
            Totals t = totals.getOrDefault(l.getId(), Totals.EMPTY);
            return new LogSummary(l.getId(), l.getScheduleId(), l.getWorkoutDate(), l.getWorkoutName(),
                l.getProgramName(), l.getStartedAt(), l.getEndedAt(), t.exercises(), t.sets(), t.reps(), t.volume());
        });
    }

    /**
     * Bài trong buổi đã xếp được ghi kể cả khi đã bị ẩn khỏi thư viện (người dùng đang ghi lại việc
     * đã làm). Bài ngoài kế hoạch phải còn hoạt động (BR-W08) → nếu không, 422 EXERCISE_INACTIVE.
     */
    private Map<UUID, Exercise> loadExercises(List<LogExerciseRequest> items, WorkoutDay day) {
        Set<UUID> seen = new HashSet<>();
        for (int i = 0; i < items.size(); i++) {
            if (!seen.add(items.get(i).exerciseId())) {
                throw ApiException.validation(exercisePath(i), "Bài này đã có trong buổi, hãy gộp các hiệp vào một bài");
            }
        }
        Map<UUID, Exercise> found = exerciseRepository.findAllById(seen).stream()
            .collect(Collectors.toMap(Exercise::getId, Function.identity()));
        Set<UUID> planned = day.getExercises().stream().map(WorkoutExercise::getExercise).map(Exercise::getId)
            .collect(Collectors.toSet());
        Map<String, String> inactive = new LinkedHashMap<>();
        for (int i = 0; i < items.size(); i++) {
            Exercise exercise = found.get(items.get(i).exerciseId());
            if (exercise == null) {
                throw ApiException.validation(exercisePath(i), "Không tìm thấy bài tập");
            }
            if (!exercise.isActive() && !planned.contains(exercise.getId())) {
                inactive.put(exercisePath(i), exercise.getName());
            }
        }
        if (!inactive.isEmpty()) {
            throw WorkoutProgramService.exerciseInactive(inactive);
        }
        return found;
    }

    private static void checkTimes(Instant startedAt, Instant endedAt, Instant now) {
        Instant latest = now.plus(CLOCK_SKEW);
        if (startedAt != null && startedAt.isAfter(latest)) {
            throw ApiException.validation("startedAt", "Thời điểm bắt đầu không được ở tương lai");
        }
        if (endedAt != null && endedAt.isAfter(latest)) {
            throw ApiException.validation("endedAt", "Thời điểm kết thúc không được ở tương lai");
        }
        if (startedAt != null && endedAt != null) {
            if (endedAt.isBefore(startedAt)) {
                throw ApiException.validation("endedAt", "Thời điểm kết thúc phải sau thời điểm bắt đầu");
            }
            if (Duration.between(startedAt, endedAt).compareTo(MAX_DURATION) > 0) {
                throw ApiException.validation("endedAt", "Một buổi tập tối đa 24 giờ");
            }
        }
    }

    private LogDetail toDetail(WorkoutLog log) {
        int sets = 0;
        int reps = 0;
        BigDecimal volume = BigDecimal.ZERO;
        List<LogExerciseItem> exercises = new ArrayList<>();
        for (WorkoutLogExercise e : log.getExercises()) {
            List<SetItem> setItems = new ArrayList<>();
            for (WorkoutSetLog s : e.getSets()) {
                setItems.add(new SetItem(s.getSetNo(), s.getReps(), s.getWeightKg()));
                sets++;
                reps += s.getReps();
                volume = volume.add(s.getWeightKg().multiply(BigDecimal.valueOf(s.getReps())));
            }
            exercises.add(new LogExerciseItem(e.getOrderNo(), e.getExerciseId(), e.getExerciseName(), setItems));
        }
        return new LogDetail(log.getId(), log.getScheduleId(), log.getWorkoutDate(), log.getWorkoutName(),
            log.getProgramName(), log.getStartedAt(), log.getEndedAt(), log.getNote(), log.getCreatedAt(),
            exercises.size(), sets, reps, volume.setScale(2, RoundingMode.UNNECESSARY), exercises);
    }

    private Map<UUID, Totals> totals(List<UUID> logIds) {
        if (logIds.isEmpty()) {
            return Map.of();
        }
        Map<UUID, Totals> result = new HashMap<>();
        for (Object[] row : logRepository.totals(logIds)) {
            result.put((UUID) row[0], new Totals(((Number) row[1]).intValue(), ((Number) row[2]).intValue(),
                ((Number) row[3]).intValue(), toDecimal(row[4])));
        }
        return result;
    }

    private static BigDecimal toDecimal(Object value) {
        BigDecimal decimal = value instanceof BigDecimal d ? d : new BigDecimal(value.toString());
        return decimal.setScale(2, RoundingMode.HALF_UP);
    }

    private record Totals(int exercises, int sets, int reps, BigDecimal volume) {
        static final Totals EMPTY = new Totals(0, 0, 0, BigDecimal.ZERO.setScale(2));
    }

    private static String exercisePath(int index) {
        return "exercises[" + index + "].exerciseId";
    }

    private static String normalizeNote(String note) {
        return note == null || note.isBlank() ? null : note.strip();
    }

    private static Instant truncate(Instant instant) {
        return instant == null ? null : instant.truncatedTo(ChronoUnit.MICROS);
    }

    private LocalDate today(User user) {
        return LocalDate.now(clock.withZone(ZoneId.of(user.getTimezone())));
    }

    private Instant now() {
        return clock.instant().truncatedTo(ChronoUnit.MICROS);
    }

    private static ApiException invalidState(String message) {
        return new ApiException(HttpStatus.CONFLICT, "INVALID_STATE", message);
    }

    private static ApiException scheduleNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy lịch tập");
    }

    private static ApiException logNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy buổi tập đã ghi");
    }

    private static ApiException userNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy tài khoản");
    }
}
