package com.viegym.backend.food.repository;

import com.viegym.backend.food.entity.FoodCategory;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FoodCategoryRepository extends JpaRepository<FoodCategory, UUID> {
    Optional<FoodCategory> findByCode(String code);
}
