package com.viegym.backend.exercise.entity;

/** Nhóm cơ chính (docs/03 §5); nhãn dùng cho GET /exercise-filters. */
public enum MuscleGroup implements Labeled {
    CHEST("Ngực"),
    BACK("Lưng"),
    SHOULDERS("Vai"),
    ARMS("Tay"),
    LEGS("Chân"),
    GLUTES("Mông"),
    CORE("Bụng/Core"),
    FULL_BODY("Toàn thân"),
    CARDIO("Cardio");

    private final String label;

    MuscleGroup(String label) {
        this.label = label;
    }

    @Override
    public String label() {
        return label;
    }
}
