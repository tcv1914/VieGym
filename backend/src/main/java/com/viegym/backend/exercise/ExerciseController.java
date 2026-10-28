package com.viegym.backend.exercise;

import com.viegym.backend.common.web.PageResponse;
import com.viegym.backend.exercise.dto.ExerciseDetail;
import com.viegym.backend.exercise.dto.ExerciseFilters;
import com.viegym.backend.exercise.dto.ExerciseSummary;
import com.viegym.backend.exercise.entity.Difficulty;
import com.viegym.backend.exercise.entity.Equipment;
import com.viegym.backend.exercise.entity.MuscleGroup;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Chỉ đọc, cho mọi tài khoản đã đăng nhập; không có endpoint ghi ở phía user. */
@RestController
@RequestMapping("/api/v1")
public class ExerciseController {
    private final ExerciseService service;

    public ExerciseController(ExerciseService service) {
        this.service = service;
    }

    /** Enum sai (kể cả sai hoa/thường) hoặc page/size không phải số → 400 qua GlobalExceptionHandler. */
    @GetMapping("/exercises")
    public PageResponse<ExerciseSummary> list(@RequestParam(required = false) String keyword,
                                              @RequestParam(required = false) MuscleGroup muscleGroup,
                                              @RequestParam(required = false) Equipment equipment,
                                              @RequestParam(required = false) Difficulty difficulty,
                                              @RequestParam(defaultValue = "0") int page,
                                              @RequestParam(defaultValue = "20") int size) {
        return service.search(keyword, muscleGroup, equipment, difficulty, page, size);
    }

    @GetMapping("/exercises/{id}")
    public ExerciseDetail get(@PathVariable UUID id) {
        return service.get(id);
    }

    @GetMapping("/exercise-filters")
    public ExerciseFilters filters() {
        return service.filters();
    }
}
