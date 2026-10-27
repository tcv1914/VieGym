package com.viegym.backend.health.entity;

import com.viegym.backend.health.HealthCalculator;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** Mục tiêu hiện tại của user (BR-H03); chỉ đổi khi lưu hồ sơ (BR-H04). */
@Entity
@Table(name = "nutrition_targets")
public class NutritionTarget {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(nullable = false, precision = 5, scale = 2)
    private BigDecimal bmi;

    @Column(name = "bmr_kcal", nullable = false, precision = 6, scale = 1)
    private BigDecimal bmrKcal;

    @Column(name = "tdee_kcal", nullable = false, precision = 6, scale = 1)
    private BigDecimal tdeeKcal;

    @Column(name = "target_kcal", nullable = false, precision = 6, scale = 1)
    private BigDecimal targetKcal;

    @Column(name = "protein_g", nullable = false, precision = 5, scale = 1)
    private BigDecimal proteinG;

    @Column(name = "carbs_g", nullable = false, precision = 5, scale = 1)
    private BigDecimal carbsG;

    @Column(name = "fat_g", nullable = false, precision = 5, scale = 1)
    private BigDecimal fatG;

    @Column(name = "kcal_floor_applied", nullable = false)
    private boolean kcalFloorApplied;

    @Column(name = "formula_version", nullable = false, length = 20)
    private String formulaVersion;

    @Column(name = "calculated_at", nullable = false)
    private Instant calculatedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected NutritionTarget() {
    }

    public NutritionTarget(UUID userId, Instant now) {
        this.userId = userId;
        this.createdAt = now;
    }

    public void apply(HealthCalculator.Result result, Instant now) {
        this.bmi = result.bmi();
        this.bmrKcal = result.bmrKcal();
        this.tdeeKcal = result.tdeeKcal();
        this.targetKcal = result.targetKcal();
        this.proteinG = result.proteinG();
        this.carbsG = result.carbsG();
        this.fatG = result.fatG();
        this.kcalFloorApplied = result.kcalFloorApplied();
        this.formulaVersion = HealthCalculator.FORMULA_VERSION;
        this.calculatedAt = now;
        this.updatedAt = now;
    }

    public BigDecimal getBmi() {
        return bmi;
    }

    public BigDecimal getBmrKcal() {
        return bmrKcal;
    }

    public BigDecimal getTdeeKcal() {
        return tdeeKcal;
    }

    public BigDecimal getTargetKcal() {
        return targetKcal;
    }

    public BigDecimal getProteinG() {
        return proteinG;
    }

    public BigDecimal getCarbsG() {
        return carbsG;
    }

    public BigDecimal getFatG() {
        return fatG;
    }

    public boolean isKcalFloorApplied() {
        return kcalFloorApplied;
    }

    public String getFormulaVersion() {
        return formulaVersion;
    }

    public Instant getCalculatedAt() {
        return calculatedAt;
    }
}
