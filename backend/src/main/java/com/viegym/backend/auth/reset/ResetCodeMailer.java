package com.viegym.backend.auth.reset;

import java.time.Duration;

/** Kênh gửi mã (BR-A07). Tách interface để test thay bằng bản giả, không gửi SMTP. */
public interface ResetCodeMailer {
    void send(String to, String code, Duration ttl);
}
