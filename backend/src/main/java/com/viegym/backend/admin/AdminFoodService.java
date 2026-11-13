package com.viegym.backend.admin;

import com.viegym.backend.admin.AdminDtos.AdminFoodDetail;
import com.viegym.backend.admin.AdminDtos.AdminFoodItem;
import com.viegym.backend.admin.AdminDtos.AdminFoodOptions;
import com.viegym.backend.admin.AdminDtos.FoodRequest;
import com.viegym.backend.admin.audit.AdminAudit;
import com.viegym.backend.admin.audit.AuditLog.Action;
import com.viegym.backend.admin.audit.AuditLog.EntityType;
import com.viegym.backend.common.exception.ApiException;
import com.viegym.backend.common.web.PageResponse;
import com.viegym.backend.exercise.SearchText;
import com.viegym.backend.food.dto.FoodDtos.Option;
import com.viegym.backend.food.entity.DataQuality;
import com.viegym.backend.food.entity.Food;
import com.viegym.backend.food.entity.FoodCategory;
import com.viegym.backend.food.entity.FoodRegion;
import com.viegym.backend.food.entity.FoodValues;
import com.viegym.backend.food.repository.FoodCategoryRepository;
import com.viegym.backend.food.repository.FoodRepository;
import jakarta.persistence.criteria.Predicate;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Admin quản lý món (docs/31 §3). Không xóa: ẩn bằng {@code active = false}. Sửa món không đụng
 * snapshot trong meal_entries (NUT-BR05) — chỉ tăng revision để bản ghi mới biết số liệu đã đổi.
 */
@Service
public class AdminFoodService {
    /** Cùng ngưỡng với seed (docs/20 §4): lệch hơn thì không được hiển thị. */
    static final BigDecimal ATWATER_TOLERANCE = new BigDecimal("0.15");
    private static final Sort ORDER = Sort.by("nameSearch", "id");

    private final FoodRepository foodRepository;
    private final FoodCategoryRepository categoryRepository;
    private final AdminAudit audit;
    private final Clock clock;

    public AdminFoodService(FoodRepository foodRepository, FoodCategoryRepository categoryRepository,
                            AdminAudit audit, Clock clock) {
        this.foodRepository = foodRepository;
        this.categoryRepository = categoryRepository;
        this.audit = audit;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public PageResponse<AdminFoodItem> search(String keyword, String categoryCode, Boolean active, int page,
                                              int size) {
        AdminSupport.checkPage(page, size);
        String normalized = AdminSupport.normalizedKeyword(keyword);
        FoodCategory category = categoryCode == null || categoryCode.isBlank() ? null
            : categoryRepository.findByCode(categoryCode)
                .orElseThrow(() -> ApiException.validation("category", "Danh mục không hợp lệ"));
        Specification<Food> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (!normalized.isEmpty()) {
                String pattern = "%" + SearchText.escapeLike(normalized) + "%";
                predicates.add(cb.or(
                    cb.like(root.get("nameSearch"), pattern, SearchText.LIKE_ESCAPE),
                    cb.like(cb.lower(root.get("code")), pattern, SearchText.LIKE_ESCAPE)));
            }
            if (category != null) {
                predicates.add(cb.equal(root.get("category"), category));
            }
            if (active != null) {
                predicates.add(cb.equal(root.get("active"), active));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
        return PageResponse.of(foodRepository.findAll(spec, PageRequest.of(page, size, ORDER)), f ->
            new AdminFoodItem(f.getId(), f.getCode(), f.getName(), category(f), f.getServingDescription(),
                f.getKcalPerServing(), f.getDataQuality(), f.isActive(), f.getRevision()));
    }

    @Transactional(readOnly = true)
    public AdminFoodDetail get(UUID id) {
        return toDetail(foodRepository.findWithCategory(id).orElseThrow(AdminFoodService::notFound));
    }

    @Transactional(readOnly = true)
    public AdminFoodOptions options() {
        List<Option> categories = categoryRepository.findAll(Sort.by("sortOrder")).stream()
            .map(c -> new Option(c.getCode(), c.getName())).toList();
        List<Option> regions = Arrays.stream(FoodRegion.values()).map(r -> new Option(r.name(), r.label())).toList();
        return new AdminFoodOptions(categories, regions, List.of(DataQuality.values()), List.of("g", "ml"));
    }

    @Transactional
    public AdminFoodDetail create(UUID actorId, FoodRequest request) {
        AdminSupport.checkRevisionPresence(request.revision(), true);
        FoodValues values = toValues(request);
        Food food = foodRepository.saveAndFlush(new Food(AdminSupport.newCode("ADM-"), values, clock.instant()));
        audit.record(actorId, Action.CREATE, EntityType.FOOD, food.getId(), null, null);
        return toDetail(food);
    }

    @Transactional
    public AdminFoodDetail update(UUID actorId, UUID id, FoodRequest request) {
        AdminSupport.checkRevisionPresence(request.revision(), false);
        Food food = foodRepository.findForUpdate(id).orElseThrow(AdminFoodService::notFound);
        if (request.revision() != food.getRevision()) {
            throw AdminSupport.revisionConflict(food.getRevision());
        }
        FoodValues before = food.values();
        FoodValues after = toValues(request);
        List<String> changed = AdminAudit.diff(before, after);
        if (changed.isEmpty()) {
            return toDetail(food);
        }
        Instant now = clock.instant();
        food.update(after, now);
        foodRepository.flush();
        audit.record(actorId, action(changed, after.active()), EntityType.FOOD, food.getId(), null, changed);
        return toDetail(food);
    }

    /** Chỉ đổi hiển thị → ACTIVATE/DEACTIVATE; có trường khác đổi → UPDATE (changedFields có "active"). */
    static Action action(List<String> changed, boolean activeNow) {
        if (changed.size() == 1 && changed.get(0).equals("active")) {
            return activeNow ? Action.ACTIVATE : Action.DEACTIVATE;
        }
        return Action.UPDATE;
    }

    private FoodValues toValues(FoodRequest r) {
        Map<String, String> errors = new LinkedHashMap<>();
        FoodCategory category = categoryRepository.findByCode(r.categoryCode()).orElse(null);
        if (category == null) {
            errors.put("categoryCode", "Danh mục không hợp lệ");
        }
        // Khớp CHECK foods_serving_check: có khối lượng thì phải có đơn vị và ngược lại.
        if ((r.servingSize() == null) != (r.servingUnit() == null)) {
            errors.put(r.servingSize() == null ? "servingSize" : "servingUnit",
                "Nhập cả khối lượng và đơn vị phần, hoặc bỏ trống cả hai");
        }
        if (r.active() && !nutritionConsistent(r)) {
            errors.put("kcalPerServing", "kcal lệch hơn 15% so với 4×đạm + 4×bột đường + 9×béo; "
                + "kiểm tra lại số liệu hoặc để ẩn kèm ghi chú rà soát");
        }
        if (!errors.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Dữ liệu không hợp lệ", errors);
        }
        return new FoodValues(r.name(), r.nameEn(), category, r.region(), r.servingSize(), r.servingUnit(),
            r.servingDescription(), r.kcalPerServing(), r.proteinPerServing(), r.carbsPerServing(),
            r.fatPerServing(), r.dataQuality(), r.source(), r.sourceUrl(), r.imageUrl(), r.reviewNote(), r.active());
    }

    /**
     * Cùng công thức seed (docs/20 §4): |kcal − (4P + 4C + 9F)| / kcal ≤ 15%. Thêm: kcal = 0 và
     * không có đạm/bột/béo (nước, trà không đường) là hợp lệ.
     */
    static boolean nutritionConsistent(FoodRequest r) {
        BigDecimal atwater = r.proteinPerServing().multiply(BigDecimal.valueOf(4))
            .add(r.carbsPerServing().multiply(BigDecimal.valueOf(4)))
            .add(r.fatPerServing().multiply(BigDecimal.valueOf(9)));
        BigDecimal kcal = r.kcalPerServing();
        if (kcal.signum() == 0) {
            return atwater.signum() == 0;
        }
        BigDecimal deviation = kcal.subtract(atwater).abs().divide(kcal, 6, RoundingMode.HALF_UP);
        return deviation.compareTo(ATWATER_TOLERANCE) <= 0;
    }

    private static AdminFoodDetail toDetail(Food f) {
        return new AdminFoodDetail(f.getId(), f.getCode(), f.getName(), f.getNameEn(), category(f),
            f.getRegion() == null ? null : new Option(f.getRegion().name(), f.getRegion().label()),
            f.getServingDescription(), f.getServingSize(), f.getServingUnit(), f.getKcalPerServing(),
            f.getProteinPerServing(), f.getCarbsPerServing(), f.getFatPerServing(), f.getDataQuality(),
            f.getSource(), f.getSourceUrl(), f.getImageUrl(), f.getReviewNote(), f.isActive(), f.getRevision());
    }

    private static Option category(Food f) {
        return new Option(f.getCategory().getCode(), f.getCategory().getName());
    }

    private static ApiException notFound() {
        return AdminSupport.notFound("Món ăn không tồn tại");
    }
}
