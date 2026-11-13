package com.viegym.backend.auth.reset;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Gửi email ngoài luồng request: thời gian phản hồi của /forgot-password không lộ email có tồn tại
 * hay không, và SMTP chậm không giữ giao dịch. Thử tối đa 3 lần; log chỉ có userId + loại lỗi,
 * không có mã hay địa chỉ email.
 */
@Component
@EnableAsync
class ResetCodeDelivery {
    private static final Logger log = LoggerFactory.getLogger(ResetCodeDelivery.class);
    private static final long[] RETRY_DELAYS_MS = {2_000, 5_000};

    private final ResetCodeMailer mailer;

    ResetCodeDelivery(ResetCodeMailer mailer) {
        this.mailer = mailer;
    }

    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onRequested(ResetCodeRequested event) {
        for (int attempt = 1; ; attempt++) {
            try {
                mailer.send(event.email(), event.code(), event.ttl());
                log.info("Đã gửi mã đặt lại mật khẩu cho user {} (lần {})", event.userId(), attempt);
                return;
            } catch (RuntimeException ex) {
                log.warn("Gửi mã đặt lại cho user {} thất bại lần {}: {}", event.userId(), attempt,
                    ex.getClass().getSimpleName());
                if (attempt > RETRY_DELAYS_MS.length) {
                    log.error("Bỏ gửi mã đặt lại cho user {} sau {} lần", event.userId(), attempt);
                    return;
                }
                try {
                    Thread.sleep(RETRY_DELAYS_MS[attempt - 1]);
                } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt();
                    return;
                }
            }
        }
    }
}
