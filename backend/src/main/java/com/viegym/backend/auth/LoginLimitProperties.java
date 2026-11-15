package com.viegym.backend.auth;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/** BR-A09 (ngày 17): viegym.login-limit.* trong application.yaml. */
@Validated
@ConfigurationProperties("viegym.login-limit")
public record LoginLimitProperties(
    @Min(1) int maxFailuresPerEmail,
    @Min(1) int maxFailuresPerIp,
    @NotNull Duration window
) {
}
