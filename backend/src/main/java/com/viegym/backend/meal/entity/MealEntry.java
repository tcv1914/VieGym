package com.viegym.backend.meal.entity;

import com.viegym.backend.food.entity.DataQuality;
import com.viegym.backend.food.entity.Food;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Một lần thêm món vào một bữa (NUT-BR08: cùng món thêm hai lần là hai mục). Tên, khẩu phần và
 * dinh dưỡng một khẩu phần là snapshot lúc thêm (NUT-BR05); chỉ {@code servings} và
 * {@code mealType} sửa được, đổi món = xóa rồi thêm mới.
 */
@Entity
@Table(name = "meal_entries")
public class MealEntry {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "meal_plan_id", nullable = false, updatable = false)
    private MealPlan mealPlan;

    @Column(name = "food_id", nullable = false, updatable = false)
    private UUID foodId;

    @Column(name = "food_revision", nullable = false, updatable = false)
    private int foodRevision;

    @Enumerated(EnumType.STRING)
    @Column(name = "meal_type", nullable = false, length = 10)
    private MealType mealType;

    @Column(nullable = false, precision = 5, scale = 2)
    private BigDecimal servings;

    @Column(name = "food_name_snapshot", nullable = false, updatable = false, length = 150)
    private String foodName;

    @Column(name = "serving_size_snapshot", updatable = false, precision = 7, scale = 2)
    private BigDecimal servingSize;

    @Column(name = "serving_unit_snapshot", updatable = false, length = 20)
    private String servingUnit;

    @Column(name = "serving_description_snapshot", nullable = false, updatable = false, length = 100)
    private String servingDescription;

    @Column(name = "kcal_per_serving_snapshot", nullable = false, updatable = false, precision = 7, scale = 2)
    private BigDecimal kcalPerServing;

    @Column(name = "protein_per_serving_snapshot", nullable = false, updatable = false, precision = 6, scale = 2)
    private BigDecimal proteinPerServing;

    @Column(name = "carbs_per_serving_snapshot", nullable = false, updatable = false, precision = 6, scale = 2)
    private BigDecimal carbsPerServing;

    @Column(name = "fat_per_serving_snapshot", nullable = false, updatable = false, precision = 6, scale = 2)
    private BigDecimal fatPerServing;

    @Enumerated(EnumType.STRING)
    @Column(name = "data_quality_snapshot", nullable = false, updatable = false, length = 10)
    private DataQuality dataQuality;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected MealEntry() {
    }

    public MealEntry(MealPlan mealPlan, Food food, MealType mealType, BigDecimal servings, Instant now) {
        this.mealPlan = mealPlan;
        this.foodId = food.getId();
        this.foodRevision = food.getRevision();
        this.mealType = mealType;
        this.servings = servings;
        this.foodName = food.getName();
        this.servingSize = food.getServingSize();
        this.servingUnit = food.getServingUnit();
        this.servingDescription = food.getServingDescription();
        this.kcalPerServing = food.getKcalPerServing();
        this.proteinPerServing = food.getProteinPerServing();
        this.carbsPerServing = food.getCarbsPerServing();
        this.fatPerServing = food.getFatPerServing();
        this.dataQuality = food.getDataQuality();
        this.createdAt = now;
        this.updatedAt = now;
    }

    /** Chỉ đổi số phần/bữa; snapshot giữ nguyên (BR-N05). */
    public void update(MealType mealType, BigDecimal servings, Instant now) {
        if (mealType != null) {
            this.mealType = mealType;
        }
        if (servings != null) {
            this.servings = servings;
        }
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public MealPlan getMealPlan() {
        return mealPlan;
    }

    public UUID getFoodId() {
        return foodId;
    }

    public int getFoodRevision() {
        return foodRevision;
    }

    public MealType getMealType() {
        return mealType;
    }

    public BigDecimal getServings() {
        return servings;
    }

    public String getFoodName() {
        return foodName;
    }

    public BigDecimal getServingSize() {
        return servingSize;
    }

    public String getServingUnit() {
        return servingUnit;
    }

    public String getServingDescription() {
        return servingDescription;
    }

    public BigDecimal getKcalPerServing() {
        return kcalPerServing;
    }

    public BigDecimal getProteinPerServing() {
        return proteinPerServing;
    }

    public BigDecimal getCarbsPerServing() {
        return carbsPerServing;
    }

    public BigDecimal getFatPerServing() {
        return fatPerServing;
    }

    public DataQuality getDataQuality() {
        return dataQuality;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
