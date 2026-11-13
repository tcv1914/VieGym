package com.viegym.backend.food.entity;

import java.math.BigDecimal;

/** Các trường admin sửa được của một món (docs/31 §3); đã kiểm tra hợp lệ trước khi tạo. */
public record FoodValues(String name, String nameEn, FoodCategory category, FoodRegion region,
                         BigDecimal servingSize, String servingUnit, String servingDescription,
                         BigDecimal kcalPerServing, BigDecimal proteinPerServing, BigDecimal carbsPerServing,
                         BigDecimal fatPerServing, DataQuality dataQuality, String source, String sourceUrl,
                         String imageUrl, String reviewNote, boolean active) {
}
