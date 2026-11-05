package com.viegym.backend.meal.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Thực đơn một ngày của một user (NUT-BR01). Tạo khi thêm món đầu tiên, không xóa khi hết món
 * (BR-N06). Không chụp mục tiêu: so với mục tiêu hiện tại (NUT-BR09, docs/23 §1).
 */
@Entity
@Table(name = "meal_plans")
public class MealPlan {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "plan_date", nullable = false, updatable = false)
    private LocalDate planDate;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected MealPlan() {
    }

    public MealPlan(UUID userId, LocalDate planDate, Instant now) {
        this.userId = userId;
        this.planDate = planDate;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public void touch(Instant now) {
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public LocalDate getPlanDate() {
        return planDate;
    }
}
