package com.viegym.backend.workout.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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

/** Một hiệp thực tế: số lần và mức tạ ngoài (kg; 0 = không dùng tạ ngoài). */
@Entity
@Table(name = "workout_set_logs")
public class WorkoutSetLog {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "log_exercise_id", nullable = false, updatable = false)
    private WorkoutLogExercise logExercise;

    @Column(name = "set_no", nullable = false, updatable = false)
    private short setNo;

    @Column(nullable = false, updatable = false)
    private short reps;

    @Column(name = "weight_kg", nullable = false, updatable = false, precision = 5, scale = 2)
    private BigDecimal weightKg;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected WorkoutSetLog() {
    }

    WorkoutSetLog(WorkoutLogExercise logExercise, int setNo, int reps, BigDecimal weightKg, Instant now) {
        this.logExercise = logExercise;
        this.setNo = (short) setNo;
        this.reps = (short) reps;
        this.weightKg = weightKg;
        this.createdAt = now;
    }

    public int getSetNo() {
        return setNo;
    }

    public int getReps() {
        return reps;
    }

    public BigDecimal getWeightKg() {
        return weightKg;
    }
}
