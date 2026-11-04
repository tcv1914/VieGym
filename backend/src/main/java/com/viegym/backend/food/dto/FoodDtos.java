package com.viegym.backend.food.dto;

import com.viegym.backend.food.entity.DataQuality;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/** Response của /foods, /food-filters (docs/05 §9). Không trả entity trực tiếp. */
public final class FoodDtos {
    private FoodDtos() {
    }

    public record Option(String code, String name) {
    }

    /**
     * Mọi số dinh dưỡng là của một khẩu phần {@code servingDescription}; {@code servingSize}/
     * {@code servingUnit} null khi nguồn không ghi khối lượng phần.
     */
    public record FoodSummary(UUID id, String code, String name, Option category, Option region,
                              String servingDescription, BigDecimal servingSize, String servingUnit,
                              BigDecimal kcalPerServing, BigDecimal proteinPerServing, BigDecimal carbsPerServing,
                              BigDecimal fatPerServing, DataQuality dataQuality, String imageUrl) {
    }

    public record FoodDetail(UUID id, String code, String name, String nameEn, Option category, Option region,
                             String servingDescription, BigDecimal servingSize, String servingUnit,
                             BigDecimal kcalPerServing, BigDecimal proteinPerServing, BigDecimal carbsPerServing,
                             BigDecimal fatPerServing, DataQuality dataQuality, String source, String sourceUrl,
                             String imageUrl, int revision) {
    }

    public record FoodFilters(List<Option> categories, List<Option> regions) {
    }
}
