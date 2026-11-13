package com.viegym.backend.exercise.entity;

import com.viegym.backend.exercise.SearchText;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** Seed bằng migration (ngày 6); admin tạo/sửa/ẩn từ ngày 14 (docs/31). */
@Entity
@Table(name = "exercises")
public class Exercise {
    @Id
    private UUID id;

    @Column(nullable = false, updatable = false, length = 100)
    private String code;

    @Column(nullable = false, length = 150)
    private String name;

    @Column(name = "name_search", nullable = false, length = 150)
    private String nameSearch;

    @Enumerated(EnumType.STRING)
    @Column(name = "muscle_group", nullable = false, length = 20)
    private MuscleGroup muscleGroup;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Equipment equipment;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private Difficulty difficulty;

    @Column(nullable = false, columnDefinition = "text")
    private String instructions;

    @Column(name = "common_mistakes", nullable = false, columnDefinition = "text")
    private String commonMistakes;

    @Column(name = "thumbnail_url", length = 500)
    private String thumbnailUrl;

    @Enumerated(EnumType.STRING)
    @Column(name = "media_type", length = 10)
    private MediaType mediaType;

    @Column(name = "media_url", length = 500)
    private String mediaUrl;

    @Column(name = "is_active", nullable = false)
    private boolean active;

    @Column(name = "content_source", length = 500)
    private String contentSource;

    @Column(name = "media_license", length = 500)
    private String mediaLicense;

    @Column(nullable = false)
    private int revision;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Exercise() {
    }

    /** Bài admin tạo; {@code code} cố định từ lúc tạo (docs/31 §3). */
    public Exercise(String code, ExerciseValues values, Instant now) {
        this.id = UUID.randomUUID();
        this.code = code;
        this.revision = 1;
        this.updatedAt = now;
        assign(values);
    }

    /** Lịch/giáo án tham chiếu theo id nên thấy nội dung mới; nhật ký tập giữ tên đã ghi. */
    public void update(ExerciseValues values, Instant now) {
        assign(values);
        this.revision++;
        this.updatedAt = now;
    }

    public ExerciseValues values() {
        return new ExerciseValues(name, muscleGroup, equipment, difficulty, instructions, commonMistakes,
            thumbnailUrl, mediaType, mediaUrl, contentSource, mediaLicense, active);
    }

    private void assign(ExerciseValues v) {
        this.name = v.name();
        this.nameSearch = SearchText.normalize(v.name());
        this.muscleGroup = v.muscleGroup();
        this.equipment = v.equipment();
        this.difficulty = v.difficulty();
        this.instructions = v.instructions();
        this.commonMistakes = v.commonMistakes();
        this.thumbnailUrl = v.thumbnailUrl();
        this.mediaType = v.mediaType();
        this.mediaUrl = v.mediaUrl();
        this.contentSource = v.contentSource();
        this.mediaLicense = v.mediaLicense();
        this.active = v.active();
    }

    public UUID getId() {
        return id;
    }

    public String getCode() {
        return code;
    }

    public String getName() {
        return name;
    }

    public MuscleGroup getMuscleGroup() {
        return muscleGroup;
    }

    public Equipment getEquipment() {
        return equipment;
    }

    public Difficulty getDifficulty() {
        return difficulty;
    }

    public String getInstructions() {
        return instructions;
    }

    public String getCommonMistakes() {
        return commonMistakes;
    }

    public String getThumbnailUrl() {
        return thumbnailUrl;
    }

    public MediaType getMediaType() {
        return mediaType;
    }

    public String getMediaUrl() {
        return mediaUrl;
    }

    public boolean isActive() {
        return active;
    }

    public String getContentSource() {
        return contentSource;
    }

    public int getRevision() {
        return revision;
    }

    public String getMediaLicense() {
        return mediaLicense;
    }
}
