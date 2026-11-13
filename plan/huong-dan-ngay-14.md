# VieGym — Ngày 14: Trang quản trị tối thiểu

**Mục tiêu:** Admin quản lý món ăn, bài tập và trạng thái tài khoản qua React TypeScript. **Thời lượng:** 7–8 giờ. Giữ phạm vi đủ phục vụ vận hành dữ liệu đồ án.

## 0. Đầu vào — 20 phút

- [ ] Auth có vai trò USER/ADMIN, kiểm tra trạng thái user/session mỗi request.
- [ ] Schema foods/exercises có active và revision.
- [ ] Có tài khoản admin tạo bằng quy trình cấu hình/seed riêng; không mở đăng ký ADMIN công khai.
- [ ] Đã kiểm tra cấu trúc frontend/admin hiện có trước khi tạo thư mục mới.

## 1. Phân quyền và API — 45 phút

Tạo `docs/30-admin-design.md` và ma trận quyền:

| Tài nguyên | USER | ADMIN |
|---|---|---|
| Danh mục active | Đọc | Đọc |
| Danh mục active/inactive, tạo/sửa | Không | Có |
| Khóa/mở tài khoản | Không | Có theo quy tắc |
| Hồ sơ sức khỏe, chat, meal/log của người khác | Không | Không trong MVP |

API gợi ý, ghép prefix thực tế của dự án:

- `GET/POST /api/admin/foods`, `PUT /api/admin/foods/{id}`.
- `PATCH /api/admin/foods/{id}/status` với active và revision.
- Bộ API tương tự cho exercises.
- `GET /api/admin/users` chỉ trả thông tin quản trị cần thiết, có phân trang.
- `PATCH /api/admin/users/{id}/status` nhận locked và reason.

Backend kiểm tra ADMIN, không dựa vào menu ẩn của frontend. USER gọi API admin trả 403; chưa đăng nhập trả 401. Không cung cấp API nâng vai trò tùy tiện trong MVP.

## 2. Service danh mục — 75 phút

1. Dùng lại validator và đơn vị dinh dưỡng ngày 9, validator bài tập ngày 6.
2. Cho cập nhật có revision; version cũ trả 409, frontend yêu cầu tải lại.
3. Vô hiệu thay vì xóa dữ liệu đang được tham chiếu.
4. Không cho sửa food khiến source/serving thiếu nhưng vẫn active.
5. Khi active=false, món/bài biến mất khỏi thư viện mới; snapshot meal và lịch đã tạo vẫn đọc được.
6. Không cập nhật hàng loạt snapshot lịch sử khi sửa catalog.

Đầu vào form món ăn phải có nhãn khẩu phần, các giá trị cùng đơn vị khẩu phần, nguồn và mức độ tin cậy. Form bài tập có nhóm cơ, thiết bị, hướng dẫn, media URL hợp lệ hoặc ảnh mặc định. Chưa làm upload file hôm nay nếu roadmap không có storage và kiểm soát file.

## 3. Khóa tài khoản và audit — 60 phút

Khóa user và revoke sessions trong một transaction. Vì mỗi request kiểm tra trạng thái, access token cũ bị từ chối ngay ở request tiếp theo. Mở khóa không phục hồi session cũ; user đăng nhập lại.

Ngăn admin tự khóa tài khoản đang thao tác. Với phạm vi MVP, chỉ cho khóa USER; không xử lý quản trị nhiều ADMIN trong UI này. Backend vẫn phải thực thi quy tắc, không chỉ disable nút.

Tạo audit log tối giản: actor_id, action, entity_type, entity_id, timestamp, reason, changed_fields. Không ghi password/token/toàn bộ dữ liệu cá nhân vào audit. Audit cùng transaction với thay đổi để không có thay đổi thành công nhưng thiếu dấu vết.

- [ ] Trường trả về user không chứa password_hash hoặc token.
- [ ] Có giới hạn trang/tìm kiếm và thứ tự ổn định.
- [ ] Lỗi không lộ SQL/stack trace.

## 4. React TypeScript — 120 phút

Dùng cấu trúc dự án hiện có. Tạo các phần tương đương API client, auth state, route guard, layout và ba màn danh sách/form. Không thay bộ công cụ build nếu không cần.

Thứ tự triển khai:

1. Login admin và xử lý 401/403.
2. Layout với menu Foods, Exercises, Users.
3. Bảng foods có tìm kiếm, phân trang, trạng thái và form thêm/sửa.
4. Tái sử dụng mẫu bảng/form cho exercises.
5. Bảng users và xác nhận thao tác khóa kèm lý do.
6. Hiển thị loading, lỗi field, lỗi chung, xung đột revision và thông báo lưu thành công.

Không đưa khóa provider AI vào biến môi trường frontend: biến build frontend có thể đọc được. Với token admin, giữ access trong memory. Nếu chưa có hạ tầng cookie refresh an toàn, MVP chấp nhận đăng nhập lại sau reload, không lưu refresh token vào localStorage chỉ để tiện. Nếu dùng cookie, phải có Secure/HttpOnly/SameSite phù hợp và kiểm soát CSRF cho request thay đổi dữ liệu.

## 5. Kiểm thử xuyên hệ thống — 90 phút

| Mã | Thao tác | Kết quả |
|---|---|---|
| AD01 | USER gọi thẳng API admin | 403 |
| AD02 | Admin tạo món đủ nguồn | Flutter tìm thấy món active |
| AD03 | Hai cửa sổ sửa cùng revision | Request sau 409 |
| AD04 | Vô hiệu món đã có trong meal | Mất khỏi tìm kiếm, meal cũ vẫn đủ snapshot |
| AD05 | Vô hiệu bài đã có lịch | Lịch cũ vẫn hiển thị |
| AD06 | Khóa A đang login | Request tiếp theo của A thất bại |
| AD07 | Mở khóa A | Login mới được, session cũ vẫn chết |
| AD08 | Tên món chứa ký tự HTML | Hiển thị chữ, không chạy script |
| AD09 | Admin tự khóa hoặc đọc health B | Bị từ chối theo chính sách |

## 6. Đóng ngày

- [ ] Ba màn quản trị hoạt động với API thật.
- [ ] Có role check server, revision và audit.
- [ ] Catalog chỉnh sửa không làm sai lịch sử.
- [ ] Có `docs/31-day-14-verification.md`, ảnh minh chứng đã che dữ liệu riêng.
- [ ] Commit gợi ý: `feat: add minimal catalog and user administration`.

Ngày 15 đóng phạm vi tính năng và sửa các điểm tích hợp còn hở; không mở rộng admin thành một hệ thống quản trị đầy đủ.
