package com.viegym.backend.exercise;

import com.viegym.backend.common.exception.ApiException;
import com.viegym.backend.common.web.PageResponse;
import com.viegym.backend.exercise.dto.ExerciseDetail;
import com.viegym.backend.exercise.dto.ExerciseFilters;
import com.viegym.backend.exercise.dto.ExerciseSummary;
import com.viegym.backend.exercise.entity.Difficulty;
import com.viegym.backend.exercise.entity.Equipment;
import com.viegym.backend.exercise.entity.Exercise;
import com.viegym.backend.exercise.entity.MuscleGroup;
import com.viegym.backend.exercise.repository.ExerciseRepository;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ExerciseService {
    public static final int MAX_PAGE_SIZE = 100;
    public static final int MAX_KEYWORD_LENGTH = 100;

    // name_search không duy nhất; thêm id để thứ tự ổn định giữa các trang.
    private static final Sort ORDER = Sort.by("nameSearch", "id");

    private final ExerciseRepository repository;
    private final MediaUrlResolver mediaUrls;

    public ExerciseService(ExerciseRepository repository, MediaUrlResolver mediaUrls) {
        this.repository = repository;
        this.mediaUrls = mediaUrls;
    }

    @Transactional(readOnly = true)
    public PageResponse<ExerciseSummary> search(String keyword, MuscleGroup muscleGroup, Equipment equipment,
                                                Difficulty difficulty, int page, int size) {
        if (page < 0) {
            throw ApiException.validation("page", "Số trang phải từ 0");
        }
        if (size < 1 || size > MAX_PAGE_SIZE) {
            throw ApiException.validation("size", "Kích thước trang phải từ 1 đến " + MAX_PAGE_SIZE);
        }
        String normalized = SearchText.normalize(keyword);
        if (normalized.length() > MAX_KEYWORD_LENGTH) {
            throw ApiException.validation("keyword", "Từ khóa tối đa " + MAX_KEYWORD_LENGTH + " ký tự");
        }
        var spec = ExerciseSpecifications.activeMatching(normalized, muscleGroup, equipment, difficulty);
        return PageResponse.of(repository.findAll(spec, PageRequest.of(page, size, ORDER)), this::toSummary);
    }

    /** Bài đã ẩn cũng trả 404 như bài không tồn tại (docs/05 §5, BR-G07). */
    @Transactional(readOnly = true)
    public ExerciseDetail get(UUID id) {
        Exercise e = repository.findByIdAndActiveTrue(id).orElseThrow(() -> new ApiException(
            HttpStatus.NOT_FOUND, "NOT_FOUND", "Bài tập không tồn tại hoặc đã ngừng hiển thị"));
        return new ExerciseDetail(e.getId(), e.getName(), e.getMuscleGroup(), e.getEquipment(), e.getDifficulty(),
            mediaUrls.resolve(e.getThumbnailUrl()), e.getInstructions(), e.getCommonMistakes(), e.getMediaType(),
            mediaUrls.resolve(e.getMediaUrl()), e.getContentSource(), e.getMediaLicense());
    }

    public ExerciseFilters filters() {
        return new ExerciseFilters(ExerciseFilters.options(MuscleGroup.class),
            ExerciseFilters.options(Equipment.class), ExerciseFilters.options(Difficulty.class));
    }

    private ExerciseSummary toSummary(Exercise e) {
        return new ExerciseSummary(e.getId(), e.getName(), e.getMuscleGroup(), e.getEquipment(), e.getDifficulty(),
            mediaUrls.resolve(e.getThumbnailUrl()));
    }
}
