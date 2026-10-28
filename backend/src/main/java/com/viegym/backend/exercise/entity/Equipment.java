package com.viegym.backend.exercise.entity;

/** Thiết bị chính (docs/03 §5). */
public enum Equipment implements Labeled {
    NONE("Không dụng cụ"),
    DUMBBELL("Tạ đơn"),
    BARBELL("Tạ đòn"),
    MACHINE("Máy"),
    CABLE("Cáp"),
    BAND("Dây kháng lực"),
    OTHER("Khác");

    private final String label;

    Equipment(String label) {
        this.label = label;
    }

    @Override
    public String label() {
        return label;
    }
}
