package com.viegym.backend.exercise.repository;

import com.viegym.backend.exercise.entity.Exercise;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface ExerciseRepository extends JpaRepository<Exercise, UUID>, JpaSpecificationExecutor<Exercise> {
    Optional<Exercise> findByIdAndActiveTrue(UUID id);
}
