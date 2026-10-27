package com.viegym.backend.common.exception;

import java.util.Map;
import org.springframework.http.HttpStatus;

/** Lỗi nghiệp vụ có mã ổn định cho app (docs/05-api-contract.md §1.1). */
public class ApiException extends RuntimeException {
    private final HttpStatus status;
    private final String code;
    private final Map<String, String> fieldErrors;

    public ApiException(HttpStatus status, String code, String message) {
        this(status, code, message, null);
    }

    public ApiException(HttpStatus status, String code, String message, Map<String, String> fieldErrors) {
        super(message);
        this.status = status;
        this.code = code;
        this.fieldErrors = fieldErrors;
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
}
