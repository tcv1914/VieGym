package com.viegym.backend.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.Locale;

/** Không có role/status: server luôn đặt USER + ACTIVE. Field lạ trong JSON bị bỏ qua. */
public record RegisterRequest(
    @NotBlank(message = "Vui lòng nhập email")
    @Email(message = "Email không hợp lệ")
    @Size(max = 254, message = "Email tối đa 254 ký tự")
    String email,

    // BR-A02. Giới hạn 72 byte UTF-8 của BCrypt kiểm tra thêm ở AuthService.
    @NotBlank(message = "Vui lòng nhập mật khẩu")
    @Size(min = 8, max = 72, message = "Mật khẩu từ 8 đến 72 ký tự")
    @Pattern(regexp = "^(?=.*\\p{L})(?=.*\\p{Nd}).*$", message = "Mật khẩu cần ít nhất một chữ cái và một chữ số")
    String password,

    @NotBlank(message = "Vui lòng nhập họ tên")
    @Size(max = 100, message = "Họ tên tối đa 100 ký tự")
    String fullName
) {
    // Chuẩn hóa trước khi validate (BR-A01). Không đụng tới mật khẩu.
    public RegisterRequest {
        email = email == null ? null : email.trim().toLowerCase(Locale.ROOT);
        fullName = fullName == null ? null : fullName.trim();
    }

    @Override
    public String toString() {
        return "RegisterRequest[email=" + email + ", fullName=" + fullName + "]";
    }
}
