# VieGym — Ngày 7: Giáo án cơ bản và lịch tập tuần

**Mục tiêu:** User chọn giáo án mẫu hoặc tự tạo giáo án bằng bài tập ngày 6, chỉnh sets/reps/thời gian nghỉ, chọn giáo án hoạt động và xếp các buổi vào lịch tuần. Dữ liệu thuộc đúng tài khoản và được lưu thật.

**Thời lượng:** 6–8 giờ khi thư viện và Auth đã chạy. Đây là hướng dẫn thiết kế/triển khai, không xác nhận code đã được tạo hoặc kiểm thử. SQL và JSON minh họa cần tích hợp theo schema hiện có.

## 0. Rà đầu vào — 15 phút

- [ ] Đăng nhập, refresh và logout hoạt động.
- [ ] Có thư viện bài tập active, ID ổn định và API chi tiết ngày 6.
- [ ] Flutter tìm/chọn được bài tập thật.
- [ ] Database và migration hoạt động.
- [ ] Có quy tắc quyền sở hữu theo use case ngày 2.
- [ ] Đã lưu thay đổi hiện tại trước khi làm module mới.

Ngày 7 chưa ghi mức tạ/reps thực tế hoặc đánh dấu COMPLETED bằng nút độc lập. Ngày 8 sẽ tạo workout log và hoàn thành lịch trong cùng transaction để không có lịch hoàn thành nhưng thiếu log.

## 1. Chốt phạm vi và quy tắc — 30 phút

Tạo `docs/16-workout-program-schedule-design.md`.

### Phân biệt ba khái niệm

| Khái niệm | Ví dụ | Dữ liệu |
|---|---|---|
| Giáo án | Giáo án cá nhân A | Các buổi và bài dự kiến |
| Buổi mẫu trong giáo án | Buổi thân trên | Bài, sets, reps, nghỉ |
| Lịch tập cụ thể | Buổi thân trên vào một ngày/giờ | Thời điểm và snapshot bài dự kiến |

Sets/reps ở giáo án là kế hoạch; kết quả từng set ngày 8 là dữ liệu thực tế, không ghi chung vào bảng bài dự kiến.

### Quy tắc đề xuất MVP

- User có nhiều giáo án cá nhân nhưng tối đa một giáo án hoạt động.
- Có ít nhất một giáo án mẫu. Chọn mẫu là sao chép thành giáo án thuộc user; không sửa bản mẫu dùng chung.
- Một giáo án có ít nhất một buổi, mỗi buổi ít nhất một bài.
- Một bài không lặp trong cùng buổi ở MVP để đơn giản thao tác; nhiều buổi khác nhau có thể dùng cùng bài.
- Các vị trí buổi/bài do server xác định theo thứ tự mảng, không tin vị trí tùy ý từ client.
- Chỉ dùng bài active để thêm mới hoặc tạo lịch mới.
- Mỗi lịch cụ thể có snapshot tên buổi, tên bài và sets/reps/nghỉ; sửa giáo án sau đó không âm thầm đổi lịch đã tạo.
- Đổi giáo án hoạt động không xóa hoặc tự sinh lại lịch.
- Lịch SCHEDULED được đổi giờ hoặc hủy; CANCELLED giữ lại để truy vết.
- MISSED được xử lý theo quy tắc xác định ở phần dưới; COMPLETED chỉ qua workflow ngày 8.
- Không cần kéo thả, lịch tháng, thông báo, lặp vô hạn hoặc AI tạo giáo án hôm nay.

Không biến giáo án demo thành khuyến nghị luyện tập cá nhân. Nội dung buổi mẫu cần rà từ nguồn phù hợp và ghi rõ dùng minh họa đồ án.

- [ ] Chốt phạm vi trước khi tạo schema.
- [ ] Sửa giáo án có thông báo không áp ngược vào lịch đã tạo.
- [ ] Không tạo API hoàn thành lịch bỏ qua workout log.

## 2. Migration giáo án và lịch — 45–60 phút

Dùng số migration tiếp theo thực tế, ví dụ `V6__create_workout_programs_and_schedules.sql` nếu V4 tạo thư viện và V5 seed ngày 6. Không đoán V5 chưa dùng hoặc sửa migration đã chạy.

Ví dụ schema cho mô hình một bài/một nhóm chính ngày 6:

```sql
CREATE TABLE workout_programs (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    name VARCHAR(150) NOT NULL,
    goal VARCHAR(30) NOT NULL,
    is_template BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT FALSE,
    revision INTEGER NOT NULL DEFAULT 1 CHECK (revision > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK ((is_template AND user_id IS NULL AND NOT is_active)
        OR (NOT is_template AND user_id IS NOT NULL)),
    CHECK (goal IN ('LOSE_WEIGHT','GAIN_WEIGHT','BUILD_MUSCLE','MAINTAIN'))
);

CREATE UNIQUE INDEX uq_one_active_program_per_user
    ON workout_programs(user_id) WHERE is_active = TRUE;

CREATE TABLE workout_days (
    id UUID PRIMARY KEY,
    program_id UUID NOT NULL REFERENCES workout_programs(id),
    name VARCHAR(150) NOT NULL,
    position INTEGER NOT NULL CHECK (position >= 0),
    UNIQUE (program_id, position)
);

CREATE TABLE workout_exercises (
    id UUID PRIMARY KEY,
    workout_day_id UUID NOT NULL REFERENCES workout_days(id),
    exercise_id UUID NOT NULL REFERENCES exercises(id),
    position INTEGER NOT NULL CHECK (position >= 0),
    planned_sets INTEGER NOT NULL CHECK (planned_sets BETWEEN 1 AND 10),
    planned_reps INTEGER NOT NULL CHECK (planned_reps BETWEEN 1 AND 100),
    rest_seconds INTEGER NOT NULL CHECK (rest_seconds BETWEEN 0 AND 600),
    UNIQUE (workout_day_id, position),
    UNIQUE (workout_day_id, exercise_id)
);

CREATE TABLE workout_schedules (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    source_program_id UUID NOT NULL REFERENCES workout_programs(id),
    source_program_revision INTEGER NOT NULL,
    title VARCHAR(150) NOT NULL,
    scheduled_at TIMESTAMPTZ NOT NULL,
    timezone VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'SCHEDULED',
    revision INTEGER NOT NULL DEFAULT 1 CHECK (revision > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (status IN ('SCHEDULED','COMPLETED','MISSED','CANCELLED'))
);

CREATE TABLE scheduled_exercises (
    id UUID PRIMARY KEY,
    schedule_id UUID NOT NULL REFERENCES workout_schedules(id),
    exercise_id UUID NOT NULL REFERENCES exercises(id),
    exercise_name_snapshot VARCHAR(200) NOT NULL,
    position INTEGER NOT NULL CHECK (position >= 0),
    planned_sets INTEGER NOT NULL CHECK (planned_sets BETWEEN 1 AND 10),
    planned_reps INTEGER NOT NULL CHECK (planned_reps BETWEEN 1 AND 100),
    rest_seconds INTEGER NOT NULL CHECK (rest_seconds BETWEEN 0 AND 600),
    UNIQUE (schedule_id, position)
);

CREATE INDEX idx_schedule_user_time
    ON workout_schedules(user_id, scheduled_at);
```

Không tham chiếu trực tiếp lịch tới workout_day nếu bạn định thay toàn bộ các buổi khi PUT giáo án. Source program/revision và snapshot lịch giúp giữ dữ liệu khi chỉnh sửa cấu trúc giáo án. MVP chưa cần xóa giáo án vật lý; giữ bản ghi chương trình đang được lịch tham chiếu.

Khoảng sets/reps/nghỉ là giới hạn kỹ thuật đề xuất, không phải hướng dẫn luyện tập. Với bài giữ tư thế theo giây như Plank, không ép duration thành reps; hôm nay chỉ cho bài có mô hình reps, hoặc thiết kế thêm trackingType/duration trước khi đưa các bài đó vào giáo án. Ghi rõ giới hạn trong UI.

Nếu chọn revision số nguyên thủ công, khi update phải dùng điều kiện revision cũ hoặc khóa ghi để phát hiện sửa đồng thời. Không trộn tăng revision thủ công với JPA @Version trên cùng cột. Có thể dùng @Version thay thế, nhưng sửa schema/API và cách quản lý version nhất quán.

- [ ] Migration chạy thành công.
- [ ] Tối đa một giáo án active/user được bảo vệ ở database.
- [ ] Snapshot không bị cascade xóa khi sửa giáo án.
- [ ] Đã cập nhật ERD và ràng buộc.

## 3. Chuẩn bị giáo án mẫu — 30 phút

Tạo ít nhất một template có 2–3 buổi minh họa. Chọn bài đã có trong thư viện và thuộc mô hình reps hỗ trợ. Số sets/reps/nghỉ cần được rà và ghi là dữ liệu demo.

Nhập qua migration seed kế tiếp hoặc script nội bộ:

1. Tạo chương trình với is_template=true, user_id=null, is_active=false.
2. Tạo buổi và bài theo thứ tự, dùng đúng UUID bài thư viện.
3. Kiểm tra mọi bài trong mẫu đang active và không thiếu.
4. Sao chép template tạo UUID mới cho program/day/exercise row của user, giữ tham chiếu exercise gốc.
5. Sau sao chép, user sửa bản cá nhân mà không thay template.

Nếu admin ẩn bài trong template sau đó, luồng chọn mẫu phải từ chối hoặc báo bài cần thay; không âm thầm bỏ bài rồi báo sao chép thành công.

- [ ] Có template thực tế và nguồn nội dung.
- [ ] Copy tạo bản sở hữu cá nhân.
- [ ] Không có FK hoặc ID mẫu giả.

## 4. API giáo án và quyền sở hữu — 60 phút

Các endpoint dưới đây có tiền tố `/api/v1`, yêu cầu Bearer hợp lệ:

| Method | Endpoint | Hành vi |
|---|---|---|
| GET | `/workout-program-templates` | Danh sách mẫu |
| GET | `/workout-program-templates/{id}` | Chi tiết mẫu |
| POST | `/workout-programs/from-template` | Copy mẫu cho user |
| GET | `/workout-programs` | Danh sách giáo án của mình, phân trang |
| POST | `/workout-programs` | Tạo giáo án custom |
| GET | `/workout-programs/{id}` | Chi tiết thuộc user |
| PUT | `/workout-programs/{id}` | Thay nội dung giáo án cá nhân với revision |
| PUT | `/workout-programs/active` | Đặt giáo án hoạt động |

Request tạo custom:

```json
{
  "name": "Giáo án cá nhân demo",
  "goal": "BUILD_MUSCLE",
  "days": [
    {
      "name": "Buổi A",
      "exercises": [
        {
          "exerciseId": "<uuid-bai-active>",
          "sets": 3,
          "reps": 10,
          "restSeconds": 90
        }
      ]
    }
  ]
}
```

Số liệu chỉ minh họa contract, không phải khuyến nghị cá nhân. POST trả 201, có id/revision và các ID con từ server; PUT trả 200. PUT yêu cầu thêm revision hiện tại; response trả revision mới. Copy mẫu nhận templateId và tên tùy chọn, không nhận userId.

Service tạo/cập nhật:

1. Lấy user từ Authentication.
2. Validate tên, goal, mảng con và giới hạn payload; đề xuất tối đa 7 buổi, 20 bài/buổi cho MVP.
3. Kiểm tra mọi exerciseId tồn tại/active và loại bài được hỗ trợ.
4. Lưu program/day/exercise trong cùng transaction.
5. PUT kiểm tra ownership và revision trước thay đổi; mismatch trả 409.
6. Không nhận userId/isTemplate/isActive tùy ý từ body nội dung giáo án.
7. List/detail riêng tư chỉ truy vấn chương trình thuộc user; đọc template qua endpoint riêng.

Nếu thay toàn bộ ngày/bài khi PUT, xóa row con theo thứ tự FK, flush trước khi insert cùng position hoặc dùng cơ chế update phù hợp để không va unique constraint. Lịch đã có dùng snapshot, không tham chiếu ID con bị thay.

### Đặt active

```http
PUT /api/v1/workout-programs/active
```

```json
{"programId": "<uuid-giao-an-cua-user>"}
```

Khóa hàng user trong transaction để tuần tự hóa các thay đổi active của cùng user, kiểm tra chương trình thuộc user và không phải template, tắt chương trình active cũ rồi flush, bật chương trình mới. Partial unique index là lớp bảo vệ cuối. Không chỉ sửa state Flutter.

- [ ] CRUD nội dung cá nhân hoạt động bằng dữ liệu thật.
- [ ] User A không đọc/sửa/activate giáo án B.
- [ ] Copy không thay template.
- [ ] Revision cũ trả 409, không ghi đè im lặng.
- [ ] Hai request activate đồng thời không để hai bản active.

## 5. API lịch tập và snapshot — 60 phút

| Method | Endpoint | Hành vi |
|---|---|---|
| GET | `/workout-schedules?weekStart=YYYY-MM-DD&timezone=Asia/Ho_Chi_Minh` | Lịch của user trong 7 ngày |
| GET | `/workout-schedules/{id}` | Chi tiết snapshot của lịch |
| POST | `/workout-schedules` | Xếp một buổi giáo án vào ngày giờ |
| PUT | `/workout-schedules/{id}` | Đổi ngày/giờ hoặc ghi chú nếu schema đã hỗ trợ |
| POST | `/workout-schedules/{id}/cancel` | Hủy, giữ bản ghi |

Ví dụ tạo lịch, ngày chỉ minh họa; khi chạy chọn ngày tương lai thực tế:

```json
{
  "programId": "<uuid-giao-an-cua-user>",
  "programRevision": 1,
  "workoutDayId": "<uuid-buoi-thuoc-giao-an>",
  "scheduledAt": "2026-10-29T18:00:00+07:00",
  "timezone": "Asia/Ho_Chi_Minh"
}
```

Backend nhận OffsetDateTime, chuyển Instant lưu TIMESTAMPTZ và lưu timezone riêng. Kiểm tra offset nhất quán với timezone tại thời điểm đó; không lấy timezone mặc định của máy server. Nếu mở rộng tới vùng DST, phải quy định rõ giờ lặp/không tồn tại; offset đã gửi phải là một offset hợp lệ.

Thực hiện trong transaction:

1. Kiểm tra user sở hữu program; buổi thuộc đúng program và revision còn hiện hành.
2. Khóa chương trình theo quy tắc chung với cập nhật để không lấy snapshot trộn hai revision.
3. Kiểm tra bài được phép dùng, ngày giờ hợp lệ.
4. Tạo lịch user hiện tại, sao chép title/bài/sets/reps/nghỉ sang snapshot.
5. Trả 201 kèm snapshot và status SCHEDULED.

Không tin danh sách bài, tên hoặc sets client gửi để lập snapshot từ giáo án. Nếu bài mới bị ẩn, từ chối tạo lịch và báo phải sửa giáo án. Nếu bài bị ẩn sau khi lịch đã tạo, lịch vẫn hiển thị snapshot đã lưu kèm thông tin không còn khả dụng nếu cần; ngày 8 phải chốt cách ghi log cho trường hợp này.

### Lịch tuần

- weekStart là ngày thứ Hai; sai định dạng hoặc không phải thứ Hai trả 400 theo contract đề xuất.
- Tính khoảng thời gian `[đầu ngày weekStart, đầu ngày weekStart + 7)` trong timezone yêu cầu rồi chuyển UTC để query.
- Không dùng `23:59:59` làm mốc cuối vì có thể sót phần giây.
- Kết quả chỉ user hiện tại, sort scheduledAt rồi id.
- Với MVP, giới hạn số lịch tạo trong tuần, ví dụ 50 lịch không hủy, để trả trọn tuần có giới hạn rõ; kiểm tra quota trong transaction có khóa user. Nếu không giới hạn, API cần phân trang và Flutter phải tải đủ trang.

### Sửa, hủy và MISSED

- Sửa giờ không thay snapshot bài; đổi sang buổi khác là tạo lịch mới rồi hủy lịch cũ theo thao tác rõ ràng.
- PUT nhận revision và kiểm tra ownership/trạng thái; xung đột trả 409.
- Hủy SCHEDULED/MISSED chuyển CANCELLED; hủy lại trả trạng thái đã hủy, không tạo dữ liệu mới.
- COMPLETED không được sửa giờ/hủy trong phạm vi MVP; xử lý log ngày 8.
- Quy tắc MISSED đề xuất: sau khi ngày lịch đã kết thúc theo timezone của lịch và chưa hoàn thành, chuyển MISSED khi truy cập lịch. Chỉ chuyển một chiều SCHEDULED→MISSED có điều kiện ở database; không ghi đè COMPLETED do request đồng thời.
- Cho phép đổi MISSED sang giờ tương lai, khi đó chuyển SCHEDULED. Ngày 8 sẽ cho ghi buổi đã tập nhưng nhập muộn từ MISSED theo quy tắc cụ thể; cập nhật use case ngày 2 trước khi triển khai.

### Chống tạo trùng khi mạng lỗi

POST tạo giáo án/copy mẫu/tạo lịch có thể được gửi lại khi người dùng chưa biết kết quả. Dùng Idempotency-Key UUID được tạo cho một thao tác và giữ nguyên khi retry. Backend lưu kết quả theo user + operation + key + hash payload trong cùng transaction, có unique constraint; cùng key khác payload trả 409. Nếu chưa làm cơ chế này, không tự retry POST và phải tải lại kiểm tra trước khi cho gửi lại; ghi rõ giới hạn chưa chống trùng hoàn chỉnh.

- [ ] Lịch chỉ thuộc user, buổi nguồn thuộc giáo án đúng.
- [ ] Có snapshot không đổi sau khi sửa giáo án.
- [ ] Khoảng tuần và timezone đúng.
- [ ] Sửa/hủy kiểm tra trạng thái và revision.
- [ ] Có chính sách chống gửi lặp được kiểm thử hoặc ghi rõ giới hạn.

## 6. Flutter: chọn mẫu, tạo và sửa giáo án — 60–75 phút

```text
lib/features/workout/
├── program/
│   ├── data/
│   ├── application/
│   └── presentation/
└── schedule/
    ├── data/
    ├── application/
    └── presentation/
```

Thứ tự:

1. Danh sách giáo án cá nhân, badge active, loading/rỗng/lỗi.
2. Nút chọn mẫu → xem chi tiết → copy → mở bản cá nhân.
3. Form custom: tên/mục tiêu → thêm buổi → chọn bài từ thư viện ngày 6.
4. Nhập sets/reps/nghỉ với đơn vị rõ ràng và validation.
5. Cho đổi thứ tự bằng nút lên/xuống, chưa cần kéo thả.
6. Lưu toàn bộ cấu trúc một lần; giữ bản nháp trong màn khi lỗi mạng.
7. Chỉnh sửa dùng revision server; 409 thì hướng dẫn tải bản mới, không tự ghi đè.
8. Kích hoạt chương trình chờ response server rồi tải lại danh sách.
9. Thông báo rõ thay đổi chỉ áp cho giáo án, lịch đã tạo được giữ nguyên.

Không tạo ID database bằng index của widget. Dùng key ổn định cho dòng form để xóa/chuyển bài không làm sets/reps nhảy sang dòng khác. Dispose TextEditingController khi xóa dòng hoặc rời màn.

- [ ] Chọn bài bằng ID thật, không nhập tay UUID.
- [ ] Form chặn buổi trống, bài trùng và số không hợp lệ.
- [ ] Copy/sửa không làm thay template.
- [ ] Badge active theo server.
- [ ] Có cảnh báo khi rời form chưa lưu nếu cần.

## 7. Flutter: lịch tuần, xếp lịch và hủy — 60 phút

Không cần thư viện lịch lớn. Có thể dùng 7 ngày từ thứ Hai đến Chủ nhật, nút tuần trước/tuần sau và danh sách các buổi theo ngày.

1. Chọn tuần, tính weekStart theo timezone UI đã thống nhất.
2. GET lịch, nhóm theo ngày hiển thị, không theo ngày UTC.
3. Nhấn thêm lịch → chọn giáo án/buổi → ngày và giờ → xác nhận.
4. Dùng showDatePicker/showTimePicker; nếu người dùng hủy picker thì giữ state cũ.
5. MVP mặc định Asia/Ho_Chi_Minh: ghép local date/time với offset +07:00 và timezone tương ứng. Không nối +07:00 nếu user chọn vùng khác; cần xử lý timezone bằng thư viện thích hợp hoặc giới hạn UI về vùng đã hỗ trợ.
6. Thành công tải lại đúng tuần vừa xếp lịch và hiển thị snapshot.
7. Sửa giờ và hủy có xác nhận, loading và lỗi.
8. Trạng thái COMPLETED chỉ hiển thị nếu có dữ liệu hợp lệ từ workflow log, chưa thêm nút đánh dấu xong hôm nay.

- [ ] Tuần trước/sau và ngày hiện tại hoạt động.
- [ ] Có trạng thái chưa có lịch, mất mạng, thử lại.
- [ ] Lịch không nhảy ngày do UTC.
- [ ] Không gửi lặp khi bấm nhanh.
- [ ] Hủy xong giữ trạng thái CANCELLED theo cách hiển thị đã chốt.
- [ ] Logout/đổi user xóa state giáo án/lịch cá nhân.

## 8. Bộ kiểm thử nghiệm thu — 45–60 phút

| Mã | Tình huống | Kết quả |
|---|---|---|
| W01 | Tạo 2 buổi, mỗi buổi 2 bài | Lưu và đọc lại đúng thứ tự/số liệu |
| W02 | Chọn mẫu rồi sửa bản cá nhân | Mẫu và bản user khác không đổi |
| W03 | Buổi rỗng/bài trùng/sets sai | 400 rõ ràng, rollback toàn bộ |
| W04 | Thêm bài inactive hoặc ID lạ | Từ chối, không lưu một phần |
| W05 | A đọc/sửa/activate giáo án B | 404 theo chính sách tài nguyên riêng tư |
| W06 | Hai activate đồng thời | Tối đa một bản active |
| W07 | Tạo lịch từ buổi thuộc giáo án khác | Bị từ chối |
| W08 | Tạo lịch rồi sửa giáo án | Snapshot lịch cũ không đổi |
| W09 | Tạo lịch với revision giáo án cũ | 409, không tạo snapshot lỗi thời |
| W10 | Lịch sát đầu/cuối tuần | Thuộc đúng khoảng [start,end) |
| W11 | Sửa giờ/hủy lịch A bằng B | Bị từ chối |
| W12 | Cập nhật cùng revision từ hai màn | Có xung đột, không ghi đè im lặng |
| W13 | Idempotency key gửi lại | Không nhân đôi nếu đã triển khai; nếu chưa, ghi giới hạn |
| W14 | Hủy lại lịch đã hủy | Trạng thái nhất quán |
| W15 | MISSED chạy cùng lúc hoàn thành ngày 8 | Thiết kế cập nhật có điều kiện không ghi đè COMPLETED |
| W16 | Quay lại/đổi tuần/mất mạng | UI giữ đúng trạng thái và có thử lại |

W15 là kiểm tra thiết kế hôm nay; chỉ ghi đạt kiểm thử runtime sau khi luồng hoàn thành ngày 8 tồn tại. Không tạo dữ liệu COMPLETED giả để tuyên bố hoàn thành E2E.

Ưu tiên integration test ownership, một active/user, snapshot, transaction và revision trên PostgreSQL test riêng. Unit test khoảng tuần dùng Clock/ngày cố định; không để kết quả phụ thuộc ngày chạy.

Lưu bằng chứng vào `docs/17-day-7-verification.md`, gồm ảnh giáo án, lịch tuần và kết quả API đã che token.

```powershell
# Trong backend với cấu hình database test
.\mvnw.cmd test

# Trong mobile
flutter analyze
flutter test
```

## 9. Lỗi thường gặp

| Lỗi | Kiểm tra |
|---|---|
| Hai giáo án active | Thiếu partial unique index hoặc transaction/khóa user |
| Activate lỗi unique dù đã tắt bản cũ | Hibernate chưa flush update tắt trước bật bản mới |
| Sửa giáo án làm lịch cũ đổi theo | Lịch đang đọc live giáo án, chưa có snapshot |
| PUT lỗi position trùng | Xóa/insert hoặc reorder chưa xử lý constraint đúng thứ tự |
| Chọn buổi A nhưng lưu bài B | Server tin IDs không kiểm tra quan hệ và ownership |
| Lịch lệch một ngày | Nhóm theo UTC thay timezone hiển thị |
| Cuối tuần bị thiếu | Query dùng mốc cuối không chính xác hoặc <= thay khoảng nửa mở |
| Form đổi thứ tự làm số liệu nhảy dòng | Widget key hoặc controller gắn index không ổn định |
| Lưu hai lần tạo hai lịch | Thiếu chống gửi lặp/idempotency và retry chưa kiểm soát |
| MISSED ghi đè trạng thái mới | Update không có điều kiện status SCHEDULED |

## 10. Checklist đóng ngày 7 — 15 phút

- [ ] Có schema giáo án, buổi, bài dự kiến và lịch snapshot.
- [ ] Có ít nhất một mẫu sử dụng bài thật.
- [ ] User tạo, xem và sửa giáo án được.
- [ ] Có tối đa một giáo án active/user.
- [ ] User xếp lịch từ giáo án, sửa giờ và hủy được.
- [ ] Android xem lịch theo tuần đúng timezone.
- [ ] Sửa giáo án không thay lịch cũ.
- [ ] A/B không thao tác dữ liệu của nhau.
- [ ] Có loading, rỗng, lỗi và xử lý revision.
- [ ] Có báo cáo test, giới hạn và công việc chưa xong.

Kiểm tra thay đổi trước commit tại thư mục gốc:

```powershell
git status
git diff
git add .
git diff --cached --stat
git diff --cached
git commit -m "feat: add workout programs and weekly schedules"
```

### Nhật ký cuối ngày

```text
Đường dẫn dự án:
Template và số buổi/bài đã dùng:
Kết quả tạo/sửa/copy giáo án:
Kết quả active và sửa đồng thời:
Kết quả xếp lịch/tuần/timezone:
Kết quả snapshot sau sửa giáo án:
Kết quả phân quyền A/B:
Chính sách chống trùng đã triển khai:
Lỗi/chưa hoàn thành:
Commit:
Việc đầu tiên ngày mai:
```

**Mốc cuối tuần 1:** Demo đăng nhập → hồ sơ → tìm bài → tạo/chọn giáo án → xếp lịch tuần bằng dữ liệu thật. Nếu phần nào chưa chạy, ghi rõ và ưu tiên xử lý trước khi mở thêm tính năng. Ngày 8 triển khai ghi kết quả từng set, lịch sử buổi tập và chuyển lịch sang COMPLETED trong cùng transaction.

## Tài liệu chính thức

- [Spring Data JPA Locking](https://docs.spring.io/spring-data/jpa/reference/3.5/jpa/locking.html): cơ chế khóa repository; dùng nhánh tài liệu khớp dependency thực tế.
- [PostgreSQL 17 Partial Indexes](https://www.postgresql.org/docs/17/indexes-partial.html): cơ sở cho unique index trên giáo án active.
- [Flutter showDatePicker](https://api.flutter.dev/flutter/material/showDatePicker.html): chọn ngày và xử lý kết quả hủy.
