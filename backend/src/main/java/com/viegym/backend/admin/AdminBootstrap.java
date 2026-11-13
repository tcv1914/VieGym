package com.viegym.backend.admin;

import com.viegym.backend.auth.dto.RegisterRequest;
import com.viegym.backend.auth.entity.User;
import com.viegym.backend.auth.entity.UserRole;
import com.viegym.backend.auth.repository.UserRepository;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validator;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.util.Set;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Tạo tài khoản ADMIN từ biến môi trường của máy chủ (docs/31 §2) — không có đăng ký ADMIN
 * công khai, không có API nâng vai trò. Chỉ tạo khi email chưa tồn tại; email đã là USER thì
 * KHÔNG tự nâng quyền (tránh cấu hình nhầm biến tài khoản người dùng thành admin). Không log mật khẩu.
 */
@Component
public class AdminBootstrap implements ApplicationRunner {
    private static final Logger log = LoggerFactory.getLogger(AdminBootstrap.class);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final Validator validator;
    private final Clock clock;
    private final String email;
    private final String password;
    private final String fullName;

    public AdminBootstrap(UserRepository userRepository, PasswordEncoder passwordEncoder, Validator validator,
                          Clock clock,
                          @Value("${viegym.admin.bootstrap-email:}") String email,
                          @Value("${viegym.admin.bootstrap-password:}") String password,
                          @Value("${viegym.admin.bootstrap-full-name:Quản trị viên}") String fullName) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.validator = validator;
        this.clock = clock;
        this.email = email;
        this.password = password;
        this.fullName = fullName;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (email.isBlank()) {
            return;
        }
        // Cùng quy tắc email/mật khẩu/họ tên với đăng ký (BR-A01, BR-A02).
        RegisterRequest request = new RegisterRequest(email, password, fullName);
        Set<ConstraintViolation<RegisterRequest>> violations = validator.validate(request);
        if (!violations.isEmpty() || password.getBytes(StandardCharsets.UTF_8).length > 72) {
            String fields = violations.stream().map(v -> v.getPropertyPath().toString())
                .collect(Collectors.joining(","));
            log.warn("Bỏ qua tạo admin: cấu hình ADMIN_EMAIL/ADMIN_PASSWORD không hợp lệ ({})",
                fields.isEmpty() ? "password" : fields);
            return;
        }
        var existing = userRepository.findByEmail(request.email());
        if (existing.isPresent()) {
            if (existing.get().getRole() != UserRole.ADMIN) {
                log.warn("Bỏ qua tạo admin: email đã thuộc một tài khoản USER, không tự nâng quyền");
            }
            return;
        }
        User admin = userRepository.save(User.bootstrapAdmin(request.email(),
            passwordEncoder.encode(request.password()), request.fullName(), clock.instant()));
        log.info("Đã tạo tài khoản admin {}", admin.getId());
    }
}
