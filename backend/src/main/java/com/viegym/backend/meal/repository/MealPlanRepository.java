package com.viegym.backend.meal.repository;

import com.viegym.backend.meal.entity.MealPlan;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MealPlanRepository extends JpaRepository<MealPlan, UUID> {
    Optional<MealPlan> findByUserIdAndPlanDate(UUID userId, LocalDate planDate);
}
