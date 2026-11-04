# Ghi nhận buổi tập và lịch sử — thiết kế ngày 8

UC06. Bảng gốc: `03-database-design.md` §5, quy tắc: `04-business-rules.md` §4 (BR-W04..W09), API: `05-api-contract.md` §8. Migration: `V8__create_workout_logs.sql`. Kết quả kiểm tra: `19-day-8-verification.md`.

## 1. Khác với plan ngày 8

Như ngày 5–7, dự án **giữ quyết định ngày 2** và chỉ bổ sung phần ngày 2 còn thiếu.

| Điểm | Plan ngày 8 | Áp dụng |
|---|---|---|
| Nguồn bài | Chọn từ snapshot `scheduled_exercises` của lịch, không cho bài ngoài lịch | Lịch trỏ `workout_day` (docs/16 §1), không có `scheduled_exercises`. Request gửi `exerciseId`. Bài **trong buổi** ghi được kể cả khi đã bị ẩn; bài **ngoài buổi** được phép nếu còn hoạt động (BR-W08), bị ẩn → `422 EXERCISE_INACTIVE` |
| Trạng thái được ghi | `SCHEDULED` hoặc `MISSED` | Chỉ `SCHEDULED` (không có MISSED — docs/16 §1). Lịch đã qua ngày vẫn ghi muộn được |
| Gửi lặp | Hash nội dung: giống → `200` cùng log, khác → `409` | Mọi lần gửi lặp → `409 WORKOUT_ALREADY_LOGGED` kèm `workoutLogId` (BR-W06). App coi đây là "đã lưu", mở log hiện có; log không bao giờ bị ghi đè. Không cần `request_hash` |
| `scheduleRevision` | Bắt buộc trong request | Lịch không có version (docs/16 §2). Khóa dòng lịch là đủ: hủy/dời/hoàn thành chạy tuần tự |
| Tra cứu sau timeout | `GET /workout-logs/by-schedule/{id}` | Dùng `GET /workout-schedules/{id}` → `workoutLogId` (khác null khi đã có log). Không thêm endpoint |
| Thời gian | `performedAt` + `durationMinutes` + `timezone` | `startedAt`/`endedAt` tùy chọn (docs/03). Ngày tập = `workout_date` lấy từ `scheduled_date` (ngày theo múi giờ user) nên lọc lịch sử không lệch ngày |
| `setNumber` | Client gửi, phải liên tiếp 1..N | Server đánh `setNo`/`orderNo` theo thứ tự mảng (BR-W08), client không gửi |
| Giới hạn | reps 1–100, tạ NUMERIC(7,2) 0–1000 | reps 1–1000, tạ NUMERIC(5,2) 0–999,99 (docs/03) |
| Lọc lịch sử | `timezone` trong query | Không cần: lọc theo `workout_date` (DATE) |

Thêm so với ngày 2 (đã cập nhật docs/03, docs/05): cột `program_name_snapshot`; response có `programName`, `totalReps`, `exerciseCount`/`setCount` trong chi tiết; `workoutLogId` trong body lỗi 409; tham số `from`/`to` không bắt buộc.

## 2. Quy tắc

| Nội dung | Quy tắc |
|---|---|
| Nguồn | Một lịch của user hiện tại; lịch người khác → 404 |
| Trạng thái | `SCHEDULED`. `CANCELLED` → `409 INVALID_STATE`. Đã có log → `409 WORKOUT_ALREADY_LOGGED` + `workoutLogId` |
| Ngày | `scheduled_date` sau hôm nay (múi giờ user) → `409 INVALID_STATE` (BR-W09). Muốn tập sớm: dời lịch về hôm nay trước. Ngày đã qua: ghi muộn được, `workout_date` vẫn là ngày của lịch |
| Hoàn thành | Đã ghi nhận ≥ 1 bài, mỗi bài ≥ 1 hiệp. Không bắt buộc đủ kế hoạch; bài không tập thì không gửi (không tạo hiệp 0 giả) |
| Bài | 1–20 bài, không trùng `exerciseId` trong một log (gộp các hiệp vào một bài) |
| Hiệp | 1–20 hiệp/bài; `reps` nguyên 1–1000 (10.5 → 400, không cắt); `weightKg` 0–999,99, tối đa 2 số lẻ, **bắt buộc** — bỏ trống không hiểu là 0 |
| Thời gian | `startedAt`, `endedAt` tùy chọn; không quá hiện tại + 5 phút (lệch đồng hồ máy); `endedAt ≥ startedAt`; tối đa 24 giờ |
| Ghi chú | ≤ 1000 ký tự, cắt khoảng trắng hai đầu, rỗng → null |
| Snapshot | Tên buổi, tên giáo án, tên bài chụp lúc ghi. Sửa giáo án, đổi tên/ẩn bài sau đó không đổi log |
| Sửa/xóa log | Không có trong MVP |

Mọi giới hạn số là **giới hạn kỹ thuật**, không phải khuyến nghị luyện tập. Mức tạ là **tạ ngoài** (kg, nhập đúng số đang cầm/đeo; app không quy đổi tạ đôi, mỗi bên hay cân nặng cơ thể). Chỉ hỗ trợ bài tính theo số lần như ngày 7.

## 3. Giao dịch và đồng thời

`POST /workout-logs`, một giao dịch:

```text
1. SELECT users FOR UPDATE            (cùng thứ tự khóa với sửa/hủy lịch, sửa giáo án → không deadlock)
2. SELECT workout_schedules WHERE id AND user_id FOR UPDATE → không có: 404
3. Đã có log của lịch → 409 WORKOUT_ALREADY_LOGGED + workoutLogId   (trước kiểm tra trạng thái)
4. CANCELLED → 409; ngày tương lai → 409; kiểm tra thời gian
5. Kiểm tra bài (trùng, tồn tại, ẩn ngoài buổi)
6. INSERT log + bài + hiệp (cascade), UPDATE lịch = COMPLETED
7. flush → lỗi ràng buộc lộ ra trong giao dịch → rollback tất cả
```

- Hai request cùng lịch: request sau chờ khóa, thấy log của request trước → 409. UNIQUE `schedule_id` là lớp cuối.
- Hủy và hoàn thành cùng lúc: cùng khóa dòng lịch; bên sau thấy trạng thái cuối → 409. Không thể vừa CANCELLED vừa có log.
- Không có luồng MISSED phía server nên không có gì ghi đè COMPLETED.
- Lỗi ở bất kỳ bước ghi nào → rollback cả log lẫn trạng thái lịch, trả `500 INTERNAL_ERROR` thông điệp chung (đã kiểm bằng trigger chỉ có trong test).
- Không gọi dịch vụ ngoài trong giao dịch.

## 4. Lịch sử

- `GET /workout-logs?from=&to=&page=&size=`: khoảng đóng theo `workout_date`, mỗi đầu tùy chọn, tối đa 366 ngày khi gửi cả hai; `size` 1–100. Sắp `workoutDate` giảm dần, rồi `createdAt`, `id` (ổn định khi phân trang).
- Danh sách không tải hiệp: một truy vấn trang + một truy vấn `GROUP BY` tính số bài/hiệp/lần/volume cho cả trang.
- Chi tiết: bài theo `orderNo`, hiệp theo `setNo` (hiệp của mọi bài tải bằng một truy vấn `IN`).
- `totalVolumeKg = Σ reps × weightKg` — **chỉ tạ ngoài**; bài không tạ có volume 0 nhưng vẫn tính vào `totalReps`. App ghi rõ điều này.
- Mọi truy vấn kèm user hiện tại; Admin không xem log cá nhân.

## 5. App

```text
lib/features/workout/log/
├── data/         log_api.dart, log_models.dart
├── application/  log_draft.dart, log_providers.dart
└── presentation/ log_form_page.dart, log_detail_page.dart, log_history_page.dart, log_format.dart
```

- Chi tiết lịch: "Bắt đầu tập" (khóa khi chưa tới ngày, ghi "Chưa tới ngày tập"); lịch đã tập có "Xem kết quả đã ghi", không mở form.
- Form: mỗi bài có ô chọn (bỏ = chưa tập), số hiệp ban đầu = số hiệp kế hoạch; ô **số lần** và **tạ (kg)** để trống, kế hoạch chỉ là gợi ý (hint, nút "Điền N lần vào ô trống" chỉ điền số lần). Thêm/xóa hiệp; hiệp mới lấy lại mức tạ của hiệp trước. Key và controller theo id ổn định của hiệp, dispose khi xóa dòng/rời màn.
- Giờ: lịch hôm nay → bắt đầu = lúc mở form, kết thúc = lần bấm lưu đầu tiên (giữ khi gửi lại). Lịch ngày đã qua → không gửi giờ.
- Bấm "Hoàn thành" → kiểm tra ở app → hộp xác nhận "Lưu N bài, M hiệp" → POST một lần, nút khóa khi đang gửi.
- `201` → mở chi tiết log, tải lại lịch tuần/chi tiết lịch/lịch sử.
- `409 WORKOUT_ALREADY_LOGGED` → báo "đã ghi nhận trước đó", cho mở log đã lưu; bản nháp vẫn giữ để so sánh.
- `400`/`422` → lỗi hiện đúng ô (đường dẫn `exercises[i]...` theo danh sách bài đã chọn).
- `409 INVALID_STATE`, `404`, `5xx` → banner lỗi, giữ nháp.
- Mất mạng → hỏi lại `GET /workout-schedules/{id}`: có `workoutLogId` → coi là đã lưu, mở log; không có → báo "máy chủ chưa nhận", bấm lại để gửi; không hỏi được → "chưa xác nhận", giữ nháp. Không tự gửi lại.
- Rời form khi đã nhập → hỏi xác nhận. Nháp chỉ giữ trong màn (không lưu qua tắt app).
- Lịch sử: nút đồng hồ trên tab "Lịch tập". Lọc khoảng ngày (≤ 366), "Tải thêm"; lỗi trang sau giữ mục đã có, có "Thử lại". Có log mới → tự tải lại.
- Provider phụ thuộc phiên đăng nhập; đổi tài khoản không còn dữ liệu người trước.

## 6. Giới hạn còn lại

- Không sửa/xóa log; không tập tự do (không gắn lịch); không PR/1RM/biểu đồ.
- Bài theo thời gian (giây) chưa hỗ trợ.
- Nháp mất khi tắt app.
- Dashboard (ngày 11) chưa dùng dữ liệu log.
