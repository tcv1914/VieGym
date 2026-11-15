package com.viegym.backend.auth;

import com.viegym.backend.auth.dto.LoginRequest;
import com.viegym.backend.auth.dto.RegisterRequest;
import com.viegym.backend.auth.dto.TokenResponse;
import com.viegym.backend.auth.dto.UserResponse;
import com.viegym.backend.auth.entity.User;
import com.viegym.backend.auth.repository.UserRepository;
import com.viegym.backend.common.exception.ApiException;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.util.Map;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class AuthService {
    // BCrypt chỉ dùng 72 byte đầu; số ký tự tiếng Việt và số byte UTF-8 khác nhau.
    private static final int BCRYPT_MAX_BYTES = 72;

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final SessionService sessionService;
    private final Clock clock;
    private final LoginAttemptLimiter loginLimiter;
    // So khớp với hash giả khi email không tồn tại để thời gian phản hồi gần như nhau.
    private final String dummyPasswordHash;

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder,
                       SessionService sessionService, Clock clock, LoginAttemptLimiter loginLimiter) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.sessionService = sessionService;
        this.clock = clock;
        this.loginLimiter = loginLimiter;
        this.dummyPasswordHash = passwordEncoder.encode("viegym-dummy-password-1");
    }

    // Không mở transaction bao quanh: saveAndFlush tự có, và lỗi UNIQUE bắt được ở đây.
    public UserResponse register(RegisterRequest request) {
        if (utf8Length(request.password()) > BCRYPT_MAX_BYTES) {
            throw ApiException.validation("password", "Mật khẩu quá dài (tối đa 72 byte)");
        }
        // Kiểm tra sớm để báo lỗi rõ; UNIQUE ở database mới là chốt chặn khi đăng ký đồng thời.
        if (userRepository.existsByEmail(request.email())) {
            throw emailAlreadyExists();
        }
        var user = new User(request.email(), passwordEncoder.encode(request.password()), request.fullName(),
            clock.instant());
        try {
            return UserResponse.from(userRepository.saveAndFlush(user), false);
        } catch (DataIntegrityViolationException ex) {
            throw emailAlreadyExists();
        }
    }

    public TokenResponse login(LoginRequest request, String clientIp) {
        // BR-A09: chặn trước khi so mật khẩu, nên đoán đúng trong lúc bị chặn cũng không lọt.
        long wait = loginLimiter.retryAfterSeconds(request.email(), clientIp);
        if (wait > 0) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED",
                "Bạn đăng nhập sai quá nhiều lần, vui lòng chờ khoảng " + Math.max(1, (wait + 59) / 60)
                    + " phút rồi thử lại", null, Map.of("retryAfterSeconds", wait));
        }
        User user = userRepository.findByEmail(request.email()).orElse(null);
        boolean passwordMatches = utf8Length(request.password()) <= BCRYPT_MAX_BYTES
            && passwordEncoder.matches(request.password(), user != null ? user.getPasswordHash() : dummyPasswordHash);
        // BR-A05: không nói rõ sai email hay sai mật khẩu.
        if (user == null || !passwordMatches) {
            loginLimiter.recordFailure(request.email(), clientIp);
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "Email hoặc mật khẩu không đúng");
        }
        // Chỉ báo khóa khi đã đúng mật khẩu, nên không lộ trạng thái cho người đoán mò.
        if (user.isLocked()) {
            throw SessionService.accountLocked();
        }
        loginLimiter.recordSuccess(request.email());
        return sessionService.start(user);
    }

    private static int utf8Length(String value) {
        return value.getBytes(StandardCharsets.UTF_8).length;
    }

    private static ApiException emailAlreadyExists() {
        return new ApiException(HttpStatus.CONFLICT, "EMAIL_ALREADY_EXISTS", "Email đã được đăng ký");
    }
}
