package com.viegym.backend.common.security;

import com.viegym.backend.auth.entity.UserRole;
import java.util.UUID;

/**
 * Người dùng của request hiện tại, đã xác minh JWT và phiên trong database.
 * Controller nhận qua {@code @AuthenticationPrincipal}; không đọc userId từ request (BR-G01).
 */
public record AuthenticatedUser(UUID userId, UUID sessionId, UserRole role) {
}
