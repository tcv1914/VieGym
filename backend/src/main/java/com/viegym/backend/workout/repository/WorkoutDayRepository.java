package com.viegym.backend.workout.repository;

import com.viegym.backend.workout.entity.WorkoutDay;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface WorkoutDayRepository extends JpaRepository<WorkoutDay, UUID> {
    /** Buổi thuộc giáo án của user (không phải mẫu); buổi của người khác trả rỗng. */
    @Query("select d from WorkoutDay d join fetch d.program p where d.id = :id and p.userId = :userId")
    Optional<WorkoutDay> findOwned(UUID id, UUID userId);
}
