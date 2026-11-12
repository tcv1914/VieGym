package com.viegym.backend.ai;

import com.viegym.backend.auth.entity.User;
import com.viegym.backend.health.HealthCalculator;
import com.viegym.backend.health.entity.HealthProfile;
import com.viegym.backend.health.entity.NutritionTarget;
import com.viegym.backend.health.repository.HealthProfileRepository;
import com.viegym.backend.health.repository.NutritionTargetRepository;
import com.viegym.backend.meal.MealPlanService;
import com.viegym.backend.meal.dto.MealDtos;
import com.viegym.backend.meal.dto.MealDtos.MealPlanView;
import com.viegym.backend.workout.WorkoutLogService;
import com.viegym.backend.workout.WorkoutScheduleService;
import com.viegym.backend.workout.entity.ScheduleStatus;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.TextStyle;
import java.util.List;
import java.util.Locale;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Dựng context từ các service nghiệp vụ (BR-AI03, AI-BR06): hồ sơ + mục tiêu, thực đơn hôm nay +
 * tổng, tối đa 5 buổi tập gần nhất, lịch 7 ngày tới. Không đọc dữ liệu theo id app gửi.
 */
@Component
public class AiContextBuilder {
    static final int RECENT_WORKOUTS = 5;
    static final int UPCOMING_DAYS = 7;

    private final HealthProfileRepository profileRepository;
    private final NutritionTargetRepository targetRepository;
    private final MealPlanService mealPlanService;
    private final WorkoutLogService logService;
    private final WorkoutScheduleService scheduleService;
    private final Clock clock;

    public AiContextBuilder(HealthProfileRepository profileRepository, NutritionTargetRepository targetRepository,
                            MealPlanService mealPlanService, WorkoutLogService logService,
                            WorkoutScheduleService scheduleService, Clock clock) {
        this.profileRepository = profileRepository;
        this.targetRepository = targetRepository;
        this.mealPlanService = mealPlanService;
        this.logService = logService;
        this.scheduleService = scheduleService;
        this.clock = clock;
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public AiContext build(User user) {
        ZoneId zone = ZoneId.of(user.getTimezone());
        LocalDate today = LocalDate.now(clock.withZone(zone));
        String weekday = today.getDayOfWeek().getDisplayName(TextStyle.FULL, Locale.forLanguageTag("vi"));

        HealthProfile profile = profileRepository.findByUserId(user.getId()).orElse(null);
        NutritionTarget target = targetRepository.findByUserId(user.getId()).orElse(null);
        AiContext.Profile profileCtx = profile == null ? AiContext.Profile.MISSING
            : new AiContext.Profile("READY", profile.getSex().name(),
                HealthCalculator.ageOn(profile.getDateOfBirth(), today), profile.getHeightCm(),
                profile.getWeightKg(), profile.getActivityLevel().name(), profile.getGoal().name(),
                target == null ? null : target.getBmi());

        MealPlanView plan = mealPlanService.get(user.getId(), today);
        AiContext.Targets targets = plan.targets() == null ? null
            : new AiContext.Targets(plan.targets().kcal(), plan.targets().proteinG(), plan.targets().carbsG(),
                plan.targets().fatG(), plan.targetsCalculatedAt());
        List<AiContext.MealEntry> entries = plan.meals().values().stream().flatMap(List::stream)
            .map(e -> new AiContext.MealEntry(e.mealType().name(), e.foodName(), e.servings(),
                e.servingDescription(), e.kcal(), e.proteinG(), e.carbsG(), e.fatG(), e.dataQuality().name()))
            .toList();
        AiContext.MealPlan mealPlan = new AiContext.MealPlan(plan.entryCount(), entries, nutrients(plan.totals()),
            plan.remaining() == null ? null : nutrients(plan.remaining()));

        List<AiContext.Workout> workouts = logService.list(user.getId(), null, today, 0, RECENT_WORKOUTS).items()
            .stream()
            .map(l -> new AiContext.Workout(l.workoutDate(), l.workoutName(), l.programName(), l.exerciseCount(),
                l.setCount(), l.totalReps(), l.totalVolumeKg()))
            .toList();

        List<AiContext.Schedule> upcoming = scheduleService
            .list(user.getId(), today, today.plusDays(UPCOMING_DAYS - 1), ScheduleStatus.SCHEDULED).items().stream()
            .map(s -> new AiContext.Schedule(s.scheduledDate(), s.startTime(), s.workoutDay().name(),
                s.workoutDay().programName()))
            .toList();

        return new AiContext(today, user.getTimezone(), weekday, profileCtx, targets, mealPlan, workouts, upcoming);
    }

    private static AiContext.Nutrients nutrients(MealDtos.Nutrients n) {
        return new AiContext.Nutrients(n.kcal(), n.proteinG(), n.carbsG(), n.fatG());
    }
}
