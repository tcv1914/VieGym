package com.viegym.backend.auth.reset;

import java.time.Duration;
import java.util.UUID;

/** Phát trong giao dịch tạo mã; email chỉ gửi sau khi mã đã commit. */
record ResetCodeRequested(UUID userId, String email, String code, Duration ttl) {
    // Không để mã/email lọt vào log nếu sự kiện bị in ra.
    @Override
    public String toString() {
        return "ResetCodeRequested[userId=" + userId + "]";
    }
}
