package com.viegym.backend.health.repository;

import com.viegym.backend.health.entity.NutritionTarget;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NutritionTargetRepository extends JpaRepository<NutritionTarget, UUID> {
    Optional<NutritionTarget> findByUserId(UUID userId);
}
