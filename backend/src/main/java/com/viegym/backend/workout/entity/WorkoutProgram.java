package com.viegym.backend.workout.entity;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

/**
 * Giáo án của user ({@code userId} khác null) hoặc giáo án mẫu ({@code userId} null).
 * {@link #days} chứa cả buổi đã archive; nơi hiển thị dùng {@link #currentDays()}.
 */
@Entity
@Table(name = "workout_programs")
public class WorkoutProgram {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", updatable = false)
    private UUID userId;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(length = 1000)
    private String description;

    @Column(name = "is_template", nullable = false, updatable = false)
    private boolean template;

    @Column(name = "is_active", nullable = false)
    private boolean active;

    @Column(name = "source_template_id", updatable = false)
    private UUID sourceTemplateId;

    /** Hibernate tự tăng khi giáo án đổi; service so với version client gửi để báo 409. */
    @Version
    @Column(nullable = false)
    private int version;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @OneToMany(mappedBy = "program", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("dayOrder")
    private List<WorkoutDay> days = new ArrayList<>();

    protected WorkoutProgram() {
    }

    /** Giáo án cá nhân; giáo án mẫu chỉ vào bằng migration seed. */
    public WorkoutProgram(UUID userId, String name, String description, UUID sourceTemplateId, Instant now) {
        this.userId = userId;
        this.name = name;
        this.description = description;
        this.template = false;
        this.sourceTemplateId = sourceTemplateId;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public WorkoutDay addDay(String name, int dayOrder, Instant now) {
        WorkoutDay day = new WorkoutDay(this, name, dayOrder, now);
        days.add(day);
        return day;
    }

    /** Xóa hẳn buổi chưa có lịch tham chiếu; orphanRemoval xóa luôn các bài của buổi. */
    public void removeDay(WorkoutDay day) {
        days.remove(day);
    }

    /** Sắp lại theo dayOrder: @OrderBy chỉ áp khi nạp, sau khi PUT đổi thứ tự thì list trong bộ nhớ vẫn theo thứ tự cũ. */
    public List<WorkoutDay> currentDays() {
        return days.stream().filter(d -> !d.isArchived())
            .sorted(Comparator.comparingInt(WorkoutDay::getDayOrder)).toList();
    }

    public void rename(String name, String description, Instant now) {
        this.name = name;
        this.description = description;
        this.updatedAt = now;
    }

    public void setActive(boolean active, Instant now) {
        if (this.active != active) {
            this.active = active;
            this.updatedAt = now;
        }
    }

    public boolean isOwnedBy(UUID userId) {
        return !template && this.userId.equals(userId);
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public String getName() {
        return name;
    }

    public String getDescription() {
        return description;
    }

    public boolean isTemplate() {
        return template;
    }

    public boolean isActive() {
        return active;
    }

    public UUID getSourceTemplateId() {
        return sourceTemplateId;
    }

    public int getVersion() {
        return version;
    }

    public List<WorkoutDay> getDays() {
        return days;
    }
}
