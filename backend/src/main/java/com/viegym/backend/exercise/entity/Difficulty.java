package com.viegym.backend.exercise.entity;

public enum Difficulty implements Labeled {
    BEGINNER("Cơ bản"),
    INTERMEDIATE("Trung bình"),
    ADVANCED("Nâng cao");

    private final String label;

    Difficulty(String label) {
        this.label = label;
    }

    @Override
    public String label() {
        return label;
    }
}
