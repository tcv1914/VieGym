package com.viegym.backend.workout;

import com.viegym.backend.auth.repository.UserRepository;
import com.viegym.backend.common.exception.ApiException;
import com.viegym.backend.exercise.MediaUrlResolver;
import com.viegym.backend.exercise.entity.Exercise;
import com.viegym.backend.exercise.repository.ExerciseRepository;
import com.viegym.backend.workout.dto.ProgramDtos.DayItem;
import com.viegym.backend.workout.dto.ProgramDtos.DayRequest;
import com.viegym.backend.workout.dto.ProgramDtos.ExerciseItem;
import com.viegym.backend.workout.dto.ProgramDtos.ExerciseRequest;
import com.viegym.backend.workout.dto.ProgramDtos.ProgramDetail;
import com.viegym.backend.workout.dto.ProgramDtos.ProgramList;
import com.viegym.backend.workout.dto.ProgramDtos.ProgramRequest;
import com.viegym.backend.workout.dto.ProgramDtos.ProgramSummary;
import com.viegym.backend.workout.entity.WorkoutDay;
import com.viegym.backend.workout.entity.WorkoutExercise;
import com.viegym.backend.workout.entity.WorkoutProgram;
import com.viegym.backend.workout.repository.WorkoutProgramRepository;
import com.viegym.backend.workout.repository.WorkoutScheduleRepository;
import jakarta.persistence.EntityManager;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * UC04. Mọi thao tác ghi khóa hàng {@code users} trước (điểm khóa chung với lịch tập), nên các
 * request của cùng user chạy tuần tự: không có hai giáo án active, không vượt giới hạn số lượng,
 * không xóa buổi trong lúc một request khác đang xếp lịch vào buổi đó.
 */
@Service
public class WorkoutProgramService {
    /** Giới hạn MVP để danh sách không cần phân trang (docs/16 §3). */
    public static final int MAX_PROGRAMS_PER_USER = 20;

    // Lớn hơn số buổi tối đa: thứ tự tạm không đụng thứ tự thật 1..7.
    private static final int ORDER_OFFSET = 100;

    private final UserRepository userRepository;
    private final WorkoutProgramRepository programRepository;
    private final WorkoutScheduleRepository scheduleRepository;
    private final ExerciseRepository exerciseRepository;
    private final MediaUrlResolver mediaUrls;
    private final EntityManager entityManager;
    private final Clock clock;

    public WorkoutProgramService(UserRepository userRepository, WorkoutProgramRepository programRepository,
                                 WorkoutScheduleRepository scheduleRepository, ExerciseRepository exerciseRepository,
                                 MediaUrlResolver mediaUrls, EntityManager entityManager, Clock clock) {
        this.userRepository = userRepository;
        this.programRepository = programRepository;
        this.scheduleRepository = scheduleRepository;
        this.exerciseRepository = exerciseRepository;
        this.mediaUrls = mediaUrls;
        this.entityManager = entityManager;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public ProgramList list(UUID userId, String scope) {
        List<WorkoutProgram> programs = switch (scope == null ? "mine" : scope) {
            case "mine" -> programRepository.findByUserIdOrderByCreatedAtDescIdAsc(userId);
            case "templates" -> programRepository.findByTemplateTrueOrderByNameAsc();
            default -> throw ApiException.validation("scope", "Chỉ nhận mine hoặc templates");
        };
        return new ProgramList(programs.stream()
            .map(p -> new ProgramSummary(p.getId(), p.getName(), p.getDescription(), p.isTemplate(), p.isActive(),
                p.currentDays().size()))
            .toList());
    }

    /** Giáo án của mình hoặc giáo án mẫu; của người khác → 404 như không tồn tại. */
    @Transactional(readOnly = true)
    public ProgramDetail get(UUID userId, UUID id) {
        WorkoutProgram program = programRepository.findById(id)
            .filter(p -> p.isTemplate() || p.isOwnedBy(userId))
            .orElseThrow(WorkoutProgramService::notFound);
        return toDetail(program);
    }

    @Transactional
    public ProgramDetail create(UUID userId, ProgramRequest request) {
        lockUser(userId);
        if (request.version() != null) {
            throw ApiException.validation("version", "Chỉ gửi version khi sửa giáo án");
        }
        if (programRepository.countByUserId(userId) >= MAX_PROGRAMS_PER_USER) {
            throw new ApiException(HttpStatus.CONFLICT, "INVALID_STATE",
                "Bạn đã có tối đa " + MAX_PROGRAMS_PER_USER + " giáo án");
        }
        Instant now = now();
        WorkoutProgram program = request.templateId() != null
            ? copyTemplate(userId, request, now)
            : createCustom(userId, request, now);
        programRepository.saveAndFlush(program);
        if (Boolean.TRUE.equals(request.activate())) {
            activate(userId, program, now);
            entityManager.flush();
        }
        return toDetail(program);
    }

    @Transactional
    public ProgramDetail update(UUID userId, UUID id, ProgramRequest request) {
        lockUser(userId);
        WorkoutProgram program = findOwnedForWrite(userId, id);
        if (request.templateId() != null) {
            throw ApiException.validation("templateId", "Không đổi giáo án mẫu khi sửa");
        }
        if (request.version() == null) {
            throw ApiException.validation("version", "Thiếu version của giáo án đang sửa");
        }
        // Hàng users đã khóa nên version đọc ở đây không đổi tới cuối giao dịch.
        if (request.version() != program.getVersion()) {
            throw versionConflict();
        }
        Content content = validateContent(request);
        Map<UUID, WorkoutDay> current = program.currentDays().stream()
            .collect(Collectors.toMap(WorkoutDay::getId, Function.identity()));
        checkKeptDayIds(request.days(), current);

        Instant now = now();
        program.rename(content.name(), content.description(), now);
        replaceDays(program, request.days(), current, content.exercises(), now);
        if (request.activate() != null) {
            if (request.activate()) {
                activate(userId, program, now);
            } else {
                program.setActive(false, now);
            }
        }
        // Flush để version trả về là version mới.
        entityManager.flush();
        return toDetail(program);
    }

    /** Kích hoạt không cần gửi lại cả giáo án; idempotent nếu đã active (docs/16 §3). */
    @Transactional
    public ProgramDetail activate(UUID userId, UUID id) {
        lockUser(userId);
        WorkoutProgram program = findOwnedForWrite(userId, id);
        activate(userId, program, now());
        entityManager.flush();
        return toDetail(program);
    }

    // ---- tạo ----

    private WorkoutProgram copyTemplate(UUID userId, ProgramRequest request, Instant now) {
        if (request.name() != null || request.description() != null || request.days() != null) {
            throw ApiException.validation("templateId", "Gửi templateId hoặc name + days, không cả hai");
        }
        WorkoutProgram template = programRepository.findByIdAndTemplateTrue(request.templateId())
            .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Giáo án mẫu không tồn tại"));

        // Bài trong mẫu bị ẩn: từ chối cả lần sao chép, không âm thầm bỏ bài.
        Map<String, String> inactive = new LinkedHashMap<>();
        List<WorkoutDay> days = template.currentDays();
        for (int i = 0; i < days.size(); i++) {
            List<WorkoutExercise> exercises = days.get(i).getExercises();
            for (int j = 0; j < exercises.size(); j++) {
                if (!exercises.get(j).getExercise().isActive()) {
                    inactive.put(exercisePath(i, j), "Bài tập trong mẫu đã ngừng sử dụng");
                }
            }
        }
        if (!inactive.isEmpty()) {
            throw exerciseInactive(inactive);
        }

        WorkoutProgram copy = new WorkoutProgram(userId, template.getName(), template.getDescription(),
            template.getId(), now);
        for (int i = 0; i < days.size(); i++) {
            WorkoutDay source = days.get(i);
            WorkoutDay day = copy.addDay(source.getName(), i + 1, now);
            for (WorkoutExercise e : source.getExercises()) {
                day.addExercise(e.getExercise(), e.getOrderNo(), e.getTargetSets(), e.getTargetReps(),
                    e.getRestSeconds(), now);
            }
        }
        return copy;
    }

    private WorkoutProgram createCustom(UUID userId, ProgramRequest request, Instant now) {
        Content content = validateContent(request);
        for (int i = 0; i < request.days().size(); i++) {
            if (request.days().get(i).id() != null) {
                throw ApiException.validation("days[" + i + "].id", "Buổi mới không có id");
            }
        }
        WorkoutProgram program = new WorkoutProgram(userId, content.name(), content.description(), null, now);
        for (int i = 0; i < request.days().size(); i++) {
            DayRequest dayRequest = request.days().get(i);
            WorkoutDay day = program.addDay(dayRequest.name().strip(), i + 1, now);
            addExercises(day, dayRequest, content.exercises(), now);
        }
        return program;
    }

    // ---- sửa ----

    /**
     * BR-W07, docs/03 §5. Thứ tự flush của Hibernate là INSERT → UPDATE → DELETE, nên phải chia hai
     * pha để không vấp UNIQUE (program, day_order) và (day, order_no):
     * 1. dời buổi giữ lại sang day_order + 100, gỡ buổi bị bỏ (archive nếu còn lịch, không thì xóa),
     *    xóa bài của buổi giữ lại → flush;
     * 2. đánh lại thứ tự 1..n theo body, thêm buổi mới và bài mới.
     */
    private void replaceDays(WorkoutProgram program, List<DayRequest> dayRequests, Map<UUID, WorkoutDay> current,
                             Map<UUID, Exercise> exercises, Instant now) {
        Set<UUID> keptIds = new HashSet<>();
        dayRequests.forEach(d -> {
            if (d.id() != null) {
                keptIds.add(d.id());
            }
        });
        for (WorkoutDay day : current.values()) {
            if (keptIds.contains(day.getId())) {
                day.moveOrderAside(ORDER_OFFSET);
                day.clearExercises();
            } else if (scheduleRepository.existsByWorkoutDayId(day.getId())) {
                day.archive(now);
            } else {
                program.removeDay(day);
            }
        }
        entityManager.flush();

        for (int i = 0; i < dayRequests.size(); i++) {
            DayRequest dayRequest = dayRequests.get(i);
            String name = dayRequest.name().strip();
            WorkoutDay day;
            if (dayRequest.id() != null) {
                day = current.get(dayRequest.id());
                day.update(name, i + 1, now);
            } else {
                day = program.addDay(name, i + 1, now);
            }
            addExercises(day, dayRequest, exercises, now);
        }
    }

    private static void checkKeptDayIds(List<DayRequest> days, Map<UUID, WorkoutDay> current) {
        Set<UUID> seen = new HashSet<>();
        for (int i = 0; i < days.size(); i++) {
            UUID id = days.get(i).id();
            if (id == null) {
                continue;
            }
            if (!current.containsKey(id)) {
                throw ApiException.validation("days[" + i + "].id", "Buổi không thuộc giáo án này hoặc đã bị gỡ");
            }
            if (!seen.add(id)) {
                throw ApiException.validation("days[" + i + "].id", "Buổi bị gửi trùng");
            }
        }
    }

    // ---- kiểm tra nội dung ----

    private record Content(String name, String description, Map<UUID, Exercise> exercises) {
    }

    /**
     * Kiểm tra phần Bean Validation không làm được: tên không rỗng, có days, bài không trùng trong
     * buổi, bài tồn tại và đang active. Lỗi ở bất kỳ đâu thì không lưu gì (cả request rollback).
     */
    private Content validateContent(ProgramRequest request) {
        if (request.name() == null || request.name().isBlank()) {
            throw ApiException.validation("name", "Vui lòng nhập tên giáo án");
        }
        if (request.days() == null) {
            throw ApiException.validation("days", "Giáo án có từ 1 đến 7 buổi");
        }
        Set<UUID> ids = new HashSet<>();
        for (int i = 0; i < request.days().size(); i++) {
            List<ExerciseRequest> exercises = request.days().get(i).exercises();
            Set<UUID> inDay = new HashSet<>();
            for (int j = 0; j < exercises.size(); j++) {
                UUID exerciseId = exercises.get(j).exerciseId();
                if (!inDay.add(exerciseId)) {
                    throw ApiException.validation(exercisePath(i, j), "Bài tập đã có trong buổi này");
                }
                ids.add(exerciseId);
            }
        }

        Map<UUID, Exercise> found = new HashMap<>();
        exerciseRepository.findAllById(ids).forEach(e -> found.put(e.getId(), e));
        Map<String, String> unusable = new LinkedHashMap<>();
        for (int i = 0; i < request.days().size(); i++) {
            List<ExerciseRequest> exercises = request.days().get(i).exercises();
            for (int j = 0; j < exercises.size(); j++) {
                Exercise exercise = found.get(exercises.get(j).exerciseId());
                if (exercise == null || !exercise.isActive()) {
                    unusable.put(exercisePath(i, j), "Bài tập không tồn tại hoặc đã ngừng sử dụng");
                }
            }
        }
        if (!unusable.isEmpty()) {
            throw exerciseInactive(unusable);
        }
        String description = request.description() == null || request.description().isBlank()
            ? null : request.description().strip();
        return new Content(request.name().strip(), description, found);
    }

    private static void addExercises(WorkoutDay day, DayRequest request, Map<UUID, Exercise> exercises,
                                     Instant now) {
        List<ExerciseRequest> items = request.exercises();
        for (int j = 0; j < items.size(); j++) {
            ExerciseRequest e = items.get(j);
            day.addExercise(exercises.get(e.exerciseId()), j + 1, e.targetSets(), e.targetReps(),
                e.restSeconds(), now);
        }
    }

    // ---- chung ----

    /** BR-W01: tắt bản đang active và flush trước khi bật bản mới (partial UNIQUE kiểm tra từng câu lệnh). */
    private void activate(UUID userId, WorkoutProgram program, Instant now) {
        if (program.isActive()) {
            return;
        }
        programRepository.findByUserIdAndActiveTrue(userId).ifPresent(old -> {
            old.setActive(false, now);
            entityManager.flush();
        });
        program.setActive(true, now);
    }

    private WorkoutProgram findOwnedForWrite(UUID userId, UUID id) {
        return programRepository.findByIdAndUserId(id, userId).orElseThrow(() ->
            programRepository.findByIdAndTemplateTrue(id).isPresent()
                ? new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Không sửa được giáo án mẫu; hãy dùng mẫu để tạo bản của bạn")
                : notFound());
    }

    private void lockUser(UUID userId) {
        userRepository.findForUpdate(userId)
            .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy tài khoản"));
    }

    private ProgramDetail toDetail(WorkoutProgram p) {
        List<DayItem> days = p.currentDays().stream()
            .map(d -> new DayItem(d.getId(), d.getDayOrder(), d.getName(), toExerciseItems(d)))
            .toList();
        return new ProgramDetail(p.getId(), p.getName(), p.getDescription(), p.isTemplate(), p.isActive(),
            p.getSourceTemplateId(), p.getVersion(), days);
    }

    List<ExerciseItem> toExerciseItems(WorkoutDay day) {
        return day.getExercises().stream().map(e -> {
            Exercise ex = e.getExercise();
            return new ExerciseItem(e.getId(), e.getOrderNo(), ex.getId(), ex.getName(), ex.isActive(),
                mediaUrls.resolve(ex.getThumbnailUrl()), e.getTargetSets(), e.getTargetReps(), e.getRestSeconds());
        }).toList();
    }

    private Instant now() {
        // Cột TIMESTAMPTZ giữ tới micro giây; cắt trước để response và lần đọc sau khớp nhau.
        return clock.instant().truncatedTo(ChronoUnit.MICROS);
    }

    private static String exercisePath(int day, int exercise) {
        return "days[" + day + "].exercises[" + exercise + "].exerciseId";
    }

    static ApiException exerciseInactive(Map<String, String> fields) {
        return new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, "EXERCISE_INACTIVE",
            "Có bài tập không còn sử dụng được, vui lòng thay bài khác", fields);
    }

    private static ApiException versionConflict() {
        return new ApiException(HttpStatus.CONFLICT, "VERSION_CONFLICT",
            "Giáo án đã được sửa ở nơi khác. Hãy tải lại bản mới rồi sửa tiếp.");
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy giáo án");
    }
}
