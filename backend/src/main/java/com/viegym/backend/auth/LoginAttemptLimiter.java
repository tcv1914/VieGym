package com.viegym.backend.auth;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Locale;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * BR-A09: đếm lần đăng nhập SAI trong cửa sổ trượt, theo email và theo IP. Đủ ngưỡng thì chặn mọi lần thử
 * (kể cả đúng mật khẩu) tới khi lần sai cũ nhất ra khỏi cửa sổ. Email không tồn tại cũng được đếm như email
 * có thật, nên giới hạn không giúp dò tài khoản. Lưu trong bộ nhớ: đủ cho một instance (MVP), mất khi restart.
 */
@Component
@EnableConfigurationProperties(LoginLimitProperties.class)
public class LoginAttemptLimiter {
    private final LoginLimitProperties properties;
    private final Clock clock;
    private final ConcurrentHashMap<String, Deque<Instant>> failures = new ConcurrentHashMap<>();

    public LoginAttemptLimiter(LoginLimitProperties properties, Clock clock) {
        this.properties = properties;
        this.clock = clock;
    }

    /** 0 = được thử; > 0 = số giây phải chờ. */
    public long retryAfterSeconds(String email, String ip) {
        Instant now = clock.instant();
        return Math.max(wait(emailKey(email), properties.maxFailuresPerEmail(), now),
            wait(ipKey(ip), properties.maxFailuresPerIp(), now));
    }

    public void recordFailure(String email, String ip) {
        Instant now = clock.instant();
        for (String key : new String[] {emailKey(email), ipKey(ip)}) {
            failures.compute(key, (k, d) -> {
                Deque<Instant> deque = prune(d == null ? new ArrayDeque<>() : d, now);
                deque.addLast(now);
                return deque;
            });
        }
    }

    /** Đăng nhập đúng xóa lịch sử sai của email (IP giữ nguyên: một IP có thể dò nhiều tài khoản). */
    public void recordSuccess(String email) {
        failures.remove(emailKey(email));
    }

    private long wait(String key, int max, Instant now) {
        long[] seconds = {0};
        failures.computeIfPresent(key, (k, d) -> {
            prune(d, now);
            if (d.size() >= max) {
                // Chờ tới khi lần sai thứ (size − max + 1) tính từ cũ nhất rời cửa sổ.
                Instant releaseAt = d.stream().skip(d.size() - max).findFirst().orElseThrow()
                    .plus(properties.window());
                seconds[0] = Math.max(1, Duration.between(now, releaseAt).toSeconds() + 1);
            }
            return d.isEmpty() ? null : d;
        });
        return seconds[0];
    }

    private Deque<Instant> prune(Deque<Instant> d, Instant now) {
        Instant windowStart = now.minus(properties.window());
        while (!d.isEmpty() && !d.peekFirst().isAfter(windowStart)) {
            d.pollFirst();
        }
        return d;
    }

    private static String emailKey(String email) {
        return "email:" + email.trim().toLowerCase(Locale.ROOT);
    }

    private static String ipKey(String ip) {
        return "ip:" + ip;
    }
}
