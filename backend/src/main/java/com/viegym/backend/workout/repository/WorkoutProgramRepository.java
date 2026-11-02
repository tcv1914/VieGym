package com.viegym.backend.workout.repository;

import com.viegym.backend.workout.entity.WorkoutProgram;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WorkoutProgramRepository extends JpaRepository<WorkoutProgram, UUID> {
    /** Chỉ giáo án của user; giáo án của người khác trả rỗng như không tồn tại (404). */
    Optional<WorkoutProgram> findByIdAndUserId(UUID id, UUID userId);

    Optional<WorkoutProgram> findByIdAndTemplateTrue(UUID id);

    List<WorkoutProgram> findByUserIdOrderByCreatedAtDescIdAsc(UUID userId);

    List<WorkoutProgram> findByTemplateTrueOrderByNameAsc();

    Optional<WorkoutProgram> findByUserIdAndActiveTrue(UUID userId);

    long countByUserId(UUID userId);
}
