package com.viegym.backend.admin;

import com.viegym.backend.admin.AdminDtos.AdminExerciseDetail;
import com.viegym.backend.admin.AdminDtos.AdminExerciseItem;
import com.viegym.backend.admin.AdminDtos.ExerciseRequest;
import com.viegym.backend.admin.audit.AdminAudit;
import com.viegym.backend.admin.audit.AuditLog.Action;
import com.viegym.backend.admin.audit.AuditLog.EntityType;
import com.viegym.backend.common.exception.ApiException;
import com.viegym.backend.common.web.PageResponse;
import com.viegym.backend.exercise.MediaUrlResolver;
import com.viegym.backend.exercise.SearchText;
import com.viegym.backend.exercise.entity.Exercise;
import com.viegym.backend.exercise.entity.ExerciseValues;
import com.viegym.backend.exercise.entity.MuscleGroup;
import com.viegym.backend.exercise.repository.ExerciseRepository;
import jakarta.persistence.criteria.Predicate;
import java.time.Clock;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Pattern;
import org.springframework.core.io.ClassPathResource;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Admin quản lý bài tập (docs/31 §3). Không xóa: ẩn bằng {@code active = false}; giáo án/lịch đã có
 * vẫn đọc được bài ẩn, chỉ không thêm mới được (BR-G07, BR-W08).
 */
@Service
public class AdminExerciseService {
    private static final Sort ORDER = Sort.by("nameSearch", "id");
    private static final Pattern HTTP_URL = Pattern.compile(AdminDtos.HTTP_URL);
    // Key tương đối giống seed (docs/13): exercises/<tệp>, không cho "..", "/" lồng hay ký tự lạ.
    private static final Pattern MEDIA_KEY = Pattern.compile("^exercises/[A-Za-z0-9][A-Za-z0-9._-]*$");

    private final ExerciseRepository repository;
    private final MediaUrlResolver mediaUrls;
    private final AdminAudit audit;
    private final Clock clock;

    public AdminExerciseService(ExerciseRepository repository, MediaUrlResolver mediaUrls, AdminAudit audit,
                                Clock clock) {
        this.repository = repository;
        this.mediaUrls = mediaUrls;
        this.audit = audit;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public PageResponse<AdminExerciseItem> search(String keyword, MuscleGroup muscleGroup, Boolean active,
                                                  int page, int size) {
        AdminSupport.checkPage(page, size);
        String normalized = AdminSupport.normalizedKeyword(keyword);
        Specification<Exercise> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (!normalized.isEmpty()) {
                String pattern = "%" + SearchText.escapeLike(normalized) + "%";
                predicates.add(cb.or(
                    cb.like(root.get("nameSearch"), pattern, SearchText.LIKE_ESCAPE),
                    cb.like(cb.lower(root.get("code")), pattern, SearchText.LIKE_ESCAPE)));
            }
            if (muscleGroup != null) {
                predicates.add(cb.equal(root.get("muscleGroup"), muscleGroup));
            }
            if (active != null) {
                predicates.add(cb.equal(root.get("active"), active));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
        return PageResponse.of(repository.findAll(spec, PageRequest.of(page, size, ORDER)), e ->
            new AdminExerciseItem(e.getId(), e.getCode(), e.getName(), e.getMuscleGroup(), e.getEquipment(),
                e.getDifficulty(), mediaUrls.resolve(e.getThumbnailUrl()), e.isActive(), e.getRevision()));
    }

    @Transactional(readOnly = true)
    public AdminExerciseDetail get(UUID id) {
        return toDetail(repository.findById(id).orElseThrow(AdminExerciseService::notFound));
    }

    @Transactional
    public AdminExerciseDetail create(UUID actorId, ExerciseRequest request) {
        AdminSupport.checkRevisionPresence(request.revision(), true);
        ExerciseValues values = toValues(request, null);
        Exercise exercise = saveAndFlush(new Exercise(AdminSupport.newCode("admin-"), values, clock.instant()));
        audit.record(actorId, Action.CREATE, EntityType.EXERCISE,
            exercise.getId(), null, null);
        return toDetail(exercise);
    }

    @Transactional
    public AdminExerciseDetail update(UUID actorId, UUID id, ExerciseRequest request) {
        AdminSupport.checkRevisionPresence(request.revision(), false);
        Exercise exercise = repository.findForUpdate(id).orElseThrow(AdminExerciseService::notFound);
        if (request.revision() != exercise.getRevision()) {
            throw AdminSupport.revisionConflict(exercise.getRevision());
        }
        ExerciseValues after = toValues(request, id);
        List<String> changed = AdminAudit.diff(exercise.values(), after);
        if (changed.isEmpty()) {
            return toDetail(exercise);
        }
        exercise.update(after, clock.instant());
        saveAndFlush(exercise);
        audit.record(actorId, AdminFoodService.action(changed, after.active()), EntityType.EXERCISE,
            exercise.getId(), null, changed);
        return toDetail(exercise);
    }

    private Exercise saveAndFlush(Exercise exercise) {
        try {
            return repository.saveAndFlush(exercise);
        } catch (DataIntegrityViolationException ex) {
            // Hai admin cùng đặt một tên: UNIQUE lower(name) chặn bản sau.
            throw nameTaken();
        }
    }

    private ExerciseValues toValues(ExerciseRequest r, UUID currentId) {
        Map<String, String> errors = new LinkedHashMap<>();
        boolean taken = currentId == null ? repository.existsByNameIgnoreCase(r.name())
            : repository.existsByNameIgnoreCaseAndIdNot(r.name(), currentId);
        if (taken) {
            throw nameTaken();
        }
        checkMedia("thumbnailUrl", r.thumbnailUrl(), errors);
        checkMedia("mediaUrl", r.mediaUrl(), errors);
        // Khớp CHECK exercises_media_pair_check.
        if ((r.mediaUrl() == null) != (r.mediaType() == null)) {
            errors.put(r.mediaUrl() == null ? "mediaUrl" : "mediaType",
                "Nhập cả loại và đường dẫn media, hoặc bỏ trống cả hai");
        }
        if (!errors.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Dữ liệu không hợp lệ", errors);
        }
        return new ExerciseValues(r.name(), r.muscleGroup(), r.equipment(), r.difficulty(), r.instructions(),
            r.commonMistakes(), r.thumbnailUrl(), r.mediaType(), r.mediaUrl(), r.contentSource(),
            r.mediaLicense(), r.active());
    }

    /** URL http(s), hoặc key tệp tĩnh có thật trong static/media; chưa có upload ở MVP. */
    private static void checkMedia(String field, String value, Map<String, String> errors) {
        if (value == null || HTTP_URL.matcher(value).matches()) {
            return;
        }
        if (!MEDIA_KEY.matcher(value).matches() || !new ClassPathResource("static/media/" + value).exists()) {
            errors.put(field, "Dùng URL http(s) hoặc tệp có sẵn dạng exercises/<tên tệp>");
        }
    }

    private AdminExerciseDetail toDetail(Exercise e) {
        return new AdminExerciseDetail(e.getId(), e.getCode(), e.getName(), e.getMuscleGroup(), e.getEquipment(),
            e.getDifficulty(), e.getInstructions(), e.getCommonMistakes(), e.getThumbnailUrl(),
            mediaUrls.resolve(e.getThumbnailUrl()), e.getMediaType(), e.getMediaUrl(),
            mediaUrls.resolve(e.getMediaUrl()), e.getContentSource(), e.getMediaLicense(), e.isActive(),
            e.getRevision());
    }

    private static ApiException nameTaken() {
        return new ApiException(HttpStatus.CONFLICT, "EXERCISE_NAME_TAKEN", "Tên bài tập đã tồn tại",
            Map.of("name", "Đã có bài tập cùng tên"));
    }

    private static ApiException notFound() {
        return AdminSupport.notFound("Bài tập không tồn tại");
    }
}
