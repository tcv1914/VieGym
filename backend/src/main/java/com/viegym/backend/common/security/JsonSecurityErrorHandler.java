package com.viegym.backend.common.security;

import com.viegym.backend.common.exception.ApiError;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.LockedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;

/** Lỗi 401/403 ở tầng filter trả cùng định dạng JSON với controller, rồi dừng filter chain. */
@Component
public class JsonSecurityErrorHandler implements AuthenticationEntryPoint, AccessDeniedHandler {
    private final ObjectMapper objectMapper;

    public JsonSecurityErrorHandler(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException ex) throws IOException {
        if (ex instanceof LockedException) {
            write(request, response, HttpServletResponse.SC_FORBIDDEN, "ACCOUNT_LOCKED", "Tài khoản đã bị khóa");
            return;
        }
        response.setHeader(HttpHeaders.WWW_AUTHENTICATE, "Bearer");
        write(request, response, HttpServletResponse.SC_UNAUTHORIZED, "UNAUTHORIZED",
            "Phiên đăng nhập không hợp lệ hoặc đã hết hạn");
    }

    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response,
                       AccessDeniedException ex) throws IOException {
        write(request, response, HttpServletResponse.SC_FORBIDDEN, "FORBIDDEN", "Bạn không có quyền thực hiện chức năng này");
    }

    private void write(HttpServletRequest request, HttpServletResponse response, int status,
                       String code, String message) throws IOException {
        response.setStatus(status);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        objectMapper.writeValue(response.getOutputStream(), ApiError.of(code, message, request.getRequestURI()));
    }
}
