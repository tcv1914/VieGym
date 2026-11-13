package com.viegym.backend.food.repository;

import com.viegym.backend.food.entity.Food;
import com.viegym.backend.food.entity.FoodCategory;
import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface FoodRepository extends JpaRepository<Food, UUID>, JpaSpecificationExecutor<Food> {
    /** Tải kèm danh mục để một trang không phát sinh truy vấn mỗi món. */
    @Override
    @EntityGraph(attributePaths = "category")
    Page<Food> findAll(Specification<Food> spec, Pageable pageable);

    @Query("select f from Food f join fetch f.category where f.id = :id and f.active = true")
    Optional<Food> findActive(UUID id);

    /** Danh mục còn ít nhất một món hiển thị, theo thứ tự của nguồn. */
    @Query("""
        select c from FoodCategory c
        where exists (select 1 from Food f where f.category = c and f.active = true)
        order by c.sortOrder
        """)
    List<FoodCategory> categoriesWithActiveFoods();

    /** Admin: cả món ẩn. */
    @Query("select f from Food f join fetch f.category where f.id = :id")
    Optional<Food> findWithCategory(UUID id);

    /** Admin sửa: khóa dòng để so revision rồi ghi không bị chen giữa (docs/31 §3). */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select f from Food f join fetch f.category where f.id = :id")
    Optional<Food> findForUpdate(UUID id);
}
