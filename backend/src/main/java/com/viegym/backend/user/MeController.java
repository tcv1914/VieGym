package com.viegym.backend.user;

import com.viegym.backend.auth.dto.UserResponse;
import com.viegym.backend.auth.repository.UserRepository;
import com.viegym.backend.common.exception.ApiException;
import com.viegym.backend.common.security.AuthenticatedUser;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users")
public class MeController {
    private final UserRepository userRepository;

    public MeController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    /** ID lấy từ phiên đã xác minh; không có tham số userId (BR-G01). */
    @GetMapping("/me")
    public UserResponse me(@AuthenticationPrincipal AuthenticatedUser currentUser) {
        return userRepository.findById(currentUser.userId())
            .map(UserResponse::from)
            .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy tài khoản"));
    }
}
