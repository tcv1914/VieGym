# Cân nặng và quên mật khẩu — thiết kế ngày 13

UC08 (theo dõi cân nặng), UC11 (quên mật khẩu). Quy tắc: `04-business-rules.md` §2 (BR-A06, A07), §3.8 (BR-H02), §6 (BR-WL01..03). API: `05-api-contract.md` §2, §4, §11. Bảng: `03-database-design.md` §3, §4, migration `V13__create_weight_logs_and_password_reset.sql`. Kết quả kiểm tra: `30-day-13-verification.md`.

## 0. Khác với plan ngày 13

Như các ngày 5–12, dự án **giữ quyết định ngày 2** (docs/03–05) và chỉ bổ sung phần còn thiếu.

| Điểm | Plan ngày 13 | Áp dụng |
|---|---|---|
| Số docs | `28-weight-reset-design.md`, `29-day-13-verification.md` | docs/28 đã dùng cho ngày 12 → **docs/29** (thiết kế), **docs/30** (kiểm tra) |
| Cân nặng ↔ hồ sơ | Bản ghi mới nhất **là** cân nặng hồ sơ, tự tính lại mục tiêu | **BR-H02:** ghi/sửa/xóa cân nặng **không** đổi hồ sơ hay mục tiêu. Sau khi ghi lần cân mới nhất, app hỏi "Cập nhật hồ sơ?"; chỉ khi đồng ý mới gọi `PUT /health-profile/me` |
| Sửa | `PUT /weight-logs/{id}` với `revision` | `POST` lại cùng ngày → ghi đè, `200` (BR-WL01); không có revision (một user, một bản ghi/ngày, ghi sau thắng) |
| Trùng ngày | `409` | `200` ghi đè; app báo trước "Ngày này đã có … kg — lưu sẽ ghi đè" |
| Xóa | `DELETE /weight-logs/{id}`, xóa hết thì cân nặng hồ sơ về null | `DELETE` **thêm** ở ngày 13 (docs/05 chưa có); hồ sơ không đổi (BR-H02) nên không cần cột null |
| Cột | `measurement_date`, `source`, `revision` | `log_date`, `note` theo docs/03; không `source` vì không nhập lịch sử từ hồ sơ (§1) |
| Khôi phục | Link chứa token ≥ 32 byte, deep link | **Mã 6 chữ số** qua email (BR-A06), nhập trong app; không cần deep link hay URL theo môi trường |
| Đặt lại | Body `token`, `newPassword` | Body `email`, `code`, `newPassword`; tra mã theo user |
| Thêm so với docs ngày 2 | — | Hash mã gắn `userId`; giới hạn `/forgot-password` theo IP (vẫn 204); gửi email bất đồng bộ sau commit, thử 3 lần |

## 1. Cân nặng

- Một bản ghi/user/ngày theo `users.timezone` (BR-G04). UNIQUE (`user_id`, `log_date`). `POST` dùng `INSERT … ON CONFLICT DO UPDATE … RETURNING (xmax = 0)` để phân biệt 201/200 và để hai request cùng ngày đồng thời không lỗi UNIQUE. Gửi lại thay **cả** `weightKg` lẫn `note` (không gửi `note` = xóa ghi chú).
- Kiểm tra: `logDate` không ở tương lai; `weightKg` 30,0–300,0, tối đa 1 chữ số lẻ (cùng khoảng với hồ sơ — kiểm tra dữ liệu nhập, không phải phân loại sức khỏe); `note` ≤ 500.
- `GET` mặc định 90 ngày tới hôm nay, tối đa 366 ngày, tăng dần theo ngày.
- **Không** tạo bản ghi từ `health_profiles.weight_kg`: hồ sơ không lưu ngày đo, tạo bản ghi là bịa ngày.
- Dashboard: `health.latestWeightLog` = bản ghi có **ngày đo** mới nhất (không phải ghi gần nhất); `health.weightKg` vẫn là cân nặng hồ sơ.
- Snapshot thực đơn cũ không bị đụng (cân nặng không đổi mục tiêu; mục tiêu chỉ đổi khi lưu hồ sơ).

### App

Màn "Cân nặng" mở từ Sức khỏe → "Theo dõi cân nặng". Chọn khoảng 30 ngày / 90 ngày / 1 năm (luôn kết thúc hôm nay). Biểu đồ vẽ bằng `CustomPainter` (không thêm thư viện): trục X theo khoảng cách ngày thật, ngày không cân thì không có điểm, một bản ghi vẫn có chấm. Dòng chênh lệch: "Từ dd/mm/yyyy đến dd/mm/yyyy: ±x kg" giữa lần cân đầu và cuối trong khoảng — không suy tốc độ. Danh sách mới nhất trước; chạm để sửa (khóa ngày), nút xóa có xác nhận.

Hỏi cập nhật hồ sơ khi: đã có hồ sơ, lần cân vừa lưu có ngày ≥ mọi lần cân trong khoảng đang xem, và khác cân nặng hồ sơ. Đồng ý → `PUT /health-profile/me` với các trường hồ sơ hiện có + cân nặng mới. Sau mọi thao tác ghi: làm mới danh sách và dashboard (và hồ sơ nếu đã cập nhật).

## 2. Quên mật khẩu

```text
App                     Spring                                       SMTP (Mailpit / thật)
 │ POST /forgot-password ─▶ IP vượt giới hạn? → 204, bỏ qua
 │                          email không tồn tại? → 204
 │                          tx: khóa users FOR UPDATE
 │                              ≥ 3 mã trong 1 giờ? → 204, bỏ qua
 │                              vô hiệu mã cũ, lưu SHA-256(userId:mã), hạn 15 phút
 │                          ◀ 204 ── sau commit: @Async gửi email ───────▶  (thử 3 lần: 0 s, +2 s, +5 s)
 │ POST /reset-password ──▶ IP > 10/15 phút → 429 + Retry-After
 │                          tx: khóa users → mã mới nhất còn hạn, chưa dùng
 │                              sai → attempt_count+1 (lần 5 → used_at) → 400 INVALID_RESET_CODE (vẫn commit)
 │                              đúng → đổi password_hash, used_at, vô hiệu mọi mã, thu hồi mọi phiên + refresh token
 │ ◀ 204 (không cấp token) → app về màn đăng nhập, điền sẵn email
```

- Mã: `SecureRandom` 000000–999999. Lưu SHA-256 của `userId:mã`, không lưu mã; so sánh thời gian hằng (`MessageDigest.isEqual`). 6 chữ số chỉ có 10⁶ khả năng nên an toàn dựa vào **giới hạn số lần thử** (5 lần/mã, 10 lần/IP/15 phút, 3 mã/email/giờ) chứ không dựa vào hash.
- Không phân biệt email lạ / sai mã / hết hạn / đã dùng / đã bị vô hiệu: cùng `400 INVALID_RESET_CODE`.
- Không lộ email tồn tại qua `/forgot-password`: cùng `204` body rỗng; gửi email ngoài luồng request nên thời gian phản hồi không phụ thuộc SMTP.
- Đồng thời: mọi thao tác ghi khóa dòng `users` trước → hai lần đặt lại cùng mã chỉ một lần thành công; hai yêu cầu mã cùng lúc không để lại hai mã còn hạn.
- Sau đặt lại: mọi phiên bị thu hồi → access token cũ bị từ chối ngay ở request kế tiếp (SessionService kiểm tra phiên), refresh token cũ `401`.
- Log: chỉ `userId` và loại lỗi; không mã, không email, không mật khẩu. `ResetPasswordRequest.toString` không in mã/mật khẩu.
- Giới hạn theo IP nằm trong bộ nhớ (một instance, mất khi restart). Backend nghe `127.0.0.1` và không sau proxy nên dùng `remoteAddr`, không đọc `X-Forwarded-For`. Qua `adb reverse` mọi điện thoại đều là `127.0.0.1`.

### Email (BR-A07)

`spring.mail.*` lấy từ biến môi trường; mặc định là **Mailpit** (`infra/compose.yaml`, SMTP `127.0.0.1:1025`, giao diện `http://127.0.0.1:8025`) — thư bị giữ lại trên máy, **không** tới hộp thư thật. Gửi thật: đặt `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_SMTP_AUTH=true`, `MAIL_STARTTLS=true`, `MAIL_FROM` (thường phải trùng tài khoản SMTP). Không có thông tin SMTP nào trong Git.

### App

Màn đăng nhập → "Quên mật khẩu?" → nhập email → "Gửi mã" → luôn hiện "Nếu email đã đăng ký, mã gồm 6 chữ số đã được gửi… hiệu lực 15 phút" → nhập mã, mật khẩu mới, nhập lại → về đăng nhập (điền sẵn email). Có "Gửi lại mã" (mã cũ hết dùng được) và "Đổi email". Kiểm tra mật khẩu phía app dùng chung `passwordRuleError` với màn đăng ký.
