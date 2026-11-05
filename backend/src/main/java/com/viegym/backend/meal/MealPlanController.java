package com.viegym.backend.meal;

import com.viegym.backend.common.security.AuthenticatedUser;
import com.viegym.backend.meal.dto.MealDtos.AddEntryRequest;
import com.viegym.backend.meal.dto.MealDtos.MealPlanView;
import com.viegym.backend.meal.dto.MealDtos.UpdateEntryRequest;
import jakarta.validation.Valid;
import java.time.LocalDate;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * docs/05 §10. Mọi thao tác ghi trả toàn bộ thực đơn của ngày để app cập nhật tổng ngay
 * (DELETE trả 200, không 204). Mục của người khác → 404.
 */
@RestController
@RequestMapping("/api/v1/meal-plans")
public class MealPlanController {
    private final MealPlanService service;

    public MealPlanController(MealPlanService service) {
        this.service = service;
    }

    @GetMapping
    public MealPlanView get(@AuthenticationPrincipal AuthenticatedUser currentUser,
                            @RequestParam(required = false) LocalDate date) {
        return service.get(currentUser.userId(), date);
    }

    @PostMapping("/entries")
    @ResponseStatus(HttpStatus.CREATED)
    public MealPlanView add(@AuthenticationPrincipal AuthenticatedUser currentUser,
                            @Valid @RequestBody AddEntryRequest request) {
        return service.add(currentUser.userId(), request);
    }

    @PutMapping("/entries/{id}")
    public MealPlanView update(@AuthenticationPrincipal AuthenticatedUser currentUser, @PathVariable UUID id,
                               @Valid @RequestBody UpdateEntryRequest request) {
        return service.update(currentUser.userId(), id, request);
    }

    @DeleteMapping("/entries/{id}")
    public MealPlanView delete(@AuthenticationPrincipal AuthenticatedUser currentUser, @PathVariable UUID id) {
        return service.delete(currentUser.userId(), id);
    }
}
