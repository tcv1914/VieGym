package com.viegym.backend.common.exception;

import java.util.Map;
import org.springframework.http.HttpStatus;

/** Lỗi nghiệp vụ có mã ổn định cho app (docs/05-api-contract.md §1.1). */
public class ApiException extends RuntimeException {
    private final HttpStatus status;
    private final String code;
    private final Map<String, String> fieldErrors;
    /** Trường thêm ở cấp gốc của body lỗi, ví dụ {@code workoutLogId} (docs/05 §8). */
    private final Map<String, Object> details;

    public ApiException(HttpStatus status, String code, String message) {
        this(status, code, message, null, null);
    }

    public ApiException(HttpStatus status, String code, String message, Map<String, String> fieldErrors) {
        this(status, code, message, fieldErrors, null);
    }

    public ApiException(HttpStatus status, String code, String message, Map<String, String> fieldErrors,
                        Map<String, Object> details) {
        super(message);
        this.status = status;
        this.code = code;
        this.fieldErrors = fieldErrors;
        this.details = details;
    }

    public static ApiException validation(String field, String message) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Dữ liệu không hợp lệ",
            Map.of(field, message));
    }

    public HttpStatus getStatus() {
        return status;
    }

    public String getCode() {
        return code;
    }

    public Map<String, String> getFieldErrors() {
        return fieldErrors;
    }

    public Map<String, Object> getDetails() {
        return details;
    }
}
