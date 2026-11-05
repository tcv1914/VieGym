package com.viegym.backend.meal;

import com.viegym.backend.auth.entity.User;
import com.viegym.backend.auth.repository.UserRepository;
import com.viegym.backend.common.exception.ApiException;
import com.viegym.backend.food.entity.Food;
import com.viegym.backend.food.repository.FoodRepository;
import com.viegym.backend.health.entity.NutritionTarget;
import com.viegym.backend.health.repository.NutritionTargetRepository;
import com.viegym.backend.meal.dto.MealDtos.AddEntryRequest;
import com.viegym.backend.meal.dto.MealDtos.EntryItem;
import com.viegym.backend.meal.dto.MealDtos.MealPlanView;
import com.viegym.backend.meal.dto.MealDtos.Nutrients;
import com.viegym.backend.meal.dto.MealDtos.UpdateEntryRequest;
import com.viegym.backend.meal.entity.MealEntry;
import com.viegym.backend.meal.entity.MealPlan;
import com.viegym.backend.meal.entity.MealType;
import com.viegym.backend.meal.repository.MealEntryRepository;
import com.viegym.backend.meal.repository.MealPlanRepository;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * UC07 — thực đơn trong ngày (docs/23). Mọi thao tác ghi khóa hàng users trước (cùng điểm khóa
 * với hồ sơ, giáo án, lịch tập): hai request thêm món đầu ngày chạy tuần tự nên chỉ tạo một
 * thực đơn; UNIQUE (user_id, plan_date) là lớp bảo vệ cuối.
 */
@Service
public class MealPlanService {
    /** BR-N07: ghi được ngày quá khứ và tối đa 7 ngày tới (theo múi giờ user). */
    static final int MAX_DAYS_AHEAD = 7;
    /** Chặn payload/lịch sử vô hạn trong một ngày (docs/23 §2). */
    static final int MAX_ENTRIES_PER_DAY = 100;
    static final LocalDate MIN_DATE = LocalDate.of(2000, 1, 1);

    private final UserRepository userRepository;
    private final MealPlanRepository planRepository;
    private final MealEntryRepository entryRepository;
    private final FoodRepository foodRepository;
    private final NutritionTargetRepository targetRepository;
    private final Clock clock;

    public MealPlanService(UserRepository userRepository, MealPlanRepository planRepository,
                           MealEntryRepository entryRepository, FoodRepository foodRepository,
                           NutritionTargetRepository targetRepository, Clock clock) {
        this.userRepository = userRepository;
        this.planRepository = planRepository;
        this.entryRepository = entryRepository;
        this.foodRepository = foodRepository;
        this.targetRepository = targetRepository;
        this.clock = clock;
    }

    /** Chưa có thực đơn → 200 với bữa rỗng, tổng 0 (A1); không tạo dữ liệu khi đọc. */
    @Transactional(readOnly = true)
    public MealPlanView get(UUID userId, LocalDate date) {
        User user = userRepository.findById(userId).orElseThrow(MealPlanService::userNotFound);
        LocalDate day = date == null ? today(user) : date;
        List<MealEntry> entries = planRepository.findByUserIdAndPlanDate(userId, day)
            .map(plan -> entryRepository.findByPlan(plan.getId()))
            .orElse(List.of());
        return view(userId, day, entries);
    }

    @Transactional
    public MealPlanView add(UUID userId, AddEntryRequest request) {
        User user = userRepository.findForUpdate(userId).orElseThrow(MealPlanService::userNotFound);
        checkWritableDate(request.date(), today(user));
        Food food = foodRepository.findById(request.foodId())
            .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy món ăn"));
        // A4: món bị ẩn trước khi xác nhận → không thêm mới; mục đã có vẫn giữ (NUT-BR06).
        if (!food.isActive()) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, "FOOD_INACTIVE",
                "Món này không còn sử dụng được, vui lòng chọn món khác", Map.of("foodId", food.getName()));
        }
        Instant now = now();
        MealPlan plan = planRepository.findByUserIdAndPlanDate(userId, request.date())
            .orElseGet(() -> planRepository.save(new MealPlan(userId, request.date(), now)));
        if (entryRepository.countByMealPlanId(plan.getId()) >= MAX_ENTRIES_PER_DAY) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, "MEAL_PLAN_LIMIT",
                "Mỗi ngày tối đa " + MAX_ENTRIES_PER_DAY + " món");
        }
        entryRepository.save(new MealEntry(plan, food, request.mealType(), scaled(request.servings()), now));
        plan.touch(now);
        // Lộ lỗi ràng buộc ngay trong giao dịch: lỗi thì rollback cả thực đơn mới lẫn mục.
        entryRepository.flush();
        return view(userId, plan.getPlanDate(), entryRepository.findByPlan(plan.getId()));
    }

    /** A5: chỉ đổi số phần/bữa, tính lại từ snapshot đã lưu; món đã ẩn vẫn sửa được. */
    @Transactional
    public MealPlanView update(UUID userId, UUID entryId, UpdateEntryRequest request) {
        if (request.mealType() == null && request.servings() == null) {
            throw ApiException.validation("servings", "Cần đổi số khẩu phần hoặc bữa");
        }
        userRepository.findForUpdate(userId).orElseThrow(MealPlanService::userNotFound);
        MealEntry entry = entryRepository.findOwned(entryId, userId).orElseThrow(MealPlanService::entryNotFound);
        Instant now = now();
        entry.update(request.mealType(), request.servings() == null ? null : scaled(request.servings()), now);
        MealPlan plan = entry.getMealPlan();
        plan.touch(now);
        entryRepository.flush();
        return view(userId, plan.getPlanDate(), entryRepository.findByPlan(plan.getId()));
    }

    /** A6: xóa mục; thực đơn còn lại kể cả khi hết món (BR-N06). */
    @Transactional
    public MealPlanView delete(UUID userId, UUID entryId) {
        userRepository.findForUpdate(userId).orElseThrow(MealPlanService::userNotFound);
        MealEntry entry = entryRepository.findOwned(entryId, userId).orElseThrow(MealPlanService::entryNotFound);
        MealPlan plan = entry.getMealPlan();
        entryRepository.delete(entry);
        plan.touch(now());
        entryRepository.flush();
        return view(userId, plan.getPlanDate(), entryRepository.findByPlan(plan.getId()));
    }

    private MealPlanView view(UUID userId, LocalDate date, List<MealEntry> entries) {
        Map<MealType, List<EntryItem>> meals = new EnumMap<>(MealType.class);
        Map<MealType, MealNutrition> sums = new EnumMap<>(MealType.class);
        for (MealType type : MealType.values()) {
            meals.put(type, new ArrayList<>());
            sums.put(type, MealNutrition.ZERO);
        }
        MealNutrition total = MealNutrition.ZERO;
        for (MealEntry e : entries) {
            MealNutrition n = MealNutrition.of(e.getServings(), e.getKcalPerServing(), e.getProteinPerServing(),
                e.getCarbsPerServing(), e.getFatPerServing());
            Nutrients r = n.rounded();
            meals.get(e.getMealType()).add(new EntryItem(e.getId(), e.getFoodId(), e.getFoodName(), e.getMealType(),
                e.getServingDescription(), e.getServingSize(), e.getServingUnit(), e.getServings(),
                e.getKcalPerServing(), e.getProteinPerServing(), e.getCarbsPerServing(), e.getFatPerServing(),
                r.kcal(), r.proteinG(), r.carbsG(), r.fatG(), e.getDataQuality(), e.getCreatedAt()));
            sums.merge(e.getMealType(), n, MealNutrition::plus);
            total = total.plus(n);
        }
        Map<MealType, Nutrients> mealTotals = new EnumMap<>(MealType.class);
        sums.forEach((type, sum) -> mealTotals.put(type, sum.rounded()));

        NutritionTarget target = targetRepository.findByUserId(userId).orElse(null);
        Nutrients targets = null;
        Nutrients remaining = null;
        Instant calculatedAt = null;
        if (target != null) {
            MealNutrition t = new MealNutrition(target.getTargetKcal(), target.getProteinG(), target.getCarbsG(),
                target.getFatG());
            targets = t.rounded();
            remaining = total.remainingOf(t).rounded();
            calculatedAt = target.getCalculatedAt();
        }
        return new MealPlanView(date, entries.size(), meals, mealTotals, total.rounded(), targets, remaining,
            calculatedAt);
    }

    private static void checkWritableDate(LocalDate date, LocalDate today) {
        if (date.isBefore(MIN_DATE)) {
            throw ApiException.validation("date", "Ngày không hợp lệ");
        }
        if (date.isAfter(today.plusDays(MAX_DAYS_AHEAD))) {
            throw ApiException.validation("date", "Chỉ lập thực đơn tối đa " + MAX_DAYS_AHEAD + " ngày tới");
        }
    }

    /** @Digits đã chặn quá 2 chữ số lẻ; chuẩn hóa scale cho cột NUMERIC(5,2). */
    private static BigDecimal scaled(BigDecimal servings) {
        return servings.setScale(2, RoundingMode.UNNECESSARY);
    }

    private LocalDate today(User user) {
        return LocalDate.now(clock.withZone(ZoneId.of(user.getTimezone())));
    }

    private Instant now() {
        return clock.instant().truncatedTo(ChronoUnit.MICROS);
    }

    private static ApiException entryNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy món trong thực đơn");
    }

    private static ApiException userNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy tài khoản");
    }
}
