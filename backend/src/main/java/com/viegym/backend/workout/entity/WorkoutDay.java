package com.viegym.backend.workout.entity;

import com.viegym.backend.exercise.entity.Exercise;
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
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "workout_days")
public class WorkoutDay {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "program_id", nullable = false, updatable = false)
    private WorkoutProgram program;

    @Column(name = "day_order", nullable = false)
    private short dayOrder;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(name = "archived_at")
    private Instant archivedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @OneToMany(mappedBy = "day", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("orderNo")
    private List<WorkoutExercise> exercises = new ArrayList<>();

    protected WorkoutDay() {
    }

    WorkoutDay(WorkoutProgram program, String name, int dayOrder, Instant now) {
        this.program = program;
        this.name = name;
        this.dayOrder = (short) dayOrder;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public void addExercise(Exercise exercise, int orderNo, int sets, int reps, int restSeconds, Instant now) {
        exercises.add(new WorkoutExercise(this, exercise, orderNo, sets, reps, restSeconds, now));
    }

    /** Xóa hết bài để INSERT lại theo body (docs/03 §5); phải flush trước khi thêm bài mới. */
    public void clearExercises() {
        exercises.clear();
    }

    public void update(String name, int dayOrder, Instant now) {
        this.name = name;
        this.dayOrder = (short) dayOrder;
        this.updatedAt = now;
    }

    /** Dời thứ tự tạm khỏi khoảng 1..n trước khi đánh lại (partial UNIQUE không DEFERRABLE được). */
    public void moveOrderAside(int offset) {
        this.dayOrder = (short) (dayOrder + offset);
    }

    /** BR-W07: buổi bị gỡ nhưng còn lịch; giữ nguyên bài để lịch SCHEDULED vẫn tập được. */
    public void archive(Instant now) {
        this.archivedAt = now;
        this.updatedAt = now;
    }

    public boolean isArchived() {
        return archivedAt != null;
    }

    public UUID getId() {
        return id;
    }

    public WorkoutProgram getProgram() {
        return program;
    }

    public int getDayOrder() {
        return dayOrder;
    }

    public String getName() {
        return name;
    }

    public List<WorkoutExercise> getExercises() {
        return exercises;
    }
}
