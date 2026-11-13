package com.viegym.backend.auth.reset;

import com.viegym.backend.auth.SessionService;
import com.viegym.backend.auth.entity.User;
import com.viegym.backend.auth.repository.UserRepository;
import com.viegym.backend.common.exception.ApiException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * UC11 — quên mật khẩu bằng mã 6 chữ số gửi qua email (BR-A06, BR-A07; docs/29 §2).
 *
 * <p>Mọi thao tác ghi khóa dòng {@code users} của chủ tài khoản trước, nên: hai yêu cầu mã đồng thời
 * không để lại hai mã còn hiệu lực, và hai lần đặt lại đồng thời cùng mã chỉ một lần thành công.
 */
@Service
@EnableConfigurationProperties(PasswordResetProperties.class)
public class PasswordResetService {
    private static final Logger log = LoggerFactory.getLogger(PasswordResetService.class);
    private static final int BCRYPT_MAX_BYTES = 72;
    private static final Duration EMAIL_WINDOW = Duration.ofHours(1);

    private final UserRepository userRepository;
    private final PasswordResetTokenRepository tokenRepository;
    private final SessionService sessionService;
    private final PasswordEncoder passwordEncoder;
    private final ApplicationEventPublisher events;
    private final PasswordResetProperties properties;
    private final Clock clock;
    private final IpRateLimiter resetLimiter;
    // Chặn một IP spam yêu cầu mã cho nhiều email khác nhau; vượt thì vẫn 204, chỉ không gửi.
    private final IpRateLimiter forgotLimiter;
    private final SecureRandom random = new SecureRandom();

    public PasswordResetService(UserRepository userRepository, PasswordResetTokenRepository tokenRepository,
                                SessionService sessionService, PasswordEncoder passwordEncoder,
                                ApplicationEventPublisher events, PasswordResetProperties properties, Clock clock) {
        this.userRepository = userRepository;
        this.tokenRepository = tokenRepository;
        this.sessionService = sessionService;
        this.passwordEncoder = passwordEncoder;
        this.events = events;
        this.properties = properties;
        this.clock = clock;
        this.resetLimiter = new IpRateLimiter(properties.resetPerIp(), properties.resetIpWindow(), clock);
        this.forgotLimiter = new IpRateLimiter(properties.resetPerIp(), properties.resetIpWindow(), clock);
    }

    /** Luôn kết thúc bình thường (controller trả 204): không lộ email có tồn tại hay không. */
    @Transactional
    public void requestCode(String email, String clientIp) {
        if (forgotLimiter.tryAcquire(clientIp) > 0) {
            log.info("Bỏ qua yêu cầu mã đặt lại: IP vượt giới hạn");
            return;
        }
        User user = userRepository.findByEmail(email).orElse(null);
        if (user == null) {
            return;
        }
        userRepository.findForUpdate(user.getId());
        Instant now = clock.instant();
        if (tokenRepository.countByUserIdAndCreatedAtAfter(user.getId(), now.minus(EMAIL_WINDOW))
            >= properties.perEmailPerHour()) {
            log.info("Bỏ qua yêu cầu mã đặt lại cho user {}: vượt {}/giờ", user.getId(),
                properties.perEmailPerHour());
            return;
        }
        // Tạo mã mới vô hiệu mã cũ (BR-A06).
        tokenRepository.invalidateAllOfUser(user.getId(), now);
        String code = "%06d".formatted(random.nextInt(1_000_000));
        tokenRepository.save(new PasswordResetToken(user.getId(), hash(user.getId(), code), now,
            now.plus(properties.codeTtl())));
        events.publishEvent(new ResetCodeRequested(user.getId(), user.getEmail(), code, properties.codeTtl()));
    }

    /**
     * Không tự đăng nhập. Sai mã vẫn commit số lần sai (noRollbackFor). Không phân biệt sai mã, hết
     * hạn, đã dùng, đã bị vô hiệu hay email không tồn tại: cùng 400 INVALID_RESET_CODE.
     */
    @Transactional(noRollbackFor = ApiException.class)
    public void reset(String email, String code, String newPassword, String clientIp) {
        long wait = resetLimiter.tryAcquire(clientIp);
        if (wait > 0) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED",
                "Bạn thử quá nhiều lần, vui lòng chờ rồi thử lại", null, Map.of("retryAfterSeconds", wait));
        }
        if (newPassword.getBytes(StandardCharsets.UTF_8).length > BCRYPT_MAX_BYTES) {
            throw ApiException.validation("newPassword", "Mật khẩu quá dài (tối đa 72 byte)");
        }
        User user = userRepository.findByEmail(email)
            .flatMap(found -> userRepository.findForUpdate(found.getId()))
            .orElseThrow(PasswordResetService::invalidCode);
        Instant now = clock.instant();
        PasswordResetToken token = tokenRepository
            .findFirstByUserIdAndUsedAtIsNullAndExpiresAtAfterOrderByCreatedAtDesc(user.getId(), now)
            .orElseThrow(PasswordResetService::invalidCode);
        if (!MessageDigest.isEqual(token.getTokenHash().getBytes(StandardCharsets.US_ASCII),
            hash(user.getId(), code).getBytes(StandardCharsets.US_ASCII))) {
            token.recordFailure(properties.maxAttempts(), now);
            throw invalidCode();
        }
        token.markUsed(now);
        user.changePassword(passwordEncoder.encode(newPassword));
        // Flush trước: các câu UPDATE hàng loạt dưới đây xóa persistence context (clearAutomatically).
        userRepository.flush();
        tokenRepository.invalidateAllOfUser(user.getId(), now);
        // Đổi mật khẩu = mọi thiết bị phải đăng nhập lại; access token cũ bị từ chối ngay vì phiên đã thu hồi.
        sessionService.revokeAllOfUser(user.getId(), now);
        log.info("User {} đã đặt lại mật khẩu", user.getId());
    }

    /** Gắn userId để cùng một mã của hai user khác nhau ra hash khác nhau. */
    static String hash(UUID userId, String code) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                .digest((userId + ":" + code).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("JVM thiếu SHA-256", ex);
        }
    }

    private static ApiException invalidCode() {
        return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_RESET_CODE",
            "Mã không đúng hoặc đã hết hạn. Hãy kiểm tra lại hoặc yêu cầu mã mới.");
    }
}
