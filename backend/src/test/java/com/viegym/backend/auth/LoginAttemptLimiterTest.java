package com.viegym.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

/** BR-A09 với đồng hồ điều khiển được: ngưỡng email/IP, cửa sổ trượt, xóa khi đúng. */
class LoginAttemptLimiterTest {
    private final MovableClock clock = new MovableClock();
    private final LoginAttemptLimiter limiter =
        new LoginAttemptLimiter(new LoginLimitProperties(3, 5, Duration.ofMinutes(15)), clock);

    @Test
    void emailIsBlockedAfterMaxFailuresUntilOldestLeavesWindow() {
        for (int i = 0; i < 3; i++) {
            assertThat(limiter.retryAfterSeconds("a@x.vn", "1.1.1.1")).isZero();
            limiter.recordFailure("a@x.vn", "1.1.1.1");
            clock.advance(Duration.ofMinutes(1));
        }
        // Lần sai đầu ở phút 0, giờ là phút 3 → chờ khoảng 12 phút.
        long wait = limiter.retryAfterSeconds("A@X.vn ", "2.2.2.2");
        assertThat(wait).isBetween(12 * 60L, 12 * 60L + 1);
        // Email khác, IP khác không bị ảnh hưởng.
        assertThat(limiter.retryAfterSeconds("b@x.vn", "2.2.2.2")).isZero();
        clock.advance(Duration.ofSeconds(wait));
        assertThat(limiter.retryAfterSeconds("a@x.vn", "2.2.2.2")).isZero();
    }

    @Test
    void ipIsBlockedAcrossDifferentEmails() {
        for (int i = 0; i < 5; i++) {
            limiter.recordFailure("u" + i + "@x.vn", "9.9.9.9");
        }
        assertThat(limiter.retryAfterSeconds("new@x.vn", "9.9.9.9")).isPositive();
        assertThat(limiter.retryAfterSeconds("new@x.vn", "8.8.8.8")).isZero();
    }

    @Test
    void successClearsEmailFailuresButNotIp() {
        limiter.recordFailure("a@x.vn", "1.1.1.1");
        limiter.recordFailure("a@x.vn", "1.1.1.1");
        limiter.recordSuccess("a@x.vn");
        limiter.recordFailure("a@x.vn", "1.1.1.1");
        limiter.recordFailure("a@x.vn", "1.1.1.1");
        assertThat(limiter.retryAfterSeconds("a@x.vn", "3.3.3.3")).isZero();
        // IP đã có 4 lần sai; lần thứ 5 chặn IP.
        limiter.recordFailure("c@x.vn", "1.1.1.1");
        assertThat(limiter.retryAfterSeconds("d@x.vn", "1.1.1.1")).isPositive();
    }

    private static final class MovableClock extends Clock {
        private Instant now = Instant.parse("2026-11-15T10:00:00Z");

        void advance(Duration d) {
            now = now.plus(d);
        }

        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }
}
