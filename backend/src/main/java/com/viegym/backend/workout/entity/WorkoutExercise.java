package com.viegym.backend.workout.entity;

import com.viegym.backend.exercise.entity.Exercise;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** Bài dự kiến trong buổi: số liệu kế hoạch, không phải kết quả tập (ngày 8 lưu riêng). */
@Entity
@Table(name = "workout_exercises")
public class WorkoutExercise {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "workout_day_id", nullable = false, updatable = false)
    private WorkoutDay day;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "exercise_id", nullable = false, updatable = false)
    private Exercise exercise;

    @Column(name = "order_no", nullable = false)
    private short orderNo;

    @Column(name = "target_sets", nullable = false)
    private short targetSets;

    @Column(name = "target_reps", nullable = false)
    private short targetReps;

    @Column(name = "rest_seconds", nullable = false)
    private short restSeconds;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected WorkoutExercise() {
    }

    WorkoutExercise(WorkoutDay day, Exercise exercise, int orderNo, int sets, int reps, int restSeconds,
                    Instant now) {
        this.day = day;
        this.exercise = exercise;
        this.orderNo = (short) orderNo;
        this.targetSets = (short) sets;
        this.targetReps = (short) reps;
        this.restSeconds = (short) restSeconds;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public Exercise getExercise() {
        return exercise;
    }

    public int getOrderNo() {
        return orderNo;
    }

    public int getTargetSets() {
        return targetSets;
    }

    public int getTargetReps() {
        return targetReps;
    }

    public int getRestSeconds() {
        return restSeconds;
    }
}
