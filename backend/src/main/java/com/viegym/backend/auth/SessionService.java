package com.viegym.backend.auth;

import com.viegym.backend.auth.dto.TokenResponse;
import com.viegym.backend.auth.dto.UserResponse;
import com.viegym.backend.auth.entity.AuthSession;
import com.viegym.backend.auth.entity.RefreshToken;
import com.viegym.backend.auth.entity.User;
import com.viegym.backend.auth.repository.AuthSessionRepository;
import com.viegym.backend.auth.repository.RefreshTokenRepository;
import com.viegym.backend.common.exception.ApiException;
import com.viegym.backend.common.security.AuthProperties;
import com.viegym.backend.common.security.AuthenticatedUser;
import java.time.Clock;
import java.time.Instant;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.LockedException;
import org.springframework.security.oauth2.server.resource.InvalidBearerTokenException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Vòng đời phiên: tạo khi login, xoay refresh token, thu hồi, kiểm tra ở mỗi request. */
@Service
public class SessionService {
    private final AuthSessionRepository sessionRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final TokenService tokenService;
    private final AuthProperties properties;
    private final Clock clock;

    public SessionService(AuthSessionRepository sessionRepository, RefreshTokenRepository refreshTokenRepository,
                          TokenService tokenService, AuthProperties properties, Clock clock) {
        this.sessionRepository = sessionRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.tokenService = tokenService;
        this.properties = properties;
        this.clock = clock;
    }

    @Transactional
    public TokenResponse start(User user) {
        Instant now = clock.instant();
        AuthSession session = sessionRepository.save(new AuthSession(user, now, now.plus(properties.sessionTtl())));
        return issueTokens(session, user, now);
    }

    @Transactional(noRollbackFor = RefreshTokenReusedException.class)
    public TokenResponse refresh(String rawToken) {
        Instant now = clock.instant();
        RefreshToken token = refreshTokenRepository.findForUpdate(TokenService.hashRefreshToken(rawToken))
            .orElseThrow(SessionService::invalidRefreshToken);
        AuthSession session = token.getSession();
        User user = session.getUser();

        // BR-A04: token đã đổi mà bị gửi lại → có thể đã lộ, thu hồi mọi phiên của user.
        if (token.isConsumed() && session.getRevokedAt() == null) {
            revokeAllOfUser(user.getId(), now);
            throw new RefreshTokenReusedException();
        }
        if (!token.isUsable(now) || !session.isActive(now)) {
            throw invalidRefreshToken();
        }
        if (user.isLocked()) {
            throw accountLocked();
        }
        token.consume(now);
        return issueTokens(session, user, now);
    }

    /** Idempotent: token lạ hoặc phiên đã thu hồi vẫn coi như thành công. */
    @Transactional
    public void logout(String rawToken) {
        Instant now = clock.instant();
        // Nhận cả token đã consumed: app có thể giữ token trước khi kịp lưu token mới.
        refreshTokenRepository.findByTokenHash(TokenService.hashRefreshToken(rawToken))
            .ifPresent(token -> revokeSession(token.getSession().getId(), now));
    }

    /** Gọi ở mọi request riêng tư sau khi JWT đã qua kiểm tra chữ ký/exp/iss/aud. */
    @Transactional(readOnly = true)
    public AuthenticatedUser authenticate(UUID userId, UUID sessionId) {
        Instant now = clock.instant();
        AuthSession session = sessionRepository.findWithUserById(sessionId)
            .filter(s -> s.getUser().getId().equals(userId) && s.isActive(now))
            .orElseThrow(() -> new InvalidBearerTokenException("Phiên đăng nhập không còn hiệu lực"));
        User user = session.getUser();
        if (user.isLocked()) {
            throw new LockedException("Tài khoản đã bị khóa");
        }
        return new AuthenticatedUser(user.getId(), session.getId(), user.getRole());
    }

    @Transactional
    public void revokeAllOfUser(UUID userId, Instant now) {
        sessionRepository.revokeAllOfUser(userId, now);
        refreshTokenRepository.revokeAllOfUser(userId, now);
    }

    private void revokeSession(UUID sessionId, Instant now) {
        sessionRepository.revoke(sessionId, now);
        refreshTokenRepository.revokeAllOfSession(sessionId, now);
    }

    private TokenResponse issueTokens(AuthSession session, User user, Instant now) {
        String rawRefresh = tokenService.newRefreshToken();
        // Refresh mới không vượt hạn tuyệt đối của phiên.
        Instant refreshExpiresAt = min(now.plus(properties.refreshTokenTtl()), session.getExpiresAt());
        refreshTokenRepository.save(
            new RefreshToken(session, TokenService.hashRefreshToken(rawRefresh), now, refreshExpiresAt));
        String accessToken = tokenService.issueAccessToken(user.getId(), session.getId(), now);
        return new TokenResponse("Bearer", accessToken, tokenService.accessTokenTtlSeconds(), rawRefresh,
            UserResponse.from(user));
    }

    private static Instant min(Instant a, Instant b) {
        return a.isBefore(b) ? a : b;
    }

    private static ApiException invalidRefreshToken() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH_TOKEN",
            "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại");
    }

    static ApiException accountLocked() {
        return new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_LOCKED", "Tài khoản đã bị khóa");
    }
}
