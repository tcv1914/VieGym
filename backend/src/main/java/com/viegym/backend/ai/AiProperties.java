package com.viegym.backend.ai;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.net.URI;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * viegym.ai.* (docs/27 §5). {@code internalKey} chỉ đặt qua biến môi trường AI_INTERNAL_KEY,
 * khác hoàn toàn khóa JWT; trống → mọi câu hỏi FAILED / AI_UPSTREAM_ERROR (không gọi ai-service).
 */
@Validated
@ConfigurationProperties("viegym.ai")
public record AiProperties(
    /** false → 503 AI_DISABLED, không lưu câu hỏi, không gọi AI. */
    boolean enabled,
    @NotNull URI serviceUrl,
    String internalKey,
    @NotNull Duration connectTimeout,
    /** BR-AI04: timeout gọi AI 30 giây (tổng thời gian chờ ai-service). */
    @NotNull Duration timeout,
    @Min(1) int perMinute,
    @Min(1) int perDay,
    /** BR-AI03: tối đa 10 tin nhắn gần nhất của hội thoại. */
    @Min(0) int historySize
) {
}
