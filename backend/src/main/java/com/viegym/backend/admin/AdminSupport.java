package com.viegym.backend.admin;

import com.viegym.backend.common.exception.ApiException;
import com.viegym.backend.exercise.SearchText;
import java.security.SecureRandom;
import java.util.HexFormat;
import java.util.Map;
import org.springframework.http.HttpStatus;

/** Quy tắc chung của API admin (docs/31 §3). */
final class AdminSupport {
    static final int MAX_PAGE_SIZE = 100;
    static final int MAX_KEYWORD_LENGTH = 100;
    private static final SecureRandom RANDOM = new SecureRandom();

    private AdminSupport() {
    }

    static void checkPage(int page, int size) {
        if (page < 0) {
            throw ApiException.validation("page", "Số trang phải từ 0");
        }
        if (size < 1 || size > MAX_PAGE_SIZE) {
            throw ApiException.validation("size", "Kích thước trang phải từ 1 đến " + MAX_PAGE_SIZE);
        }
    }

    static String normalizedKeyword(String keyword) {
        String normalized = SearchText.normalize(keyword);
        if (normalized.length() > MAX_KEYWORD_LENGTH) {
            throw ApiException.validation("keyword", "Từ khóa tối đa " + MAX_KEYWORD_LENGTH + " ký tự");
        }
        return normalized;
    }

    /** POST không có revision; PUT phải có. */
    static void checkRevisionPresence(Integer revision, boolean creating) {
        if (creating && revision != null) {
            throw ApiException.validation("revision", "Chỉ gửi revision khi sửa");
        }
        if (!creating && revision == null) {
            throw ApiException.validation("revision", "Thiếu revision của bản đang sửa");
        }
    }

    /** 409 kèm revision hiện tại để frontend báo "đã có người sửa, tải lại". */
    static ApiException revisionConflict(int currentRevision) {
        return new ApiException(HttpStatus.CONFLICT, "VERSION_CONFLICT",
            "Dữ liệu đã được sửa ở nơi khác. Hãy tải lại rồi sửa tiếp.", null,
            Map.of("currentRevision", currentRevision));
    }

    static ApiException notFound(String message) {
        return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", message);
    }

    /** Mã cố định cho bản ghi admin tạo; không đổi khi sửa tên. */
    static String newCode(String prefix) {
        byte[] bytes = new byte[5];
        RANDOM.nextBytes(bytes);
        return prefix + HexFormat.of().formatHex(bytes);
    }
}
