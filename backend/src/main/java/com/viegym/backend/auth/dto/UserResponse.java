package com.viegym.backend.auth.dto;

import com.viegym.backend.auth.entity.User;
import com.viegym.backend.auth.entity.UserRole;
import java.util.UUID;

/** Thông tin an toàn của tài khoản; không bao giờ trả entity hay password_hash. */
public record UserResponse(
    UUID id,
    String email,
    String fullName,
    UserRole role,
    String timezone,
    boolean hasHealthProfile
) {
    public static UserResponse from(User user) {
        // Bảng health_profiles có từ ngày 5; tới lúc đó user nào cũng chưa có hồ sơ.
        return new UserResponse(user.getId(), user.getEmail(), user.getFullName(), user.getRole(),
            user.getTimezone(), false);
    }
}
