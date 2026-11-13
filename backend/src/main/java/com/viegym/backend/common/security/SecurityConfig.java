package com.viegym.backend.common.security;

import jakarta.servlet.http.HttpServletRequest;
import java.time.Clock;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.factory.PasswordEncoderFactories;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.server.resource.web.BearerTokenResolver;
import org.springframework.security.oauth2.server.resource.web.DefaultBearerTokenResolver;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableConfigurationProperties(AuthProperties.class)
public class SecurityConfig {
    private static final String[] PUBLIC_AUTH_ENDPOINTS = {
        "/api/v1/auth/register",
        "/api/v1/auth/login",
        // refresh/logout xác minh refresh token trong body, không cần access token.
        "/api/v1/auth/refresh",
        "/api/v1/auth/logout",
        // Ngày 13: chưa đăng nhập được nên phải public; tự giới hạn tần suất (BR-A06).
        "/api/v1/auth/forgot-password",
        "/api/v1/auth/reset-password",
    };

    @Bean
    SecurityFilterChain apiSecurity(HttpSecurity http, SessionJwtConverter sessionJwtConverter,
                                    JsonSecurityErrorHandler errorHandler) throws Exception {
        http
            // API mobile chỉ dùng Bearer + JSON, không cookie, nên tắt CSRF. Đổi sang cookie phải bật lại.
            .csrf(AbstractHttpConfigurer::disable)
            .formLogin(AbstractHttpConfigurer::disable)
            .httpBasic(AbstractHttpConfigurer::disable)
            .logout(AbstractHttpConfigurer::disable)
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers(HttpMethod.GET, "/api/v1/system/health").permitAll()
                // Ảnh/GIF bài tập: Image.network không gửi Bearer; chỉ chứa media công khai.
                .requestMatchers(HttpMethod.GET, "/media/**").permitAll()
                .requestMatchers(HttpMethod.POST, PUBLIC_AUTH_ENDPOINTS).permitAll()
                .requestMatchers("/error").permitAll()
                .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                // Endpoint chưa khai báo vẫn phải đăng nhập.
                .anyRequest().authenticated())
            .oauth2ResourceServer(oauth2 -> oauth2
                .bearerTokenResolver(bearerTokenResolver())
                .jwt(jwt -> jwt.jwtAuthenticationConverter(sessionJwtConverter))
                .authenticationEntryPoint(errorHandler)
                .accessDeniedHandler(errorHandler))
            .exceptionHandling(ex -> ex
                .authenticationEntryPoint(errorHandler)
                .accessDeniedHandler(errorHandler));
        return http.build();
    }

    /**
     * Bỏ qua header Authorization ở endpoint công khai: app còn giữ access token cũ/hết hạn
     * vẫn phải login/refresh được thay vì bị 401.
     */
    private static BearerTokenResolver bearerTokenResolver() {
        var resolver = new DefaultBearerTokenResolver();
        return (HttpServletRequest request) -> isPublic(request) ? null : resolver.resolve(request);
    }

    private static boolean isPublic(HttpServletRequest request) {
        String path = request.getRequestURI().substring(request.getContextPath().length());
        return path.startsWith("/api/v1/auth/") || path.equals("/api/v1/system/health")
            || path.startsWith("/media/");
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        // Hash có tiền tố {bcrypt}; giữ nguyên để matches chọn đúng encoder.
        return PasswordEncoderFactories.createDelegatingPasswordEncoder();
    }

    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }
}
