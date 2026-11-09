package com.viegym.backend.dashboard;

import com.viegym.backend.auth.entity.User;
import com.viegym.backend.auth.repository.UserRepository;
import com.viegym.backend.common.exception.ApiException;
import com.viegym.backend.dashboard.DashboardDtos.DashboardView;
import com.viegym.backend.dashboard.DashboardDtos.Health;
import com.viegym.backend.dashboard.DashboardDtos.Nutrition;
import com.viegym.backend.dashboard.DashboardDtos.ScheduleRef;
import com.viegym.backend.dashboard.DashboardDtos.Training;
import com.viegym.backend.dashboard.DashboardDtos.WeekStats;
import com.viegym.backend.health.entity.HealthProfile;
import com.viegym.backend.health.entity.NutritionTarget;
import com.viegym.backend.health.repository.HealthProfileRepository;
import com.viegym.backend.health.repository.NutritionTargetRepository;
import com.viegym.backend.meal.MealPlanService;
import com.viegym.backend.meal.dto.MealDtos.MealPlanView;
import com.viegym.backend.workout.WorkoutScheduleService;
import com.viegym.backend.workout.dto.ScheduleDtos.ScheduleItem;
import com.viegym.backend.workout.entity.ScheduleStatus;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

/**
 * UC09 (docs/25). Chỉ ghép kết quả của các module đã có — thực đơn ngày (MealPlanService), lịch
 * tuần (WorkoutScheduleService), hồ sơ/mục tiêu (bảng ngày 5) — không chép công thức. Mỗi nhóm
 * tổng hợp riêng rồi mới ghép, không JOIN chéo meal_entries với workout nên không nhân dòng.
 * REPEATABLE READ chỉ đọc: mọi truy vấn trong một request thấy cùng một snapshot PostgreSQL.
 * GET không tạo/sửa dữ liệu.
 */
@Service
public class DashboardService {
    static final LocalDate MIN_DATE = LocalDate.of(2000, 1, 1);
    static final LocalDate MAX_DATE = LocalDate.of(2099, 12, 31);
    /** Cửa sổ tìm buổi tiếp theo, tính từ hôm nay (≤ giới hạn 62 ngày của danh sách lịch). */
    static final int NEXT_WINDOW_DAYS = 30;

    private final UserRepository userRepository;
    private final HealthProfileRepository profileRepository;
    private final NutritionTargetRepository targetRepository;
    private final MealPlanService mealPlanService;
    private final WorkoutScheduleService scheduleService;
    private final Clock clock;

    public DashboardService(UserRepository userRepository, HealthProfileRepository profileRepository,
                            NutritionTargetRepository targetRepository, MealPlanService mealPlanService,
                            WorkoutScheduleService scheduleService, Clock clock) {
        this.userRepository = userRepository;
        this.profileRepository = profileRepository;
        this.targetRepository = targetRepository;
        this.mealPlanService = mealPlanService;
        this.scheduleService = scheduleService;
        this.clock = clock;
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public DashboardView get(UUID userId, LocalDate requestedDate) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy tài khoản"));
        ZoneId zone = ZoneId.of(user.getTimezone());
        LocalDate today = LocalDate.now(clock.withZone(zone));
        LocalDate date = requestedDate == null ? today : requestedDate;
        if (date.isBefore(MIN_DATE) || date.isAfter(MAX_DATE)) {
            throw ApiException.validation("date", "Ngày không hợp lệ");
        }
        return new DashboardView(date, user.getTimezone(), health(userId), nutrition(userId, date),
            training(userId, date, today), clock.instant().truncatedTo(ChronoUnit.MILLIS));
    }

    private Health health(UUID userId) {
        HealthProfile profile = profileRepository.findByUserId(userId).orElse(null);
        if (profile == null) {
            return new Health(false, null, null, null, null, null);
        }
        NutritionTarget target = targetRepository.findByUserId(userId).orElse(null);
        return new Health(true, profile.getWeightKg(), profile.getHeightCm(),
            target == null ? null : target.getBmi(), profile.getGoal(), null);
    }

    private Nutrition nutrition(UUID userId, LocalDate date) {
        MealPlanView plan = mealPlanService.get(userId, date);
        return new Nutrition(plan.entryCount(), plan.totals(), plan.targets(), plan.remaining(),
            plan.targetsCalculatedAt());
    }

    private Training training(UUID userId, LocalDate date, LocalDate today) {
        LocalDate from = WorkoutScheduleService.weekStart(date);
        List<ScheduleItem> week = scheduleService.list(userId, from, from.plusDays(6), null).items();
        int cancelled = 0;
        int completed = 0;
        for (ScheduleItem s : week) {
            if (s.status() == ScheduleStatus.CANCELLED) {
                cancelled++;
            } else if (s.status() == ScheduleStatus.COMPLETED) {
                completed++;
            }
        }
        List<ScheduleRef> onDate = week.stream().filter(s -> s.scheduledDate().equals(date))
            .map(DashboardService::ref).toList();
        ScheduleRef next = scheduleService
            .list(userId, today, today.plusDays(NEXT_WINDOW_DAYS - 1), ScheduleStatus.SCHEDULED).items().stream()
            .findFirst().map(DashboardService::ref).orElse(null);
        return new Training(onDate,
            new WeekStats(from, from.plusDays(6), week.size() - cancelled, completed, cancelled), next);
    }

    private static ScheduleRef ref(ScheduleItem s) {
        return new ScheduleRef(s.id(), s.scheduledDate(), s.startTime(), s.workoutDay().name(),
            s.workoutDay().programName(), s.status(), s.workoutLogId());
    }
}
