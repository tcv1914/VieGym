package com.viegym.backend.workout;

import com.viegym.backend.common.security.AuthenticatedUser;
import com.viegym.backend.workout.dto.ProgramDtos.ProgramDetail;
import com.viegym.backend.workout.dto.ProgramDtos.ProgramList;
import com.viegym.backend.workout.dto.ProgramDtos.ProgramRequest;
import jakarta.validation.Valid;
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

/** docs/05 §6. Chủ sở hữu luôn lấy từ token (BR-G01). */
@RestController
@RequestMapping("/api/v1/workout-programs")
public class WorkoutProgramController {
    private final WorkoutProgramService service;

    public WorkoutProgramController(WorkoutProgramService service) {
        this.service = service;
    }

    @GetMapping
    public ProgramList list(@AuthenticationPrincipal AuthenticatedUser currentUser,
                            @RequestParam(required = false) String scope) {
        return service.list(currentUser.userId(), scope);
    }

    @GetMapping("/{id}")
    public ProgramDetail get(@AuthenticationPrincipal AuthenticatedUser currentUser, @PathVariable UUID id) {
        return service.get(currentUser.userId(), id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ProgramDetail create(@AuthenticationPrincipal AuthenticatedUser currentUser,
                                @Valid @RequestBody ProgramRequest request) {
        return service.create(currentUser.userId(), request);
    }

    @PutMapping("/{id}")
    public ProgramDetail update(@AuthenticationPrincipal AuthenticatedUser currentUser, @PathVariable UUID id,
                                @Valid @RequestBody ProgramRequest request) {
        return service.update(currentUser.userId(), id, request);
    }

    /** Bổ sung so với docs/05 ngày 2: kích hoạt mà không gửi lại cả giáo án. */
    @PostMapping("/{id}/activate")
    public ProgramDetail activate(@AuthenticationPrincipal AuthenticatedUser currentUser, @PathVariable UUID id) {
        return service.activate(currentUser.userId(), id);
    }
}
