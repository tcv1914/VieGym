package com.viegym.backend.exercise.dto;

import com.viegym.backend.exercise.entity.Difficulty;
import com.viegym.backend.exercise.entity.Equipment;
import com.viegym.backend.exercise.entity.MediaType;
import com.viegym.backend.exercise.entity.MuscleGroup;
import java.util.UUID;

/** GET /exercises/{id}. {@code instructions}, {@code commonMistakes}: mỗi dòng một ý. */
public record ExerciseDetail(UUID id, String name, MuscleGroup muscleGroup, Equipment equipment,
                             Difficulty difficulty, String thumbnailUrl, String instructions,
                             String commonMistakes, MediaType mediaType, String mediaUrl,
                             String contentSource, String mediaLicense) {
}
