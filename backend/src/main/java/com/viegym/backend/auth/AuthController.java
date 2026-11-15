package com.viegym.backend.auth;

import com.viegym.backend.auth.dto.LoginRequest;
import com.viegym.backend.auth.dto.RefreshRequest;
import com.viegym.backend.auth.dto.RegisterRequest;
import com.viegym.backend.auth.dto.TokenResponse;
import com.viegym.backend.auth.dto.UserResponse;
import com.viegym.backend.auth.reset.PasswordResetDtos.ForgotPasswordRequest;
import com.viegym.backend.auth.reset.PasswordResetDtos.ResetPasswordRequest;
import com.viegym.backend.auth.reset.PasswordResetService;
import jakarta.servlet.http.HttpServletRequest;
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
    private final PasswordResetService passwordResetService;

    public AuthController(AuthService authService, SessionService sessionService,
                          PasswordResetService passwordResetService) {
        this.authService = authService;
        this.sessionService = sessionService;
        this.passwordResetService = passwordResetService;
    }

    /** Không cấp token; app gọi tiếp /auth/login. */
    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse register(@Valid @RequestBody RegisterRequest request) {
        return authService.register(request);
    }

    @PostMapping("/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest request, HttpServletRequest http) {
        return authService.login(request, clientIp(http));
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

    /** BR-A06: luôn 204, kể cả email không tồn tại hoặc vượt giới hạn. */
    @PostMapping("/forgot-password")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void forgotPassword(@Valid @RequestBody ForgotPasswordRequest request, HttpServletRequest http) {
        passwordResetService.requestCode(request.email(), clientIp(http));
    }

    /** Không cấp token: app quay về màn đăng nhập. */
    @PostMapping("/reset-password")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void resetPassword(@Valid @RequestBody ResetPasswordRequest request, HttpServletRequest http) {
        passwordResetService.reset(request.email(), request.code(), request.newPassword(), clientIp(http));
    }

    // Backend nghe 127.0.0.1, không sau proxy, nên không đọc X-Forwarded-For (client tự đặt được).
    private static String clientIp(HttpServletRequest http) {
        return http.getRemoteAddr();
    }
}
