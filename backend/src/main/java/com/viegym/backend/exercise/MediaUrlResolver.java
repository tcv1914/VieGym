package com.viegym.backend.exercise;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

/**
 * DB lưu key tương đối (exercises/0662-x.gif) để seed không gắn với một host; URL được ghép
 * lúc trả API. Không cấu hình base-url thì dùng host của chính request, nên điện thoại đi qua
 * adb reverse nhận đúng địa chỉ nó đang gọi.
 */
@Component
public class MediaUrlResolver {
    private final String baseUrl;

    public MediaUrlResolver(@Value("${viegym.media.base-url:}") String baseUrl) {
        this.baseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
    }

    public String resolve(String stored) {
        if (stored == null || stored.isBlank()) {
            return null;
        }
        if (stored.startsWith("https://") || stored.startsWith("http://")) {
            return stored;
        }
        String base = baseUrl.isEmpty()
            ? ServletUriComponentsBuilder.fromCurrentContextPath().toUriString()
            : baseUrl;
        return base + "/media/" + stored;
    }
}
