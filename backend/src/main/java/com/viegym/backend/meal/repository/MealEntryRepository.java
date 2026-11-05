package com.viegym.backend.meal.repository;

import com.viegym.backend.meal.entity.MealEntry;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface MealEntryRepository extends JpaRepository<MealEntry, UUID> {
    /** Thứ tự thêm; id phá hòa khi cùng thời điểm. */
    @Query("select e from MealEntry e where e.mealPlan.id = :planId order by e.createdAt, e.id")
    List<MealEntry> findByPlan(UUID planId);

    long countByMealPlanId(UUID planId);

    /** Luôn kèm user: mục của người khác trả rỗng như không tồn tại (A9). */
    @Query("select e from MealEntry e join fetch e.mealPlan p where e.id = :id and p.userId = :userId")
    Optional<MealEntry> findOwned(UUID id, UUID userId);
}
