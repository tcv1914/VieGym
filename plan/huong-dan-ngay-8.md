# VieGym — Ngày 8: Ghi nhận buổi tập và lịch sử luyện tập

**Mục tiêu:** User mở một buổi trong lịch, nhập kết quả thực tế từng set, lưu workout log và xem lại lịch sử. Lịch chuyển COMPLETED cùng lúc dữ liệu tập được lưu thành công. Gửi lặp không tạo hai log cho một lịch.

**Thời lượng:** khoảng 6–8 giờ nếu ngày 7 đã chạy. Đây là hướng dẫn triển khai, có SQL/API và thuật toán minh họa; không xác nhận mã nguồn đã được tạo hoặc kiểm thử. Điều chỉnh theo schema và phiên bản framework thực tế.

## 0. Rà đầu vào — 15 phút

- [ ] Auth ngày 4 còn hoạt động, có hai tài khoản test A/B.
- [ ] Có giáo án và lịch thật của A từ ngày 7.
- [ ] Lịch có snapshot các bài dự kiến trong `scheduled_exercises`.
- [ ] API đọc lịch kiểm tra quyền sở hữu.
- [ ] Database có migration và test database riêng.
- [ ] Đã lưu thay đổi hiện tại trước khi làm module mới.

Hôm nay tập trung ghi từ lịch, xem danh sách và chi tiết lịch sử. Tập tự do, chỉnh sửa/xóa log, PR, 1RM và biểu đồ nâng cao có thể triển khai sau. Dashboard tổng hợp vẫn ở ngày 11; hôm nay cập nhật màn lịch và lịch sử.

## 1. Chốt quy tắc ghi buổi tập — 30 phút

Ghi vào `docs/18-workout-log-design.md` và cập nhật use case ngày 2 nếu khác.

| Nội dung | Quy tắc MVP |
|---|---|
| Nguồn | Một lịch thuộc user hiện tại |
| Trạng thái cho phép | SCHEDULED hoặc MISSED |
| Một lịch | Tối đa một workout log |
| Bài thực tế | Chọn từ snapshot của lịch; chưa hỗ trợ thêm bài ngoài lịch |
| Hoàn thành | Buổi đã được ghi nhận, không bắt buộc thực hiện đủ mọi bài/set dự kiến |
| Buổi có dữ liệu | Tối thiểu một bài có một set hợp lệ |
| Bỏ bài | Có thể không gửi bài chưa thực hiện; không tự ghi reps bằng 0 |
| Sets thực tế | Có thể khác kế hoạch, trong giới hạn kỹ thuật |
| Reps | Số nguyên dương |
| Mức tạ | Kg, không âm; 0 được phép khi không dùng tạ ngoài |
| Sửa giáo án | Không thay kết quả thực tế đã lưu |
| Lịch CANCELLED | Từ chối ghi log |
| Lịch COMPLETED | Trả log cũ nếu gửi lại đúng nội dung, hoặc 409 nếu khác |

Chỉ hỗ trợ bài theo reps như phạm vi ngày 7. Bài tính bằng thời gian cần trackingType/duration riêng; không dùng trường reps để chứa số giây.

### Thời gian thực tế

- Request có `performedAt` dạng timestamp có offset, biểu thị thời điểm bắt đầu buổi thực tế.
- `durationMinutes` tùy chọn; nếu có, lưu số phút nguyên và kiểm tra > 0, trong giới hạn kỹ thuật đã chốt.
- `createdAt` là lúc server ghi dữ liệu; không dùng nó thay cho thời gian tập khi user ghi muộn.
- Không nhận thời điểm tập trong tương lai; kiểm tra bằng Clock server. Nếu có duration, thời điểm kết thúc suy ra cũng không vượt hiện tại.
- MISSED vẫn cho ghi muộn; lưu đúng performedAt, không ép thành hôm nay.
- Lịch tương lai chỉ cho ghi nếu ngày lịch đã tới theo timezone của lịch; có thể tập sớm hơn giờ dự kiến trong cùng ngày. Nếu muốn tập trước ngày đã lên lịch, sửa lịch trước.
- Lưu Instant và timezone snapshot của lịch; nhóm lịch sử theo ngày tại timezone đã chọn trong bộ lọc.

### Bài đã bị ẩn sau khi lên lịch

Cho phép ghi kết quả của bài đã có trong snapshot, kể cả bài gốc hiện inactive: người dùng có thể đang ghi lại hoạt động đã thực hiện. Không dùng API thư viện active-only để làm điều kiện bắt buộc đọc lịch sử. Tên và số liệu lịch sử lấy từ snapshot, không lấy tên hiện tại rồi ghi đè.

- [ ] Phân biệt rõ kế hoạch và kết quả thực tế.
- [ ] Chốt cho phép MISSED và cách ghi muộn.
- [ ] Chốt không thêm bài ngoài lịch trong MVP.
- [ ] Chốt đơn vị mức tạ cho từng loại bài trong UI; không tự quy đổi tạ đôi, tạ mỗi bên hoặc cân nặng cơ thể.

## 2. Migration dữ liệu thực tế — 45 phút

Chọn số migration tiếp theo sau schema/seed ngày 7, ví dụ `V8__create_workout_logs.sql` nếu V7 đã được sử dụng. Kiểm tra lịch sử Flyway trước, không sửa migration đã chạy.

```sql
CREATE TABLE workout_logs (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    schedule_id UUID NOT NULL UNIQUE REFERENCES workout_schedules(id),
    schedule_title_snapshot VARCHAR(150) NOT NULL,
    performed_at TIMESTAMPTZ NOT NULL,
    timezone VARCHAR(100) NOT NULL,
    duration_minutes INTEGER,
    note VARCHAR(1000),
    request_hash CHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (duration_minutes IS NULL OR duration_minutes BETWEEN 1 AND 1440)
);

CREATE TABLE workout_log_exercises (
    id UUID PRIMARY KEY,
    workout_log_id UUID NOT NULL REFERENCES workout_logs(id),
    scheduled_exercise_id UUID NOT NULL REFERENCES scheduled_exercises(id),
    exercise_id UUID NOT NULL REFERENCES exercises(id),
    exercise_name_snapshot VARCHAR(200) NOT NULL,
    position INTEGER NOT NULL CHECK (position >= 0),
    UNIQUE (workout_log_id, scheduled_exercise_id),
    UNIQUE (workout_log_id, position)
);

CREATE TABLE workout_set_logs (
    id UUID PRIMARY KEY,
    workout_log_exercise_id UUID NOT NULL REFERENCES workout_log_exercises(id),
    set_number INTEGER NOT NULL CHECK (set_number BETWEEN 1 AND 20),
    reps INTEGER NOT NULL CHECK (reps BETWEEN 1 AND 100),
    weight_kg NUMERIC(7,2) NOT NULL CHECK (weight_kg BETWEEN 0 AND 1000),
    UNIQUE (workout_log_exercise_id, set_number)
);

CREATE INDEX idx_workout_logs_user_time
    ON workout_logs(user_id, performed_at DESC, id);
```

Các giới hạn số là giới hạn kỹ thuật đề xuất, không phải khuyến nghị luyện tập. Điều chỉnh theo phạm vi đã chốt và giữ validation API khớp database. Khai báo precision/scale phù hợp khi map BigDecimal/JPA.

Quyền sở hữu liên bảng được kiểm tra ở service: user của log bằng user của lịch; scheduled_exercise phải thuộc lịch đó; exerciseId lấy từ scheduled_exercise ở server. FK riêng lẻ không tự bảo đảm toàn bộ các quan hệ này.

`request_hash` dùng nhận diện nội dung gửi lại cho cùng lịch, không phải token bảo mật. Log được giữ nguyên sau tạo trong MVP ngày 8; khi bổ sung chỉnh sửa log cần thiết kế revision và cập nhật chính sách retry.

- [ ] Unique schedule_id hoạt động.
- [ ] FK và kiểu dữ liệu khớp schema ngày 7.
- [ ] Không cascade xóa log khi sửa giáo án.
- [ ] Lịch đã hoàn thành giữ snapshot và không bị sửa/xóa vật lý.

## 3. Hợp đồng API — 30 phút

| Method | Endpoint | Mục đích |
|---|---|---|
| POST | `/api/v1/workout-logs` | Ghi kết quả và hoàn thành lịch |
| GET | `/api/v1/workout-logs` | Lịch sử của user, phân trang/lọc ngày |
| GET | `/api/v1/workout-logs/{id}` | Chi tiết log thuộc user |
| GET | `/api/v1/workout-logs/by-schedule/{scheduleId}` | Kiểm tra kết quả đã lưu sau timeout |

Tất cả yêu cầu Bearer và kiểm tra user/session như ngày 4. Không thêm API `/complete` chỉ đổi trạng thái, vì như vậy có thể tạo COMPLETED thiếu log.

POST minh họa; dùng ID thật và thời điểm đã xảy ra khi chạy:

```json
{
  "scheduleId": "<uuid-lich-cua-user>",
  "scheduleRevision": 1,
  "performedAt": "2026-11-01T08:00:00+07:00",
  "durationMinutes": 45,
  "note": "Dữ liệu demo",
  "exercises": [
    {
      "scheduledExerciseId": "<uuid-bai-trong-snapshot-lich>",
      "sets": [
        {"setNumber": 1, "reps": 10, "weightKg": 20},
        {"setNumber": 2, "reps": 8, "weightKg": 22.5}
      ]
    }
  ]
}
```

Không nhận userId, tên bài, title hoặc tổng volume làm nguồn tin cậy. Server lấy thông tin snapshot từ lịch và tính tổng từ các set đã validate.

Response tạo lần đầu: 201, gồm logId, scheduleId, scheduleStatus COMPLETED, scheduleRevision mới, performedAt, exerciseCount, setCount và totalReps. Gửi lại cùng nội dung đã lưu trả 200 với cùng logId, không tạo mới. UI xử lý cả 200 và 201 là đã lưu.

| Lỗi | Mã |
|---|---|
| Thiếu/sai JWT hoặc session hết hiệu lực | 401 |
| Lịch/log không tồn tại hoặc không thuộc user | 404 |
| Reps/tạ/thời gian/ID bài trong request sai | 400 |
| Lịch hủy, revision cũ, log đã có nhưng khác nội dung | 409 |
| Lỗi server/database | 5xx, thông báo chung; không lộ SQL hoặc stacktrace |

GET by-schedule kiểm tra quyền sở hữu lịch trước khi trả kết quả. Chưa có log trả 404 `WORKOUT_LOG_NOT_FOUND`; code khác dùng cho lịch không khả dụng. App chỉ quyết định retry sau khi hiểu đúng trường hợp, không coi mọi 404 là được tạo mới.

- [ ] Có request/response/lỗi trong tài liệu API.
- [ ] Màn Flutter biết xử lý retry thành công 200.
- [ ] Endpoint tra cứu sau timeout vẫn kiểm tra ownership.

## 4. Validate dữ liệu và snapshot — 30 phút

Tạo DTO lồng nhau có `@Valid` cho danh sách bài và danh sách set. Validation tối thiểu:

- scheduleId, scheduleRevision, performedAt bắt buộc.
- 1–20 bài/log; mỗi bài 1–20 set theo giới hạn MVP.
- Không trùng scheduledExerciseId trong request.
- Mỗi scheduledExerciseId thuộc đúng lịch đã xác thực.
- setNumber không trùng, liên tiếp 1..N cho mỗi bài.
- Reps nguyên 1–100; weightKg 0–1000, tối đa 2 chữ số lẻ.
- Duration nếu có là số nguyên 1–1440; note tối đa 1000 ký tự.
- Kiểm tra thời gian theo Bước 1; reject NaN/Infinity và số không parse được.
- Có thể nhập ít/nhiều set hơn planned_sets nhưng không vượt giới hạn payload.

Thứ tự bài lưu theo snapshot lịch; không phụ thuộc thứ tự request. Tên bài lấy từ scheduled_exercises. Số tạ 0 được chấp nhận nhưng null/rỗng không tự chuyển thành 0, vì rỗng có thể là user chưa nhập.

## 5. Lưu log và hoàn thành lịch trong một transaction — 60 phút

Cấu trúc gợi ý:

```text
workout/log/
├── WorkoutLogController.java
├── WorkoutLogService.java
├── WorkoutLogRepository.java
├── WorkoutSetLogRepository.java
├── WorkoutLogRequestNormalizer.java
├── dto/
└── entity/
```

Đặt transaction ở service public được gọi qua Spring bean. Controller chỉ nhận/validate request, lấy identity và trả DTO. Dùng rollbackFor phù hợp nếu business exception là checked; mặc định không phải mọi exception đều rollback.

Thuật toán:

```text
BEGIN TRANSACTION
  1. SELECT lịch WHERE id = scheduleId AND user_id = currentUser FOR UPDATE.
  2. Không tìm thấy → 404.
  3. Chuẩn hóa nội dung request và tính requestHash.
  4. Tìm log đã có theo scheduleId:
       hash giống → trả log cũ (200).
       hash khác → 409, không thay dữ liệu.
  5. Kiểm tra trạng thái SCHEDULED/MISSED, revision hiện tại và thời gian.
  6. Validate mọi bài/set so với snapshot của lịch.
  7. INSERT log, các bài thực tế và từng set.
  8. Chuyển lịch COMPLETED, tăng revision theo cơ chế ngày 7.
  9. Flush để phát hiện constraint error.
COMMIT
  10. Trả 201 và DTO.
```

Kiểm tra log cũ phải xảy ra trước kiểm tra revision hiện tại: sau lần lưu thành công lịch đã tăng revision, retry của request cũ vẫn phải nhận log cũ nếu nội dung không đổi. Nếu database có log nhưng lịch không COMPLETED, coi là bất nhất cần xử lý, không trả thành công giả; không nên phát sinh trạng thái này nếu transaction đúng.

Trong requestHash, dùng biểu diễn chuẩn: scheduleId, performedAt chuẩn UTC, duration, note chuẩn hóa nhất quán và các bài/set đã sort ổn định; chuẩn hóa BigDecimal để 20 và 20.00 cùng nghĩa. Không hash raw JSON vì thứ tự field có thể khác. Không đưa scheduleRevision vào hash nội dung nghiệp vụ để retry sau ghi thành công vẫn khớp.

Ràng buộc unique schedule_id là lớp bảo vệ cuối; khóa hàng lịch tuần tự hóa hai thao tác ghi cùng buổi. Request thứ hai chờ request thứ nhất commit, rồi đọc log đã lưu. Không bắt unique violation và truy vấn tiếp trong transaction đã rollback-only; xử lý ngoài ranh giới transaction nếu vẫn có trường hợp lỗi bất ngờ.

Không gọi AI, email hay dịch vụ bên ngoài trong transaction này. Khi lỗi ở bất kỳ bước ghi nào, rollback toàn bộ để không có log nửa chừng hoặc lịch hoàn thành sai.

### Đồng thời với hủy/sửa lịch/MISSED

Cập nhật các luồng ngày 7 để cùng khóa hàng lịch hoặc dùng conditional update có kiểm tra số dòng và revision tương đương:

- Hủy thắng trước → ghi log bị chặn vì CANCELLED.
- Ghi log thắng trước → hủy bị chặn vì COMPLETED.
- Sửa giờ thắng trước → request với revision cũ nhận 409.
- Chuyển MISSED chỉ khi trạng thái còn SCHEDULED, tăng revision nhất quán; không ghi đè COMPLETED.

Nếu MISSED được chuyển trong lúc user đang nhập và gây revision conflict, tải lại lịch, giữ bản nháp và yêu cầu gửi lại sau khi xác nhận trạng thái mới. Không làm mất form.

- [ ] Có khóa/kiểm soát đồng thời cùng lịch.
- [ ] Gửi lại cùng nội dung trả cùng logId.
- [ ] Nội dung khác không ghi đè log đã lưu.
- [ ] Lỗi giữa chừng rollback toàn bộ.
- [ ] Hủy và hoàn thành không thể cùng thành công.

## 6. Lịch sử và chi tiết buổi tập — 45 phút

Ví dụ:

```http
GET /api/v1/workout-logs?from=2026-10-26&to=2026-11-01&timezone=Asia/Ho_Chi_Minh&page=0&size=20
```

Chốt `from` và `to` là ngày bao gồm hai đầu ở API; backend chuyển thành khoảng `[đầu from, đầu to+1 ngày)` theo timezone. Không query bằng created_at nếu màn đang hiển thị ngày thực tế tập. Giới hạn size 1–50, page >= 0 và khoảng ngày tối đa đề xuất 366 ngày; from > to trả 400.

Danh sách trả DTO phân trang ổn định như ngày 6, sort performedAt DESC rồi id. Mỗi item có logId, title snapshot, performedAt, timezone, số bài/set và duration nếu có. Không tải toàn bộ sets cho mọi item chỉ để vẽ danh sách; dùng truy vấn tổng hợp phù hợp, tránh N+1.

Chi tiết trả snapshot tên bài, danh sách set theo setNumber, reps và weightKg. Tính tổng tại backend nếu có. Luôn thêm điều kiện currentUser vào list/detail/by-schedule; Admin không mặc nhiên được xem log cá nhân theo ma trận quyền ngày 2.

Nếu hiển thị volume, định nghĩa là tổng `reps × externalWeightKg` và gọi rõ là volume tạ ngoài; bài tạ ngoài bằng 0 không có nghĩa không tập hoặc không tiêu hao năng lượng. Hôm nay có thể chỉ hiển thị số bài/set/reps để tránh hiểu sai và dành PR/biểu đồ cho giai đoạn sau.

- [ ] Lịch sử hiển thị đúng ngày thực tế, cả nhập muộn.
- [ ] Chi tiết không thay đổi khi sửa giáo án hoặc tên bài gốc.
- [ ] Lọc và phân trang có validation.
- [ ] Các tổng tính từ dữ liệu thực tế, không từ kế hoạch.

## 7. Flutter: form ghi buổi tập — 75 phút

```text
lib/features/workout/log/
├── data/
│   ├── workout_log_api.dart
│   ├── workout_log_repository.dart
│   └── workout_log_model.dart
├── application/
│   └── workout_log_controller.dart
└── presentation/
    ├── workout_log_form_page.dart
    ├── workout_history_page.dart
    └── workout_log_detail_page.dart
```

Thứ tự thực hiện:

1. Từ lịch SCHEDULED/MISSED mở form bằng scheduleId, tải chi tiết snapshot và revision.
2. Hiển thị tên bài và sets/reps dự kiến như gợi ý, không tự coi là kết quả đã thực hiện.
3. Cho thêm/bớt dòng set, nhập reps và kg, bỏ chọn bài chưa tập.
4. Form giữ thời gian thực tế, duration tùy chọn và note.
5. Dùng key ổn định cho bài/set; dispose controller khi xóa dòng hoặc rời màn.
6. Chọn hoàn thành → validate tất cả dòng được chọn → hiện tóm tắt số bài/set → gửi POST một lần.
7. Disable nút trong lúc gửi; giữ nguyên performedAt và payload khi retry, không tự thay bằng thời gian hiện tại.
8. Chỉ hiển thị hoàn thành sau response 200/201 hoặc GET xác minh log đã lưu.
9. Thành công: mở chi tiết log và làm mới provider lịch/lịch sử. Nếu dashboard chưa có thì không đánh dấu đã tích hợp dashboard.
10. Lịch COMPLETED mở log đã lưu, không mở form tạo mới.

### Lỗi mạng và chưa biết server đã lưu chưa

Khi timeout sau POST:

- Giữ nguyên bản nháp, không tự tạo lịch mới.
- Dùng GET by-schedule kiểm tra.
- Nếu có log, hiển thị dữ liệu server; nếu người dùng đã sửa nháp khác, cho xem và so sánh, không tự ghi đè.
- Nếu đúng WORKOUT_LOG_NOT_FOUND và lịch vẫn thuộc user, cho thử lại cùng payload.
- Nếu vẫn lỗi mạng thì giữ trạng thái “chưa xác nhận lưu”, không báo hoàn thành.
- 409 khác nội dung/revision thì tải lại lịch/log, giữ dữ liệu đang nhập để user quyết định.
- 401 đi qua cơ chế refresh ngày 4; chỉ replay request ghi khi chính sách retry/idempotency của endpoint đã được bảo đảm.

Trong ngày 8, giữ nháp trong bộ nhớ khi còn màn hình là mức tối thiểu. Lưu nháp qua đóng app là phần bổ sung; nếu làm, tách theo userId/scheduleId, bảo vệ dữ liệu và xóa khi logout hoặc lưu thành công. Không hứa khôi phục sau tắt app nếu chưa triển khai.

- [ ] Có input reps/tạ rõ đơn vị.
- [ ] Tạ 0 khác trường bỏ trống.
- [ ] Bỏ bài chưa làm không tạo set 0 giả.
- [ ] Thử lại không tạo log thứ hai.
- [ ] Lỗi mạng/409 giữ nháp.
- [ ] Đổi tài khoản không lộ nháp user cũ.

## 8. Flutter: lịch sử và cập nhật lịch — 45 phút

1. Thêm mục Lịch sử trong phần Luyện tập.
2. Danh sách có ngày tập, tên buổi, số bài/set, duration nếu có.
3. Chọn khoảng ngày, tải thêm trang và xử lý lỗi trang sau mà giữ items trước.
4. Mở chi tiết bằng logId và dữ liệu server.
5. Quay lại lịch tuần thấy trạng thái COMPLETED và nút xem kết quả.
6. Mở app lại, GET lịch sử vẫn có kết quả sau khi đăng nhập/refresh.
7. Bài bị ẩn vẫn hiện tên snapshot trong lịch sử; không phụ thuộc gọi detail thư viện active-only.

- [ ] Có loading, rỗng, lỗi và thử lại.
- [ ] Các set giữ đúng thứ tự và số liệu.
- [ ] Lịch và lịch sử đồng bộ sau lưu.
- [ ] Không có nút sửa/xóa log chưa được backend hỗ trợ.

## 9. Dữ liệu test và tiêu chí nghiệm thu — 60 phút

Chuẩn bị user A/B và lịch có hai bài theo reps. Dùng số liệu kỹ thuật giả để kiểm thử, không xem là giáo án khuyến nghị:

| Bài | Set | Reps | Kg |
|---|---:|---:|---:|
| Bài A | 1 | 10 | 20 |
| Bài A | 2 | 8 | 22.5 |
| Bài B | 1 | 12 | 0 |
| Bài B | 2 | 10 | 0 |

Expected: 2 bài, 4 set, 40 reps. Nếu có volume tạ ngoài: `10×20 + 8×22.5 = 380 kg·lần`. Bài B vẫn có 22 reps dù volume tạ ngoài bằng 0.

| Mã | Tình huống | Kết quả mong đợi |
|---|---|---|
| L01 | Lưu fixture 2 bài/4 set | 201, dữ liệu đúng, lịch COMPLETED |
| L02 | Gửi lại cùng payload | 200 cùng logId, vẫn một log |
| L03 | Gửi lại khác reps | 409, dữ liệu cũ nguyên vẹn |
| L04 | Hai request đồng thời cùng payload | Một log; request sau nhận kết quả cũ |
| L05 | Hai request đồng thời khác payload | Một thành công, một 409 |
| L06 | Lỗi sau khi insert một phần | Không log/bài/set mới, lịch giữ trạng thái cũ |
| L07 | A gửi scheduleId B | 404, không thay dữ liệu B |
| L08 | A đọc logId/by-schedule của B | 404 |
| L09 | ID bài thuộc lịch khác | 400, không lưu |
| L10 | Reps 0/âm, tạ âm, trùng setNumber | 400, lỗi đúng trường |
| L11 | Tạ 0 và số thập phân | Lưu/mở lại đúng |
| L12 | CANCELLED hoặc lịch tương lai | Bị từ chối theo quy tắc |
| L13 | MISSED nhập muộn | Lưu đúng ngày thực tế và COMPLETED |
| L14 | Hủy và hoàn thành đồng thời | Chỉ một chuyển trạng thái hợp lệ thắng |
| L15 | Tự chuyển MISSED đồng thời hoàn thành | Không ghi đè COMPLETED |
| L16 | Sửa giáo án/tên bài sau khi ghi | Log vẫn giữ snapshot |
| L17 | Bài inactive sau xếp lịch | Vẫn ghi được từ snapshot theo chính sách |
| L18 | Lọc lịch sử gần ranh giới ngày/tuần | Đúng timezone, không sót dữ liệu |
| L19 | Server đã commit nhưng response mất | GET xác minh hoặc retry không tạo trùng |
| L20 | Đóng/mở app sau lưu | Đọc lại log thành công |
| L21 | JWT sai/session thu hồi | 401, không ghi dữ liệu |
| L22 | Bỏ một bài chưa thực hiện | Log chỉ ghi dữ liệu thực tế còn lại |

Kiểm thử transaction/concurrency bằng PostgreSQL test riêng. Các request đồng thời cần transaction/kết nối riêng và điểm đồng bộ có kiểm soát; gọi tuần tự hai lần không chứng minh đã chống race condition.

Đối với test rollback, tạo lỗi có chủ ý chỉ trong test ở giữa quá trình ghi và kiểm tra database sau transaction thất bại. Không thêm endpoint gây lỗi vào ứng dụng thật. Không nuốt exception trong service rồi trả DTO thành công.

Lưu kết quả vào `docs/19-day-8-verification.md`: đầu vào, expected, actual, đạt/chưa đạt, ảnh đã che token và lỗi tồn đọng. Không đánh dấu test chưa chạy là đạt.

```powershell
# Trong backend, dùng cấu hình database test
.\mvnw.cmd test

# Trong mobile
flutter analyze
flutter test
```

## 10. Lỗi thường gặp

| Lỗi | Kiểm tra |
|---|---|
| Hai log cho một lịch | Thiếu UNIQUE schedule_id hoặc dùng schedule khác khi retry |
| Retry cùng dữ liệu trả 409 | Kiểm tra revision trước log cũ hoặc hash raw JSON chưa chuẩn hóa |
| Lịch COMPLETED nhưng không có đủ log | Ghi trạng thái ngoài transaction, thiếu rollback hoặc nuốt exception |
| Lịch chuyển lại MISSED sau hoàn thành | Update thiếu điều kiện trạng thái/khóa tương thích |
| Không ghi được bài đã ẩn | Đang validate bằng thư viện active thay snapshot lịch |
| Tên/kết quả lịch sử đổi sau sửa giáo án | Dùng dữ liệu live thay snapshot và log thực tế |
| Reps/tạ nhảy sang dòng khác | Widget key/controllers gắn index không ổn định |
| Timeout tạo trùng | Client tạo request/lịch mới thay vì xác minh và retry cùng lịch |
| Log nhập muộn xuất hiện sai ngày | Dùng createdAt thay performedAt hoặc nhóm UTC sai timezone |
| Checked exception không rollback | Chưa cấu hình rollback rule phù hợp |

## 11. Checklist đóng ngày 8 — 15 phút

- [ ] Ghi log từ lịch SCHEDULED/MISSED của user.
- [ ] Lưu đúng từng bài/set/reps/tạ và thời điểm thực tế.
- [ ] Unique và retry ngăn log trùng.
- [ ] Lưu log và hoàn thành lịch trong cùng transaction.
- [ ] Hủy/MISSED không ghi đè sai trạng thái.
- [ ] Lịch sử và chi tiết dùng snapshot đúng.
- [ ] Kiểm thử phân quyền A/B thành công.
- [ ] Flutter giữ nháp khi lỗi và xác minh sau timeout.
- [ ] Mở app lại xem được kết quả thật.
- [ ] Có báo cáo kiểm thử và phần chưa hoàn thành.

Tại thư mục gốc, kiểm tra nội dung trước khi commit:

```powershell
git status
git diff
git add .
git diff --cached --stat
git diff --cached
git commit -m "feat: add workout logging and training history"
```

### Nhật ký cuối ngày

```text
Đường dẫn dự án:
Kết quả fixture 2 bài/4 set:
Kết quả retry và request đồng thời:
Kết quả rollback:
Kết quả phân quyền A/B:
Kết quả MISSED/cancel/complete:
Kết quả Android và đọc lại sau mở app:
Lỗi/chưa hoàn thành:
Commit:
Việc đầu tiên ngày mai:
```

**Điều kiện chuyển sang ngày 9:** Lưu buổi tập thành công, lịch và log nhất quán, gửi lặp không tạo bản ghi thứ hai, lịch sử đọc lại được và tách biệt tài khoản. Ngày 9 bắt đầu dữ liệu món Việt và API tra cứu món ăn.

## Tài liệu chính thức

- [Spring Framework — Transaction rollback](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/rolling-back.html): kiểm tra rollback rule của loại exception sử dụng.
- [Spring Framework — Using @Transactional](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/annotations.html): ranh giới transaction và cách gọi qua proxy.
- [PostgreSQL 17 — Explicit locking](https://www.postgresql.org/docs/17/explicit-locking.html): khóa hàng trong transaction và xử lý truy cập đồng thời.
