package com.viegym.backend.exercise;

import com.viegym.backend.exercise.entity.Difficulty;
import com.viegym.backend.exercise.entity.Equipment;
import com.viegym.backend.exercise.entity.Exercise;
import com.viegym.backend.exercise.entity.MuscleGroup;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.List;
import org.springframework.data.jpa.domain.Specification;

final class ExerciseSpecifications {
    private ExerciseSpecifications() {
    }

    /**
     * Luôn có điều kiện active, client không bỏ được; các bộ lọc còn lại ghép AND.
     *
     * @param normalizedKeyword đã qua {@link SearchText#normalize}; rỗng = không tìm theo tên
     */
    static Specification<Exercise> activeMatching(String normalizedKeyword, MuscleGroup muscleGroup,
                                                  Equipment equipment, Difficulty difficulty) {
        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.isTrue(root.get("active")));
            if (!normalizedKeyword.isEmpty()) {
                String pattern = "%" + SearchText.escapeLike(normalizedKeyword) + "%";
                predicates.add(cb.like(root.get("nameSearch"), pattern, SearchText.LIKE_ESCAPE));
            }
            if (muscleGroup != null) {
                predicates.add(cb.equal(root.get("muscleGroup"), muscleGroup));
            }
            if (equipment != null) {
                predicates.add(cb.equal(root.get("equipment"), equipment));
            }
            if (difficulty != null) {
                predicates.add(cb.equal(root.get("difficulty"), difficulty));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
    }
}
