package com.viegym.backend.exercise.entity;

/** Các trường admin sửa được của một bài tập (docs/31 §3); đã kiểm tra hợp lệ trước khi tạo. */
public record ExerciseValues(String name, MuscleGroup muscleGroup, Equipment equipment, Difficulty difficulty,
                             String instructions, String commonMistakes, String thumbnailUrl,
                             MediaType mediaType, String mediaUrl, String contentSource, String mediaLicense,
                             boolean active) {
}
