package com.viegym.backend.admin;

import com.viegym.backend.admin.AdminDtos.AdminUserItem;
import com.viegym.backend.admin.AdminDtos.UserStatusRequest;
import com.viegym.backend.admin.audit.AdminAudit;
import com.viegym.backend.admin.audit.AuditLog.Action;
import com.viegym.backend.admin.audit.AuditLog.EntityType;
import com.viegym.backend.auth.SessionService;
import com.viegym.backend.auth.entity.User;
import com.viegym.backend.auth.entity.UserRole;
import com.viegym.backend.auth.entity.UserStatus;
import com.viegym.backend.auth.repository.UserRepository;
import com.viegym.backend.common.exception.ApiException;
import com.viegym.backend.common.web.PageResponse;
import com.viegym.backend.exercise.SearchText;
import jakarta.persistence.criteria.Predicate;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Admin khóa/mở tài khoản (docs/31 §4, BR-G08). Chỉ khóa USER; không tự khóa; không đọc dữ liệu
 * nghiệp vụ của user (hồ sơ, thực đơn, nhật ký, chat).
 */
@Service
public class AdminUserService {
    private static final Logger log = LoggerFactory.getLogger(AdminUserService.class);
    private static final Sort ORDER = Sort.by(Sort.Order.desc("createdAt"), Sort.Order.asc("id"));

    private final UserRepository userRepository;
    private final SessionService sessionService;
    private final AdminAudit audit;
    private final Clock clock;

    public AdminUserService(UserRepository userRepository, SessionService sessionService, AdminAudit audit,
                            Clock clock) {
        this.userRepository = userRepository;
        this.sessionService = sessionService;
        this.audit = audit;
        this.clock = clock;
    }

    /** Tìm theo email hoặc họ tên (không phân biệt hoa thường, chuỗi con). */
    @Transactional(readOnly = true)
    public PageResponse<AdminUserItem> search(String keyword, UserStatus status, int page, int size) {
        AdminSupport.checkPage(page, size);
        String trimmed = keyword == null ? "" : keyword.strip().toLowerCase(Locale.ROOT);
        if (trimmed.length() > AdminSupport.MAX_KEYWORD_LENGTH) {
            throw ApiException.validation("keyword", "Từ khóa tối đa " + AdminSupport.MAX_KEYWORD_LENGTH + " ký tự");
        }
        Specification<User> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (!trimmed.isEmpty()) {
                String pattern = "%" + SearchText.escapeLike(trimmed) + "%";
                predicates.add(cb.or(
                    cb.like(root.get("email"), pattern, SearchText.LIKE_ESCAPE),
                    cb.like(cb.lower(root.get("fullName")), pattern, SearchText.LIKE_ESCAPE)));
            }
            if (status != null) {
                predicates.add(cb.equal(root.get("status"), status));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
        return PageResponse.of(userRepository.findAll(spec, PageRequest.of(page, size, ORDER)), AdminUserService::toItem);
    }

    /**
     * Khóa: đổi trạng thái + thu hồi mọi phiên/refresh token + audit trong một giao dịch, nên access
     * token cũ bị từ chối ngay ở request kế tiếp. Mở khóa không phục hồi phiên cũ. Đặt lại đúng trạng
     * thái hiện có là no-op (200, không audit).
     */
    @Transactional
    public AdminUserItem setStatus(UUID actorId, UUID userId, UserStatusRequest request) {
        if (actorId.equals(userId)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, "CANNOT_CHANGE_OWN_STATUS",
                "Không thể khóa hoặc mở tài khoản đang đăng nhập");
        }
        User user = userRepository.findForUpdate(userId)
            .orElseThrow(() -> AdminSupport.notFound("Tài khoản không tồn tại"));
        if (user.getRole() != UserRole.USER) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, "ADMIN_ACCOUNT_PROTECTED",
                "Không khóa/mở tài khoản quản trị trong MVP");
        }
        boolean lock = request.status() == UserStatus.LOCKED;
        if (lock && request.reason() == null) {
            throw ApiException.validation("reason", "Vui lòng nhập lý do khóa");
        }
        if (user.getStatus() == request.status()) {
            return toItem(user);
        }
        Instant now = clock.instant();
        user.setLocked(lock);
        if (lock) {
            sessionService.revokeAllOfUser(user.getId(), now);
        }
        userRepository.flush();
        audit.record(actorId, lock ? Action.LOCK : Action.UNLOCK, EntityType.USER, user.getId(), request.reason(),
            List.of("status"));
        log.info("Admin {} {} user {}", actorId, lock ? "khóa" : "mở khóa", user.getId());
        return toItem(user);
    }

    private static AdminUserItem toItem(User u) {
        return new AdminUserItem(u.getId(), u.getEmail(), u.getFullName(), u.getRole(), u.getStatus(),
            u.getCreatedAt());
    }
}
