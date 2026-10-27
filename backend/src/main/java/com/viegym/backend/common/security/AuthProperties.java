package com.viegym.backend.common.security;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.core.io.Resource;
import org.springframework.validation.annotation.Validated;

/** Cấu hình phiên: viegym.auth.* trong application.yaml. */
@Validated
@ConfigurationProperties("viegym.auth")
public record AuthProperties(
    @NotBlank String issuer,
    @NotBlank String audience,
    @NotNull Duration accessTokenTtl,
    @NotNull Duration refreshTokenTtl,
    @NotNull Duration sessionTtl,
    // PEM nằm ngoài Git và ổn định qua restart; sinh mới mỗi lần chạy sẽ vô hiệu mọi JWT cũ.
    @NotNull Resource privateKeyLocation,
    @NotNull Resource publicKeyLocation
) {
}
