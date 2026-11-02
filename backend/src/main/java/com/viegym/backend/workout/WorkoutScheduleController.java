package com.viegym.backend.workout;

import com.viegym.backend.common.security.AuthenticatedUser;
import com.viegym.backend.workout.dto.ScheduleDtos.CreateScheduleRequest;
import com.viegym.backend.workout.dto.ScheduleDtos.ScheduleDetail;
import com.viegym.backend.workout.dto.ScheduleDtos.ScheduleList;
import com.viegym.backend.workout.dto.ScheduleDtos.UpdateScheduleRequest;
import com.viegym.backend.workout.entity.ScheduleStatus;
import jakarta.validation.Valid;
import java.time.LocalDate;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** docs/05 §7. Ngày sai định dạng / status lạ → 400 qua GlobalExceptionHandler. */
@RestController
@RequestMapping("/api/v1/workout-schedules")
public class WorkoutScheduleController {
    private final WorkoutScheduleService service;

    public WorkoutScheduleController(WorkoutScheduleService service) {
        this.service = service;
    }

    @GetMapping
    public ScheduleList list(@AuthenticationPrincipal AuthenticatedUser currentUser,
                             @RequestParam(required = false) LocalDate from,
                             @RequestParam(required = false) LocalDate to,
                             @RequestParam(required = false) ScheduleStatus status) {
        return service.list(currentUser.userId(), from, to, status);
    }

    @GetMapping("/{id}")
    public ScheduleDetail get(@AuthenticationPrincipal AuthenticatedUser currentUser, @PathVariable UUID id) {
        return service.get(currentUser.userId(), id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ScheduleDetail create(@AuthenticationPrincipal AuthenticatedUser currentUser,
                                 @Valid @RequestBody CreateScheduleRequest request) {
        return service.create(currentUser.userId(), request);
    }

    @PutMapping("/{id}")
    public ScheduleDetail update(@AuthenticationPrincipal AuthenticatedUser currentUser, @PathVariable UUID id,
                                 @Valid @RequestBody UpdateScheduleRequest request) {
        return service.update(currentUser.userId(), id, request);
    }
}
