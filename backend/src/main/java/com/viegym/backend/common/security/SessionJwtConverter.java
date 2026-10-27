package com.viegym.backend.common.security;

import com.viegym.backend.auth.SessionService;
import java.util.UUID;
import org.springframework.core.convert.converter.Converter;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.InvalidBearerTokenException;
import org.springframework.stereotype.Component;

/**
 * Chạy sau khi Resource Server đã xác minh chữ ký, exp, iss, aud. Ở đây kiểm tra thêm
 * user + phiên trong database cho MỌI request riêng tư, nên logout/khóa tài khoản có
 * hiệu lực ngay cả khi access token chưa hết hạn.
 */
@Component
public class SessionJwtConverter implements Converter<Jwt, AbstractAuthenticationToken> {
    private final SessionService sessionService;

    public SessionJwtConverter(SessionService sessionService) {
        this.sessionService = sessionService;
    }

    @Override
    public AbstractAuthenticationToken convert(Jwt jwt) {
        UUID userId = parseUuid(jwt.getSubject());
        UUID sessionId = parseUuid(jwt.getClaimAsString(JwtConfig.SESSION_CLAIM));
        AuthenticatedUser principal = sessionService.authenticate(userId, sessionId);
        return new SessionAuthentication(principal, jwt);
    }

    private static UUID parseUuid(String value) {
        try {
            return UUID.fromString(value);
        } catch (IllegalArgumentException | NullPointerException ex) {
            throw new InvalidBearerTokenException("Access token không hợp lệ");
        }
    }
}
