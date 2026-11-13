package com.viegym.backend.auth.reset;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Cửa sổ trượt trong bộ nhớ, theo IP. Đủ cho một instance (MVP); mất khi restart. Nhiều instance
 * thì cần chuyển sang database/Redis.
 */
class IpRateLimiter {
    private final int maxRequests;
    private final Duration window;
    private final Clock clock;
    private final ConcurrentHashMap<String, Deque<Instant>> hits = new ConcurrentHashMap<>();

    IpRateLimiter(int maxRequests, Duration window, Clock clock) {
        this.maxRequests = maxRequests;
        this.window = window;
        this.clock = clock;
    }

    /** 0 = được phép (đã tính lượt này); > 0 = số giây phải chờ. */
    long tryAcquire(String key) {
        Instant now = clock.instant();
        Instant windowStart = now.minus(window);
        long[] wait = {0};
        hits.compute(key, (k, deque) -> {
            Deque<Instant> d = deque == null ? new ArrayDeque<>() : deque;
            while (!d.isEmpty() && !d.peekFirst().isAfter(windowStart)) {
                d.pollFirst();
            }
            if (d.size() >= maxRequests) {
                wait[0] = Math.max(1, Duration.between(now, d.peekFirst().plus(window)).toSeconds() + 1);
            } else {
                d.addLast(now);
            }
            return d;
        });
        return wait[0];
    }
}
