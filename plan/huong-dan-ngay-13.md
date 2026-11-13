# VieGym — Ngày 13: Theo dõi cân nặng và khôi phục mật khẩu

**Mục tiêu:** Xem lịch sử cân nặng bằng biểu đồ và khôi phục tài khoản qua email. **Thời lượng:** 7–8 giờ, chia khoảng 3 giờ cho cân nặng, 4 giờ cho reset password và 1 giờ kiểm tra.

## 0. Chuẩn bị

- [ ] Module health ngày 5 và cơ chế session ngày 4 hoạt động.
- [ ] Đã chọn cách gửi email, có hộp thư test do bạn kiểm soát.
- [ ] Có database test, tài khoản A/B và cấu hình URL reset riêng từng môi trường.
- [ ] Giữ lại các quy tắc null target và lịch sử snapshot đã chốt.

## 1. Quy tắc cân nặng — 30 phút

MVP một bản ghi mỗi user mỗi ngày địa phương; ghi lại cùng ngày là cập nhật có kiểm tra revision. Không nhận ngày tương lai. Chốt khoảng hợp lệ phục vụ kiểm tra dữ liệu, ví dụ lớn hơn 0 và không vượt giới hạn kỹ thuật đã định nghĩa; không coi khoảng này là phân loại sức khỏe.

Chọn rõ chính sách: bản ghi cân nặng mới nhất là cân nặng hiện tại của hồ sơ. Thêm/sửa/xóa một bản ghi cũ phải xác định lại bản ghi mới nhất. Khi thay đổi cân nặng hiện tại, tính lại chỉ số và mục tiêu hiện tại bằng service ngày 5; không đổi target snapshot của meal plan cũ.

Nếu đã có cân nặng trong health profile nhưng chưa có log, migration chỉ tạo log khi biết ngày đo; nếu chỉ biết ngày nhập, gắn nguồn PROFILE_BASELINE và giải thích đó là ngày ghi nhận. Không bịa ngày đo lịch sử.

## 2. Schema, API và transaction — 60 phút

`weight_logs`: id, user_id, measurement_date DATE, weight_kg NUMERIC, source, revision, created_at, updated_at. Unique `(user_id, measurement_date)`; constraint cân nặng dương. Index hỗ trợ đọc theo user/ngày.

| API | Công dụng |
|---|---|
| GET /api/weight-logs?from=...&to=... | Danh sách theo ngày tăng dần, giới hạn khoảng truy vấn |
| POST /api/weight-logs | Tạo; trùng ngày trả 409 và cho UI mở bản ghi hiện có |
| PUT /api/weight-logs/{id} | Sửa với revision |
| DELETE /api/weight-logs/{id} | Xóa bản ghi thuộc user |

Không nhận userId. Khóa health profile khi cập nhật log và tính lại dữ liệu hiện tại trong cùng transaction. Nếu xóa hết log, áp dụng chính sách đã ghi rõ: chuyển cân nặng hiện tại về null và vô hiệu hóa các chỉ số phụ thuộc; UI yêu cầu nhập lại, không âm thầm dùng dữ liệu đã xóa. Nếu schema cũ không cho phép null, sửa migration/service trước khi bật chức năng xóa cuối cùng.

## 3. Biểu đồ Flutter — 60 phút

1. Tạo màn hình lịch sử, form cân nặng/ngày, danh sách chỉnh sửa.
2. Dùng package biểu đồ đã có hoặc chọn package tương thích dự án và khóa phiên bản. Không đổi state management hôm nay.
3. Trục X là ngày đo, Y là kg; không chèn giá trị 0 cho ngày không có dữ liệu.
4. Một điểm vẫn hiển thị marker; không dữ liệu có CTA nhập.
5. Hiển thị chênh lệch giữa hai mốc có dữ liệu và nêu rõ khoảng ngày; không suy diễn tốc độ giảm cân cho ngày thiếu.
6. Sau ghi, invalidate health/dashboard/weight providers. Không tự đổi snapshot meal plan.

Fixture: ngày 1 = 70 kg, ngày 3 = 69,5 kg, ngày 7 = 69,8 kg; chênh lệch đầu–cuối = -0,2 kg. Đây là dữ liệu kiểm thử, không phải mục tiêu sức khỏe.

## 4. Thiết kế khôi phục mật khẩu — 45 phút

Tạo `password_reset_tokens`: id, user_id, token_hash, expires_at, used_at, created_at. Token ngẫu nhiên mật mã ít nhất 32 byte; chỉ lưu SHA-256 của token. TTL đề xuất cho dự án là 15 phút, cấu hình được. Một lần dùng thành công phải tiêu thụ token và thu hồi mọi session.

| API | Quy tắc |
|---|---|
| POST /api/auth/forgot-password | Nhận email; trả thông báo chung dù email tồn tại hay không |
| POST /api/auth/reset-password | Nhận token và newPassword; không tự đăng nhập |

Thông báo chung: “Nếu địa chỉ email phù hợp, hướng dẫn khôi phục sẽ được gửi.” Có giới hạn theo IP và tài khoản, tránh phân biệt user qua body/status/thời gian phản hồi dễ quan sát. Không trả token qua response và không ghi token vào log.

URL trong email lấy từ cấu hình tin cậy, không dựng từ Host header của request. Dùng trang reset hoặc deep link đã kiểm thử trên thiết bị. Trong môi trường local có thể dùng hộp thư bắt email phục vụ phát triển; phải ghi rõ đó chưa phải thử gửi email thật.

## 5. Triển khai và chống race — 90 phút

1. Chuẩn hóa email theo quy tắc đăng ký, tạo token khi tài khoản tồn tại.
2. Làm vô hiệu token cũ theo chính sách nhất quán, lưu token mới và gửi email sau khi lưu thành công.
3. Khi reset, validate password theo chính sách chung; băm token để tra cứu.
4. Khóa dòng token, kiểm tra chưa dùng/chưa hết hạn bằng server clock.
5. Trong cùng transaction: cập nhật password hash, đánh dấu token đã dùng, vô hiệu mọi reset token của user và revoke auth_sessions.
6. Sau commit, yêu cầu đăng nhập lại. Hai request reset đồng thời chỉ một request thành công.
7. Xử lý email gửi thất bại bằng log đã làm sạch và retry có giới hạn; UI không tiết lộ sự tồn tại của email.

## 6. Kiểm thử — 75 phút

| Mã | Ca kiểm thử | Kỳ vọng |
|---|---|---|
| W01 | Ba điểm fixture | Biểu đồ đúng, chênh lệch -0,2 kg |
| W02 | Sửa bản ghi cũ | Current weight vẫn theo ngày mới nhất |
| W03 | Xóa điểm mới nhất/cuối cùng | Current/target cập nhật đúng chính sách |
| W04 | User B sửa log A | 404 |
| P01 | Email có/không tồn tại | Thông báo chung |
| P02 | Token hết hạn/đã dùng/sai | Không đổi mật khẩu |
| P03 | Hai request cùng token | Chỉ một thành công |
| P04 | Reset thành công | Mật khẩu cũ sai, mới đúng, session cũ bị từ chối |
| P05 | Link trên điện thoại/email thật | Mở đúng môi trường, hoàn tất luồng |

## 7. Checklist và bằng chứng

- [ ] Có `docs/28-weight-reset-design.md` và `docs/29-day-13-verification.md`.
- [ ] Weight, health và dashboard nhất quán; snapshot cũ giữ nguyên.
- [ ] Reset token một lần dùng, có TTL và rate limit.
- [ ] Email/link thật được kiểm tra hoặc ghi rõ phần còn chưa hoàn tất.
- [ ] Không có token, mật khẩu hay thông tin SMTP trong commit.
- [ ] Commit gợi ý: `feat: add weight tracking and password recovery`.

Tham khảo: [OWASP — Forgot Password](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html).
