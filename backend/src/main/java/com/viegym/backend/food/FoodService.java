package com.viegym.backend.food;

import com.viegym.backend.common.exception.ApiException;
import com.viegym.backend.common.web.PageResponse;
import com.viegym.backend.exercise.SearchText;
import com.viegym.backend.food.dto.FoodDtos.FoodDetail;
import com.viegym.backend.food.dto.FoodDtos.FoodFilters;
import com.viegym.backend.food.dto.FoodDtos.FoodSummary;
import com.viegym.backend.food.dto.FoodDtos.Option;
import com.viegym.backend.food.entity.Food;
import com.viegym.backend.food.entity.FoodCategory;
import com.viegym.backend.food.entity.FoodRegion;
import com.viegym.backend.food.repository.FoodCategoryRepository;
import com.viegym.backend.food.repository.FoodRepository;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Tra cứu món ăn (docs/05 §9, docs/20). Chỉ món active; món ẩn trả 404 như không tồn tại. */
@Service
public class FoodService {
    static final int MAX_PAGE_SIZE = 100;
    static final int MAX_KEYWORD_LENGTH = 100;
    // name_search không duy nhất; thêm id để thứ tự ổn định giữa các trang.
    private static final Sort ORDER = Sort.by("nameSearch", "id");

    private final FoodRepository foodRepository;
    private final FoodCategoryRepository categoryRepository;

    public FoodService(FoodRepository foodRepository, FoodCategoryRepository categoryRepository) {
        this.foodRepository = foodRepository;
        this.categoryRepository = categoryRepository;
    }

    @Transactional(readOnly = true)
    public PageResponse<FoodSummary> search(String keyword, String categoryCode, FoodRegion region, int page,
                                            int size) {
        if (page < 0) {
            throw ApiException.validation("page", "Số trang phải từ 0");
        }
        if (size < 1 || size > MAX_PAGE_SIZE) {
            throw ApiException.validation("size", "Kích thước trang phải từ 1 đến " + MAX_PAGE_SIZE);
        }
        String normalized = SearchText.normalize(keyword);
        if (normalized.length() > MAX_KEYWORD_LENGTH) {
            throw ApiException.validation("keyword", "Từ khóa tối đa " + MAX_KEYWORD_LENGTH + " ký tự");
        }
        FoodCategory category = null;
        if (categoryCode != null && !categoryCode.isBlank()) {
            category = categoryRepository.findByCode(categoryCode)
                .orElseThrow(() -> ApiException.validation("category", "Danh mục không hợp lệ"));
        }
        var spec = activeMatching(normalized, category, region);
        return PageResponse.of(foodRepository.findAll(spec, PageRequest.of(page, size, ORDER)), this::toSummary);
    }

    @Transactional(readOnly = true)
    public FoodDetail get(UUID id) {
        Food f = foodRepository.findActive(id).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
            "NOT_FOUND", "Món ăn không tồn tại hoặc đã ngừng hiển thị"));
        return new FoodDetail(f.getId(), f.getCode(), f.getName(), f.getNameEn(), category(f), region(f),
            f.getServingDescription(), f.getServingSize(), f.getServingUnit(), f.getKcalPerServing(),
            f.getProteinPerServing(), f.getCarbsPerServing(), f.getFatPerServing(), f.getDataQuality(),
            f.getSource(), f.getSourceUrl(), f.getImageUrl(), f.getRevision());
    }

    @Transactional(readOnly = true)
    public FoodFilters filters() {
        List<Option> categories = foodRepository.categoriesWithActiveFoods().stream()
            .map(c -> new Option(c.getCode(), c.getName())).toList();
        List<Option> regions = Arrays.stream(FoodRegion.values()).map(r -> new Option(r.name(), r.label())).toList();
        return new FoodFilters(categories, regions);
    }

    /** Điều kiện active luôn có, client không bỏ được. */
    private static Specification<Food> activeMatching(String normalizedKeyword, FoodCategory category,
                                                      FoodRegion region) {
        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.isTrue(root.get("active")));
            if (!normalizedKeyword.isEmpty()) {
                String pattern = "%" + SearchText.escapeLike(normalizedKeyword) + "%";
                predicates.add(cb.like(root.get("nameSearch"), pattern, SearchText.LIKE_ESCAPE));
            }
            if (category != null) {
                predicates.add(cb.equal(root.get("category"), category));
            }
            if (region != null) {
                predicates.add(cb.equal(root.get("region"), region));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
    }

    private FoodSummary toSummary(Food f) {
        return new FoodSummary(f.getId(), f.getCode(), f.getName(), category(f), region(f),
            f.getServingDescription(), f.getServingSize(), f.getServingUnit(), f.getKcalPerServing(),
            f.getProteinPerServing(), f.getCarbsPerServing(), f.getFatPerServing(), f.getDataQuality(),
            f.getImageUrl());
    }

    private static Option category(Food f) {
        return new Option(f.getCategory().getCode(), f.getCategory().getName());
    }

    private static Option region(Food f) {
        return f.getRegion() == null ? null : new Option(f.getRegion().name(), f.getRegion().label());
    }
}
