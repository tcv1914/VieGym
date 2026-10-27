package com.viegym.backend.auth;

import com.viegym.backend.common.exception.ApiException;
import org.springframework.http.HttpStatus;

/**
 * Refresh token đã đổi rồi lại được gửi lên (BR-A04). Client chỉ thấy 401 như token sai,
 * nhưng transaction vẫn commit việc thu hồi phiên.
 */
class RefreshTokenReusedException extends ApiException {
    RefreshTokenReusedException() {
        super(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH_TOKEN", "Phiên đăng nhập không hợp lệ, vui lòng đăng nhập lại");
    }
}
