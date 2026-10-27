package com.viegym.backend.auth;

import com.viegym.backend.auth.dto.LoginRequest;
import com.viegym.backend.auth.dto.RefreshRequest;
import com.viegym.backend.auth.dto.RegisterRequest;
import com.viegym.backend.auth.dto.TokenResponse;
import com.viegym.backend.auth.dto.UserResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Response có Cache-Control: no-store từ header mặc định của Spring Security. */
@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    private final AuthService authService;
    private final SessionService sessionService;

    public AuthController(AuthService authService, SessionService sessionService) {
        this.authService = authService;
        this.sessionService = sessionService;
    }

    /** Không cấp token; app gọi tiếp /auth/login. */
    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse register(@Valid @RequestBody RegisterRequest request) {
        return authService.register(request);
    }

    @PostMapping("/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }

    @PostMapping("/refresh")
    public TokenResponse refresh(@Valid @RequestBody RefreshRequest request) {
        return sessionService.refresh(request.refreshToken());
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(@Valid @RequestBody RefreshRequest request) {
        sessionService.logout(request.refreshToken());
    }
}
