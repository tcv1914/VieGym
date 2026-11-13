package com.viegym.backend.exercise.repository;

import com.viegym.backend.exercise.entity.Exercise;
import jakarta.persistence.LockModeType;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface ExerciseRepository extends JpaRepository<Exercise, UUID>, JpaSpecificationExecutor<Exercise> {
    Optional<Exercise> findByIdAndActiveTrue(UUID id);

    /** Admin sửa: khóa dòng để so revision rồi ghi không bị chen giữa (docs/31 §3). */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select e from Exercise e where e.id = :id")
    Optional<Exercise> findForUpdate(UUID id);

    /** Trùng với UNIQUE lower(name) của V4; kiểm tra trước để trả lỗi theo trường. */
    boolean existsByNameIgnoreCase(String name);

    boolean existsByNameIgnoreCaseAndIdNot(String name, UUID id);
}
