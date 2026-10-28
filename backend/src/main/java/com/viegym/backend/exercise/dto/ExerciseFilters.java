package com.viegym.backend.exercise.dto;

import com.viegym.backend.exercise.entity.Labeled;
import java.util.Arrays;
import java.util.List;

/** GET /exercise-filters: mã dùng trong query + nhãn hiển thị, theo thứ tự khai báo enum. */
public record ExerciseFilters(List<Option> muscleGroups, List<Option> equipment, List<Option> difficulties) {
    public record Option(String code, String name) {
    }

    public static <E extends Enum<E> & Labeled> List<Option> options(Class<E> type) {
        return Arrays.stream(type.getEnumConstants()).map(e -> new Option(e.name(), e.label())).toList();
    }
}
