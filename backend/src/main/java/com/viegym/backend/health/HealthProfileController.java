package com.viegym.backend.health;

import com.viegym.backend.common.security.AuthenticatedUser;
import com.viegym.backend.health.dto.HealthProfileRequest;
import com.viegym.backend.health.dto.HealthProfileResponse;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Chỉ hồ sơ của user hiện tại; không có endpoint đọc hồ sơ theo userId (BR-G01). */
@RestController
@RequestMapping("/api/v1/health-profile")
public class HealthProfileController {
    private final HealthProfileService service;

    public HealthProfileController(HealthProfileService service) {
        this.service = service;
    }

    @GetMapping("/me")
    public HealthProfileResponse get(@AuthenticationPrincipal AuthenticatedUser currentUser) {
        return service.get(currentUser.userId());
    }

    /** Tạo mới hoặc thay toàn bộ; luôn 200 kèm mục tiêu vừa tính. */
    @PutMapping("/me")
    public HealthProfileResponse put(@AuthenticationPrincipal AuthenticatedUser currentUser,
                                     @Valid @RequestBody HealthProfileRequest request) {
        return service.put(currentUser.userId(), request);
    }
}
