package com.viegym.backend.common.exception;

import jakarta.servlet.http.HttpServletRequest;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import org.apache.tomcat.util.http.InvalidParameterException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.exc.MismatchedInputException;

@RestControllerAdvice
public class GlobalExceptionHandler {
    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(ApiException.class)
    ResponseEntity<ApiError> handleApi(ApiException ex, HttpServletRequest request) {
        var body = new ApiError(ex.getCode(), ex.getMessage(), ex.getFieldErrors(), Instant.now(),
            request.getRequestURI(), ex.getDetails());
        var response = ResponseEntity.status(ex.getStatus());
        // 429 RATE_LIMITED (docs/05 §12): báo cả qua header chuẩn Retry-After.
        if (ex.getDetails() != null && ex.getDetails().get("retryAfterSeconds") instanceof Number seconds) {
            response.header(HttpHeaders.RETRY_AFTER, String.valueOf(seconds.longValue()));
        }
        return response.body(body);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex, HttpServletRequest request) {
        Map<String, String> fieldErrors = new LinkedHashMap<>();
        // Mỗi trường một thông báo là đủ cho form trên app.
        ex.getBindingResult().getFieldErrors()
            .forEach(error -> fieldErrors.putIfAbsent(error.getField(), error.getDefaultMessage()));
        var body = new ApiError("VALIDATION_ERROR", "Dữ liệu không hợp lệ", fieldErrors, Instant.now(),
            request.getRequestURI());
        return ResponseEntity.badRequest().body(body);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<ApiError> handleMalformed(HttpMessageNotReadableException ex, HttpServletRequest request) {
        // JSON đúng cú pháp nhưng một trường sai kiểu (enum lạ, ngày sai định dạng): báo theo trường.
        if (ex.getCause() instanceof MismatchedInputException mismatch) {
            String field = mismatch.getPath().stream()
                .map(JacksonException.Reference::getPropertyName)
                .filter(Objects::nonNull)
                .reduce((first, second) -> second)
                .orElse(null);
            if (field != null) {
                var body = new ApiError("VALIDATION_ERROR", "Dữ liệu không hợp lệ",
                    Map.of(field, "Giá trị không hợp lệ"), Instant.now(), request.getRequestURI());
                return ResponseEntity.badRequest().body(body);
            }
        }
        return ResponseEntity.badRequest()
            .body(ApiError.of("MALFORMED_JSON", "Nội dung request không đúng định dạng JSON", request.getRequestURI()));
    }

    /** Query/path sai kiểu: enum lạ, UUID sai định dạng, page không phải số. */
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    ResponseEntity<ApiError> handleTypeMismatch(MethodArgumentTypeMismatchException ex, HttpServletRequest request) {
        var body = new ApiError("VALIDATION_ERROR", "Dữ liệu không hợp lệ",
            Map.of(ex.getName(), "Giá trị không hợp lệ"), Instant.now(), request.getRequestURI());
        return ResponseEntity.badRequest().body(body);
    }

    /** Query string không giải mã được UTF-8 (vd. %-encode theo bảng mã khác): lỗi của client. */
    @ExceptionHandler(InvalidParameterException.class)
    ResponseEntity<ApiError> handleBadEncoding(HttpServletRequest request) {
        return ResponseEntity.badRequest().body(ApiError.of("VALIDATION_ERROR",
            "Tham số không đúng mã hóa UTF-8", request.getRequestURI()));
    }

    @ExceptionHandler(NoResourceFoundException.class)
    ResponseEntity<ApiError> handleNotFound(HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
            .body(ApiError.of("NOT_FOUND", "Không tìm thấy", request.getRequestURI()));
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    ResponseEntity<ApiError> handleMethod(HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED)
            .body(ApiError.of("METHOD_NOT_ALLOWED", "Phương thức không được hỗ trợ", request.getRequestURI()));
    }

    // Không trả stacktrace hay thông điệp nội bộ cho client.
    @ExceptionHandler(Exception.class)
    ResponseEntity<ApiError> handleUnexpected(Exception ex, HttpServletRequest request) {
        log.error("Lỗi không xử lý tại {}", request.getRequestURI(), ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(ApiError.of("INTERNAL_ERROR", "Lỗi hệ thống, vui lòng thử lại sau", request.getRequestURI()));
    }
}
