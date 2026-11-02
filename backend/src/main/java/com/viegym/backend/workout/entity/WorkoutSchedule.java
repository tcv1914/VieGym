package com.viegym.backend.workout.entity;

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
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

/**
 * Một buổi được xếp vào ngày cụ thể. Tham chiếu buổi trong giáo án (docs/03 §5), không chụp
 * snapshot bài: snapshot nằm ở workout log ngày 8 (WO-BR04). Xem docs/16 §1.
 */
@Entity
@Table(name = "workout_schedules")
public class WorkoutSchedule {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "workout_day_id", nullable = false, updatable = false)
    private WorkoutDay workoutDay;

    @Column(name = "scheduled_date", nullable = false)
    private LocalDate scheduledDate;

    @Column(name = "start_time")
    private LocalTime startTime;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private ScheduleStatus status;

    @Column(length = 500)
    private String note;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected WorkoutSchedule() {
    }

    public WorkoutSchedule(UUID userId, WorkoutDay workoutDay, LocalDate scheduledDate, LocalTime startTime,
                           String note, Instant now) {
        this.userId = userId;
        this.workoutDay = workoutDay;
        this.scheduledDate = scheduledDate;
        this.startTime = startTime;
        this.note = note;
        this.status = ScheduleStatus.SCHEDULED;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public void reschedule(LocalDate date, LocalTime startTime, String note, Instant now) {
        this.scheduledDate = date;
        this.startTime = startTime;
        this.note = note;
        this.updatedAt = now;
    }

    public void cancel(Instant now) {
        this.status = ScheduleStatus.CANCELLED;
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public WorkoutDay getWorkoutDay() {
        return workoutDay;
    }

    public LocalDate getScheduledDate() {
        return scheduledDate;
    }

    public LocalTime getStartTime() {
        return startTime;
    }

    public ScheduleStatus getStatus() {
        return status;
    }

    public String getNote() {
        return note;
    }
}
