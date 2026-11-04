package com.viegym.backend.common.exception;

import com.fasterxml.jackson.annotation.JsonAnyGetter;
import com.fasterxml.jackson.annotation.JsonInclude;
import java.time.Instant;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record ApiError(
    String code,
    String message,
    Map<String, String> fieldErrors,
    Instant timestamp,
    String path,
    /** Trải phẳng vào body, ví dụ {@code "workoutLogId": "uuid"}. */
    @JsonAnyGetter
    Map<String, Object> details
) {
    public ApiError(String code, String message, Map<String, String> fieldErrors, Instant timestamp, String path) {
        this(code, message, fieldErrors, timestamp, path, null);
    }

    public static ApiError of(String code, String message, String path) {
        return new ApiError(code, message, null, Instant.now(), path);
    }
}
