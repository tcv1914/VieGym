package com.viegym.backend.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Dùng cho cả /auth/refresh và /auth/logout. */
public record RefreshRequest(
    @NotBlank(message = "Thiếu refresh token")
    @Size(max = 128, message = "Refresh token không hợp lệ")
    String refreshToken
) {
    @Override
    public String toString() {
        return "RefreshRequest[***]";
    }
}
