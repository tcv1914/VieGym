package com.viegym.backend.auth.reset;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.Locale;

/** docs/05 §2. Email chuẩn hóa như đăng ký (BR-A01). toString không in mã/mật khẩu. */
public final class PasswordResetDtos {
    private PasswordResetDtos() {
    }

    public record ForgotPasswordRequest(
        @NotBlank(message = "Vui lòng nhập email")
        @Size(max = 254, message = "Email tối đa 254 ký tự")
        String email
    ) {
        public ForgotPasswordRequest {
            email = normalize(email);
        }
    }

    public record ResetPasswordRequest(
        @NotBlank(message = "Vui lòng nhập email")
        @Size(max = 254, message = "Email tối đa 254 ký tự")
        String email,

        @NotBlank(message = "Vui lòng nhập mã")
        @Pattern(regexp = "^\\d{6}$", message = "Mã gồm 6 chữ số")
        String code,

        // BR-A02, như RegisterRequest; giới hạn 72 byte UTF-8 kiểm thêm ở service.
        @NotBlank(message = "Vui lòng nhập mật khẩu mới")
        @Size(min = 8, max = 72, message = "Mật khẩu từ 8 đến 72 ký tự")
        @Pattern(regexp = "^(?=.*\\p{L})(?=.*\\p{Nd}).*$", message = "Mật khẩu cần ít nhất một chữ cái và một chữ số")
        String newPassword
    ) {
        public ResetPasswordRequest {
            email = normalize(email);
            code = code == null ? null : code.strip();
        }

        @Override
        public String toString() {
            return "ResetPasswordRequest[email=" + email + "]";
        }
    }

    private static String normalize(String email) {
        return email == null ? null : email.trim().toLowerCase(Locale.ROOT);
    }
}
