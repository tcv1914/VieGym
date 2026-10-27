package com.viegym.backend.auth.dto;

import jakarta.validation.constraints.NotBlank;
import java.util.Locale;

public record LoginRequest(
    @NotBlank(message = "Vui lòng nhập email") String email,
    @NotBlank(message = "Vui lòng nhập mật khẩu") String password
) {
    public LoginRequest {
        email = email == null ? null : email.trim().toLowerCase(Locale.ROOT);
    }

    @Override
    public String toString() {
        return "LoginRequest[email=" + email + "]";
    }
}
