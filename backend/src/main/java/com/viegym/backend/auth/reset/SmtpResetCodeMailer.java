package com.viegym.backend.auth.reset;

import java.time.Duration;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;

/** SMTP theo spring.mail.* — Mailpit khi chạy local, SMTP thật khi đặt biến môi trường. */
@Component
class SmtpResetCodeMailer implements ResetCodeMailer {
    private final JavaMailSender mailSender;
    private final PasswordResetProperties properties;

    SmtpResetCodeMailer(JavaMailSender mailSender, PasswordResetProperties properties) {
        this.mailSender = mailSender;
        this.properties = properties;
    }

    @Override
    public void send(String to, String code, Duration ttl) {
        var message = new SimpleMailMessage();
        message.setFrom(properties.mailFrom());
        message.setTo(to);
        message.setSubject("VieGym - Mã đặt lại mật khẩu");
        message.setText("""
            Mã đặt lại mật khẩu VieGym của bạn là: %s

            Mã có hiệu lực trong %d phút và chỉ dùng được một lần. Nhập mã này trong ứng dụng VieGym, \
            mục "Quên mật khẩu".

            Nếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này; mật khẩu hiện tại vẫn giữ nguyên.
            """.formatted(code, ttl.toMinutes()));
        mailSender.send(message);
    }
}
