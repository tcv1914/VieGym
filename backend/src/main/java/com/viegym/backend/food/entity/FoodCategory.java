package com.viegym.backend.food.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

/** Danh mục giữ nguyên từ nguồn (docs/20 §3). Chỉ đọc; dữ liệu vào bằng seed V10. */
@Entity
@Table(name = "food_categories")
public class FoodCategory {
    @Id
    private UUID id;

    @Column(nullable = false, updatable = false, length = 80)
    private String code;

    @Column(nullable = false, length = 150)
    private String name;

    @Column(name = "sort_order", nullable = false)
    private short sortOrder;

    protected FoodCategory() {
    }

    public UUID getId() {
        return id;
    }

    public String getCode() {
        return code;
    }

    public String getName() {
        return name;
    }

    public int getSortOrder() {
        return sortOrder;
    }
}
