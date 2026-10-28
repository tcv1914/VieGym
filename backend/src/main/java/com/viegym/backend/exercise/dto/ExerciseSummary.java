package com.viegym.backend.exercise.dto;

import com.viegym.backend.exercise.entity.Difficulty;
import com.viegym.backend.exercise.entity.Equipment;
import com.viegym.backend.exercise.entity.MuscleGroup;
import java.util.UUID;

/** Phần tử danh sách GET /exercises (docs/05 §5). */
public record ExerciseSummary(UUID id, String name, MuscleGroup muscleGroup, Equipment equipment,
                              Difficulty difficulty, String thumbnailUrl) {
}
