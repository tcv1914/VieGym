package com.viegym.backend.workout;

import com.viegym.backend.common.security.AuthenticatedUser;
import com.viegym.backend.common.web.PageResponse;
import com.viegym.backend.workout.dto.LogDtos.CreateLogRequest;
import com.viegym.backend.workout.dto.LogDtos.LogDetail;
import com.viegym.backend.workout.dto.LogDtos.LogSummary;
import jakarta.validation.Valid;
import java.time.LocalDate;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * docs/05 §8. Không có API "đánh dấu hoàn thành" riêng: COMPLETED chỉ có cùng với log (BR-W04).
 * Mọi truy vấn kèm user hiện tại; log của người khác → 404.
 */
@RestController
@RequestMapping("/api/v1/workout-logs")
public class WorkoutLogController {
    private final WorkoutLogService service;

    public WorkoutLogController(WorkoutLogService service) {
        this.service = service;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public LogDetail create(@AuthenticationPrincipal AuthenticatedUser currentUser,
                            @Valid @RequestBody CreateLogRequest request) {
        return service.create(currentUser.userId(), request);
    }

    @GetMapping
    public PageResponse<LogSummary> list(@AuthenticationPrincipal AuthenticatedUser currentUser,
                                         @RequestParam(required = false) LocalDate from,
                                         @RequestParam(required = false) LocalDate to,
                                         @RequestParam(defaultValue = "0") int page,
                                         @RequestParam(defaultValue = "20") int size) {
        return service.list(currentUser.userId(), from, to, page, size);
    }

    @GetMapping("/{id}")
    public LogDetail get(@AuthenticationPrincipal AuthenticatedUser currentUser, @PathVariable UUID id) {
        return service.get(currentUser.userId(), id);
    }
}
