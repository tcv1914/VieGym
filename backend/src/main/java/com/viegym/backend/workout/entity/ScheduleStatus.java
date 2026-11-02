package com.viegym.backend.workout.entity;

/** BR-W04: COMPLETED chỉ qua POST /workout-logs (ngày 8); COMPLETED, CANCELLED là trạng thái cuối. */
public enum ScheduleStatus {
    SCHEDULED,
    COMPLETED,
    CANCELLED
}
