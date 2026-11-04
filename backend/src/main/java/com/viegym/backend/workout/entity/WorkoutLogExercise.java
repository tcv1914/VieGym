package com.viegym.backend.workout.entity;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.hibernate.annotations.BatchSize;

/** Một bài trong log. Giữ {@code exercise_id} để thống kê sau này; tên là snapshot lúc ghi. */
@Entity
@Table(name = "workout_log_exercises")
public class WorkoutLogExercise {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "workout_log_id", nullable = false, updatable = false)
    private WorkoutLog log;

    @Column(name = "exercise_id", nullable = false, updatable = false)
    private UUID exerciseId;

    @Column(name = "exercise_name_snapshot", nullable = false, updatable = false, length = 150)
    private String exerciseName;

    @Column(name = "order_no", nullable = false, updatable = false)
    private short orderNo;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @OneToMany(mappedBy = "logExercise", cascade = CascadeType.ALL)
    @OrderBy("setNo")
    // Chi tiết log: tải hiệp của mọi bài bằng một truy vấn IN thay vì một truy vấn mỗi bài.
    @BatchSize(size = 20)
    private List<WorkoutSetLog> sets = new ArrayList<>();

    protected WorkoutLogExercise() {
    }

    WorkoutLogExercise(WorkoutLog log, UUID exerciseId, String exerciseName, int orderNo, Instant now) {
        this.log = log;
        this.exerciseId = exerciseId;
        this.exerciseName = exerciseName;
        this.orderNo = (short) orderNo;
        this.createdAt = now;
    }

    public void addSet(int setNo, int reps, BigDecimal weightKg, Instant now) {
        sets.add(new WorkoutSetLog(this, setNo, reps, weightKg, now));
    }

    public UUID getExerciseId() {
        return exerciseId;
    }

    public String getExerciseName() {
        return exerciseName;
    }

    public int getOrderNo() {
        return orderNo;
    }

    public List<WorkoutSetLog> getSets() {
        return sets;
    }
}
