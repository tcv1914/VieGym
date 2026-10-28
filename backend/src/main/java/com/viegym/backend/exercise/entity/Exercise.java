package com.viegym.backend.exercise.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

/** Chỉ đọc ở ngày 6; dữ liệu vào bằng migration seed, admin CRUD ở ngày 14. */
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

    protected Exercise() {
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

    public String getMediaLicense() {
        return mediaLicense;
    }
}
