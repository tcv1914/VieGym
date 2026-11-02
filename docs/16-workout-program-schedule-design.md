# Giáo án và lịch tập — thiết kế ngày 7

UC04 (giáo án), UC05 (lịch tập). Bảng gốc: `03-database-design.md` §5, quy tắc: `04-business-rules.md` §4 (BR-W01..W07), API: `05-api-contract.md` §6–7. Migration: `V6__create_workout_programs_and_schedules.sql`, seed mẫu `V7__seed_workout_templates.sql`. Kết quả kiểm tra: `17-day-7-verification.md`.

## 1. Khác với plan ngày 7

Giống ngày 5–6, dự án **giữ quyết định ngày 2** (ERD, BR-W, hợp đồng API) và chỉ thêm phần ngày 2 còn thiếu.

| Điểm | Plan ngày 7 | Áp dụng |
|---|---|---|
| Lịch giữ nội dung buổi | Snapshot `scheduled_exercises` lúc tạo lịch | Lịch trỏ `workout_day_id`; buổi bị gỡ mà còn lịch thì **archive** chứ không xóa (BR-W07). Snapshot nằm ở log ngày 8 (tên bài, reps, mức tạ thực tế — docs/04 §8) |
| Hệ quả | Sửa giáo án không đổi lịch đã tạo | Sửa **bài** của buổi thì lịch SCHEDULED của buổi đó thấy bài mới (đây là "kế hoạch", chưa phải lịch sử). Gỡ hẳn buổi thì lịch vẫn giữ buổi cũ (archived) và tập được. App báo rõ điều này ở form sửa |
| Thời điểm lịch | `scheduled_at TIMESTAMPTZ` + `timezone` mỗi lịch | `scheduled_date DATE` + `start_time TIME` (tùy chọn) theo múi giờ của user (BR-G04). Không có chuyển UTC nên không lệch ngày; DST không áp dụng cho `Asia/Ho_Chi_Minh` |
| Trạng thái | thêm `MISSED` | Chỉ `SCHEDULED`/`COMPLETED`/`CANCELLED` (docs/03). Lịch quá ngày chưa tập: app hiển thị "Đã qua" từ dữ liệu, server không ghi trạng thái mới → không có chuyện ghi đè COMPLETED (W15) |
| Tuần | `weekStart` + `timezone` | `from`/`to` (khoảng đóng ngày, ≤ 62 ngày, docs/05 §7); không gửi = tuần hiện tại theo múi giờ user. App gửi thứ Hai–Chủ nhật |
| Template API | `/workout-program-templates`, `/from-template` | `GET /workout-programs?scope=templates`, `GET /workout-programs/{id}` đọc được mẫu, `POST /workout-programs {templateId}` (docs/05 §6) |
| Đặt active | `PUT /workout-programs/active` | `POST /workout-programs/{id}/activate` (**thêm**), ngoài ra `activate` trong body POST/PUT như docs/05 |
| Khóa lạc quan | `revision` | `version` (JPA `@Version`), **thêm** vào response chi tiết và bắt buộc ở PUT; lệch → `409 VERSION_CONFLICT` |
| Danh sách giáo án | phân trang | Không phân trang (docs/05), giới hạn 20 giáo án/user |
| Số bài/buổi | 20 | 15 (docs/05) |
| Tên giáo án | 150 ký tự, có `goal` | 100 ký tự + `description` (docs/03); chưa có `goal` |
| Idempotency-Key | đề xuất | **Chưa làm**. App không tự retry POST; mỗi nút gửi khóa tới khi có response (§6) |

Thêm so với ngày 2 (đã cập nhật docs/03, docs/05): cột `version`; `POST /{id}/activate`; `exerciseActive`, `thumbnailUrl` trong bài của giáo án; `from`/`to` trong response danh sách lịch; `programId`, `archived` trong `workoutDay` của lịch; `422 EXERCISE_INACTIVE` khi xếp lịch từ buổi có bài bị ẩn; `409 INVALID_STATE` khi vượt giới hạn số lượng.

## 2. Quy tắc

- Mỗi user tối đa **một** giáo án active: partial UNIQUE `(user_id) WHERE is_active` là lớp cuối; service tắt bản cũ, `flush`, rồi bật bản mới.
- Mọi thao tác ghi (giáo án lẫn lịch) khóa hàng `users` (`SELECT … FOR UPDATE`) trước → các request của cùng user chạy tuần tự: hai lần kích hoạt đồng thời không vi phạm index, không vượt giới hạn số lượng, không gỡ buổi trong lúc request khác đang xếp lịch vào buổi đó.
- Chọn mẫu = sao chép (UUID mới cho giáo án/buổi/bài, giữ `exercise_id`, ghi `source_template_id`). Mẫu chỉ đọc: PUT/activate mẫu → `403 FORBIDDEN`.
- Giáo án 1–7 buổi, buổi 1–15 bài; một bài không lặp trong cùng buổi (UNIQUE `(workout_day_id, exercise_id)`), buổi khác dùng lại được.
- `day_order`/`order_no` do server gán theo thứ tự mảng, client không gửi.
- Chỉ bài active: thêm vào giáo án, sao chép mẫu, xếp lịch đều kiểm tra; bài bị ẩn → `422 EXERCISE_INACTIVE` kèm `fields` chỉ đúng vị trí, không lưu một phần (rollback cả request).
- `targetSets` 1–10, `targetReps` 1–100, `restSeconds` 0–600 là **giới hạn kỹ thuật**, không phải khuyến nghị luyện tập. Mọi bài đều tính theo reps; bài giữ tư thế (Plank) chưa có kiểu theo giây, nên không có trong mẫu và app ghi chú "đơn vị là số lần".
- Lịch: buổi phải thuộc giáo án của chính user và chưa archived (BR-W03; của người khác/của mẫu → 404). Không xếp vào ngày đã qua (theo múi giờ user). Tối đa 5 lịch chưa hủy mỗi ngày → một tuần ≤ 35, trả trọn không cần phân trang.
- Không đổi buổi của lịch: muốn tập buổi khác thì hủy lịch cũ và tạo lịch mới.
- `PUT /workout-schedules/{id}`: dời ngày/giờ/ghi chú hoặc `CANCELLED`; khóa dòng lịch. `COMPLETED` → 400 (chỉ qua `POST /workout-logs` ngày 8). Lịch đã CANCELLED/COMPLETED → `409 INVALID_STATE` (trạng thái cuối, BR-W04); hủy lại không đổi dữ liệu. Không có version: hai lần dời cùng lúc thì lần sau thắng (dữ liệu nhỏ, chấp nhận ở MVP).

## 3. Sửa giáo án (PUT)

1. Khóa user, tìm giáo án của user (mẫu → 403, của người khác → 404).
2. So `version` gửi lên với version hiện tại → lệch `409 VERSION_CONFLICT`. Vì đã khóa user nên không có ai đổi giữa lúc so và lúc ghi.
3. Kiểm tra `days[].id`: chỉ nhận buổi đang có của giáo án, không trùng.
4. Hibernate flush theo thứ tự INSERT → UPDATE → DELETE, nên chia hai pha để không vấp UNIQUE thứ tự:
   - pha 1: buổi giữ lại dời `day_order + 100` và xóa hết bài; buổi bị bỏ → archive nếu còn lịch tham chiếu, không thì xóa → `flush`;
   - pha 2: đánh lại thứ tự 1..n theo body, thêm buổi mới, chèn lại bài.
5. Response trả `version` mới.

## 4. Giáo án mẫu

Hai mẫu ở V7 (ID cố định `7e000000-…`), bài tham chiếu theo `code` của V5 (subquery `NOT NULL`: thiếu bài thì migration lỗi):

| Mẫu | Buổi | Bài/buổi | Thiết bị |
|---|---|---|---|
| Full Body cơ bản — 3 buổi | A, B, C | 5 | Tạ đơn, cáp, không dụng cụ |
| Thân trên / Thân dưới — 4 buổi | Thân trên A/B, Thân dưới A/B | 4–5 | Tạ đòn, cáp, máy |

Nguồn: cấu trúc chia buổi phổ biến (toàn thân 3 buổi; thân trên/thân dưới 4 buổi), chỉ dùng bài có sẵn trong thư viện ngày 6 và tính theo reps. Số sets/reps/nghỉ là **dữ liệu minh họa đồ án, chưa được huấn luyện viên rà**, ghi rõ trong `description` của mẫu.

## 5. App

```text
lib/features/workout/
├── program/  data / application / presentation
└── schedule/ data / application / presentation
```

- Tab "Giáo án" và "Lịch tập" trong `HomeShell`.
- Danh sách giáo án của mình (badge "Đang dùng" theo server), nút "Dùng mẫu" → danh sách mẫu → chi tiết → "Dùng giáo án này" (sao chép) → mở bản của mình.
- Form giáo án: tên, mô tả, buổi (thêm/xóa/lên/xuống), bài chọn từ thư viện ngày 6 (không gõ UUID), sets/reps/nghỉ có đơn vị. Mỗi dòng có key ổn định (không theo index); controller dispose khi xóa dòng hoặc rời màn. Chặn ở client: buổi trống, bài trùng trong buổi, số ngoài khoảng (server kiểm tra lại).
- Lưu cả cấu trúc một lần; lỗi mạng giữ bản nháp trong màn. `409 VERSION_CONFLICT` → hộp thoại "Tải bản mới" (bỏ thay đổi), không tự ghi đè. Rời form có thay đổi chưa lưu → hỏi xác nhận.
- Kích hoạt chờ response rồi tải lại danh sách.
- Lịch: tuần thứ Hai–Chủ nhật, nút tuần trước/sau/tuần này, nhóm theo `scheduledDate` (chuỗi ngày, không có giờ UTC). "Hôm nay" theo giờ máy (MVP chỉ hỗ trợ `Asia/Ho_Chi_Minh`, docs/04 BR-G04).
- Xếp lịch: chọn giáo án → buổi → ngày (`showDatePicker`, không cho ngày đã qua) → giờ (tùy chọn) → ghi chú. Hủy picker giữ giá trị cũ. Thành công → mở tuần chứa ngày vừa xếp.
- Chi tiết lịch: bài của buổi, dời ngày/giờ, hủy (có xác nhận). Lịch đã hủy vẫn hiển thị (gạch ngang). Không có nút "đánh dấu hoàn thành".
- Mọi nút gửi bị khóa khi đang chờ response (không gửi lặp khi bấm nhanh). Không tự retry POST.
- Provider phụ thuộc phiên đăng nhập, `autoDispose`: logout/đổi tài khoản không còn dữ liệu của người trước.

## 6. Giới hạn còn lại

- Chưa có Idempotency-Key: mạng lỗi sau khi server đã ghi mà người dùng bấm lưu lại thì có thể tạo bản trùng. App không tự retry; lỗi kết nối hiển thị "Hãy tải lại để kiểm tra trước khi gửi lại".
- Không có lịch lặp, lịch tháng, kéo thả, thông báo, AI tạo giáo án.
- Không xóa giáo án (chưa có endpoint; giới hạn 20/user).
- Dời lịch không có khóa lạc quan (§2).
- Bài giữ tư thế theo giây chưa có trong giáo án.
