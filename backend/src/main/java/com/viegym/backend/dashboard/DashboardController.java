package com.viegym.backend.dashboard;

import com.viegym.backend.common.security.AuthenticatedUser;
import com.viegym.backend.dashboard.DashboardDtos.DashboardView;
import java.time.LocalDate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** docs/05 §11. Không nhận userId: luôn là người đang đăng nhập. */
@RestController
@RequestMapping("/api/v1/dashboard")
public class DashboardController {
    private final DashboardService service;

    public DashboardController(DashboardService service) {
        this.service = service;
    }

    @GetMapping
    public DashboardView get(@AuthenticationPrincipal AuthenticatedUser currentUser,
                             @RequestParam(required = false) LocalDate date) {
        return service.get(currentUser.userId(), date);
    }
}
