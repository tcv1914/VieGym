package com.viegym.backend.auth.reset;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/** viegym.password-reset.* — BR-A06, docs/05 §2. */
@Validated
@ConfigurationProperties("viegym.password-reset")
public record PasswordResetProperties(
    @NotNull Duration codeTtl,
    @Positive int maxAttempts,
    @Positive int perEmailPerHour,
    @Positive int resetPerIp,
    @NotNull Duration resetIpWindow,
    @NotBlank String mailFrom
) {
}
