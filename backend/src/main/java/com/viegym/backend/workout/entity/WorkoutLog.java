package com.viegym.backend.workout.entity;

import com.viegym.backend.exercise.entity.Exercise;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Kết quả thực tế của một buổi đã xếp lịch (docs/03 §5). Mọi tên đều là snapshot lúc ghi:
 * sửa giáo án, đổi tên hay ẩn bài sau này không đổi log (WO-BR04). MVP không sửa/xóa log.
 */
@Entity
@Table(name = "workout_logs")
public class WorkoutLog {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "schedule_id", updatable = false)
    private UUID scheduleId;

    @Column(name = "workout_date", nullable = false, updatable = false)
    private LocalDate workoutDate;

    @Column(name = "workout_name_snapshot", nullable = false, updatable = false, length = 100)
    private String workoutName;

    @Column(name = "program_name_snapshot", nullable = false, updatable = false, length = 100)
    private String programName;

    @Column(name = "started_at", updatable = false)
    private Instant startedAt;

    @Column(name = "ended_at", updatable = false)
    private Instant endedAt;

    @Column(length = 1000, updatable = false)
    private String note;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @OneToMany(mappedBy = "log", cascade = CascadeType.ALL)
    @OrderBy("orderNo")
    private List<WorkoutLogExercise> exercises = new ArrayList<>();

    protected WorkoutLog() {
    }

    public WorkoutLog(UUID userId, UUID scheduleId, LocalDate workoutDate, String workoutName, String programName,
                      Instant startedAt, Instant endedAt, String note, Instant now) {
        this.userId = userId;
        this.scheduleId = scheduleId;
        this.workoutDate = workoutDate;
        this.workoutName = workoutName;
        this.programName = programName;
        this.startedAt = startedAt;
        this.endedAt = endedAt;
        this.note = note;
        this.createdAt = now;
    }

    public WorkoutLogExercise addExercise(Exercise exercise, int orderNo, Instant now) {
        WorkoutLogExercise item = new WorkoutLogExercise(this, exercise.getId(), exercise.getName(), orderNo, now);
        exercises.add(item);
        return item;
    }

    public UUID getId() {
        return id;
    }

    public UUID getScheduleId() {
        return scheduleId;
    }

    public LocalDate getWorkoutDate() {
        return workoutDate;
    }

    public String getWorkoutName() {
        return workoutName;
    }

    public String getProgramName() {
        return programName;
    }

    public Instant getStartedAt() {
        return startedAt;
    }

    public Instant getEndedAt() {
        return endedAt;
    }

    public String getNote() {
        return note;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public List<WorkoutLogExercise> getExercises() {
        return exercises;
    }
}
