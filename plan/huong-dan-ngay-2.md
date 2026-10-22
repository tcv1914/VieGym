# VieGym — Ngày 2: Thiết kế use case, database và API

Ngày 2 chốt thiết kế trước khi viết chức năng: người dùng thao tác gì, dữ liệu lưu ở đâu và app gọi API như thế nào.

**Thời lượng:** 6–8 giờ. Thực hiện trong thư mục VieGym đã chuẩn bị ở ngày 1.

Tạo 5 tài liệu:

```text
docs/
├── 02-use-cases.md
├── 03-database-design.md
├── 04-business-rules.md
├── 05-api-contract.md
└── 06-day-2-checklist.md
```

Nếu tài liệu đã tồn tại, bổ sung nội dung vào bản hiện có. Chưa cần tạo bảng database hoặc viết controller hôm nay; thống nhất thiết kế đủ rõ để ngày 3 khởi tạo đúng.

## Bước 1 — Chốt use case và quyền truy cập

**Thời gian:** 60 phút.

Trong `02-use-cases.md`, lập bảng:

| Mã | Người thực hiện | Chức năng | Điều kiện/kết quả chính |
|---|---|---|---|
| UC01 | Khách | Đăng ký, đăng nhập | Tạo tài khoản và bắt đầu phiên |
| UC02 | User | Quản lý hồ sơ sức khỏe | Lưu hồ sơ, tính chỉ số và mục tiêu |
| UC03 | User | Xem thư viện bài tập | Tìm kiếm, lọc và xem hướng dẫn |
| UC04 | User | Tạo/chỉnh sửa giáo án | Chọn bài, sets, reps, thời gian nghỉ |
| UC05 | User | Quản lý lịch tập | Tạo, sửa, hủy, xem lịch |
| UC06 | User | Ghi nhận buổi tập | Lưu từng set và xem lịch sử |
| UC07 | User | Lập thực đơn | Thêm/sửa/xóa món, tính tổng dinh dưỡng |
| UC08 | User | Theo dõi cân nặng | Ghi nhận theo ngày, xem lịch sử |
| UC09 | User | Xem dashboard | Tổng hợp sức khỏe, ăn uống, luyện tập |
| UC10 | User | Chat với AI | Phản hồi theo ngữ cảnh, lưu hội thoại |
| UC11 | User | Đặt lại mật khẩu | Đổi mật khẩu qua mã/liên kết hợp lệ |
| UC12 | Admin | Quản trị dữ liệu | Quản lý món ăn, bài tập và tài khoản |

Sau bảng, mô tả chi tiết 3 use case quan trọng nhất: ghi buổi tập, lập thực đơn và chat AI.

Mỗi use case dùng cấu trúc:

```text
Mã và tên:
Actor:
Tiền điều kiện:
Dữ liệu đầu vào:
Luồng thành công:
Luồng lỗi:
Dữ liệu được lưu:
Hậu điều kiện:
Tiêu chí nghiệm thu:
```

Ví dụ lập thực đơn:

1. User chọn ngày và bữa ăn.
2. Tìm món đang hoạt động.
3. Nhập số khẩu phần lớn hơn 0.
4. Backend lấy dinh dưỡng chuẩn của món, tính theo khẩu phần.
5. Lưu món vào thực đơn thuộc user hiện tại.
6. Trả thực đơn với tổng dinh dưỡng mới.

Luồng lỗi: món không tồn tại/inactive, khẩu phần sai, người dùng không có quyền.

- [ ] Có danh sách use case.
- [ ] Phân biệt Guest, User và Admin.
- [ ] Ba use case trọng tâm có luồng thành công và lỗi.
- [ ] Mỗi use case có tiêu chí kiểm tra được.

## Bước 2 — Thiết kế database theo từng nhóm

**Thời gian:** 120 phút.

Trong `03-database-design.md`, bắt đầu bằng các bảng sau. Đây là đề xuất thiết kế MVP; điều chỉnh sau khi đối chiếu code hiện có.

| Nhóm | Bảng | Nội dung chính |
|---|---|---|
| Tài khoản | `users` | Email, mật khẩu hash, tên, role, trạng thái |
| Phiên | `refresh_tokens` | Hash token, chủ sở hữu, hạn dùng, thời điểm thu hồi |
| Khôi phục | `password_reset_tokens` | Hash mã/token, hạn dùng, trạng thái sử dụng |
| Sức khỏe | `health_profiles` | Ngày sinh, chiều cao, cân nặng, mức vận động, mục tiêu |
| Mục tiêu | `nutrition_targets` | Calories, protein, carb, fat hiện tại |
| Cân nặng | `weight_logs` | Ngày đo, cân nặng, ghi chú |
| Bài tập | `exercises` | Tên, nhóm cơ, thiết bị, độ khó, hướng dẫn, media |
| Giáo án | `workout_programs` | Tên, user sở hữu, trạng thái hoạt động |
| Buổi mẫu | `workout_days` | Buổi tập thuộc giáo án |
| Bài trong buổi | `workout_exercises` | Bài tập, thứ tự, sets, reps, nghỉ |
| Lịch | `workout_schedules` | Ngày giờ, buổi dự kiến, trạng thái |
| Nhật ký | `workout_logs` | Ngày tập, user, lịch liên quan, ghi chú |
| Bài đã tập | `workout_log_exercises` | Bài thực tế trong buổi tập |
| Set đã tập | `workout_set_logs` | Số thứ tự set, reps, mức tạ |
| Món ăn | `foods` | Khẩu phần chuẩn, kcal, macro, nguồn dữ liệu |
| Thực đơn | `meal_plans` | User và ngày |
| Món trong bữa | `meal_entries` | Món, loại bữa, số khẩu phần, dinh dưỡng đã chốt |
| Hội thoại | `ai_conversations` | User sở hữu, tiêu đề, thời điểm |
| Tin nhắn | `ai_messages` | Hội thoại, vai trò, nội dung, trạng thái |

Vẽ các quan hệ chính bằng công cụ quen dùng:

```text
User → HealthProfile               1–1
User → NutritionTarget             1–1
User → WeightLog                   1–n
User → WorkoutProgram              1–n
WorkoutProgram → WorkoutDay        1–n
WorkoutDay → WorkoutExercise       1–n
Exercise → WorkoutExercise         1–n

User → WorkoutSchedule             1–n
User → WorkoutLog                  1–n
WorkoutSchedule → WorkoutLog       1–0..1
WorkoutLog → WorkoutLogExercise    1–n
WorkoutLogExercise → WorkoutSetLog 1–n

User → MealPlan                    1–n
MealPlan → MealEntry               1–n
Food → MealEntry                   1–n

User → AiConversation              1–n
AiConversation → AiMessage         1–n
```

Với mỗi bảng, ghi tên cột, kiểu dữ liệu, bắt buộc, khóa ngoại và ràng buộc. Ví dụ:

| Cột `meal_entries` | Kiểu đề xuất | Quy tắc |
|---|---|---|
| `id` | UUID | Khóa chính |
| `meal_plan_id` | UUID | Bắt buộc, liên kết thực đơn |
| `food_id` | UUID | Bắt buộc, liên kết món |
| `meal_type` | VARCHAR | BREAKFAST/LUNCH/DINNER/SNACK |
| `servings` | NUMERIC | Lớn hơn 0 |
| `food_name_snapshot` | VARCHAR | Tên món lúc ghi nhận |
| `kcal_per_serving_snapshot` | NUMERIC | Kcal một khẩu phần lúc ghi nhận |
| `protein_per_serving_snapshot` | NUMERIC | Protein một khẩu phần |
| `carbs_per_serving_snapshot` | NUMERIC | Carb một khẩu phần |
| `fat_per_serving_snapshot` | NUMERIC | Fat một khẩu phần |

**Vì sao cần snapshot?** Khi admin sửa dinh dưỡng món ăn, thực đơn cũ phải giữ số liệu đã ghi nhận. Nhật ký tập cũng cần giữ sets/reps/mức tạ thực tế, độc lập với giáo án được sửa sau này.

Các ràng buộc cần chốt:

- [ ] Email chuẩn hóa có giá trị duy nhất.
- [ ] Một hồ sơ sức khỏe/user.
- [ ] Một thực đơn/user/ngày.
- [ ] Một cân nặng chính/user/ngày.
- [ ] Một workout log gắn với một lịch tập trong phạm vi MVP.
- [ ] Chọn `NUMERIC` và quy tắc làm tròn cho dữ liệu cần tính tổng chính xác.
- [ ] Các bảng chính có thời điểm tạo/cập nhật.
- [ ] Bài tập, món ăn được ẩn thay vì xóa dữ liệu đang được tham chiếu.

**Nghiệm thu:** Giải thích được dữ liệu ghi vào bảng nào khi hoàn thành buổi tập hoặc thêm món ăn.

## Bước 3 — Chốt quy tắc nghiệp vụ

**Thời gian:** 60 phút.

Trong `04-business-rules.md`, ghi các quyết định:

| Nội dung | Quy tắc đề xuất cho MVP |
|---|---|
| Quyền dữ liệu | Backend lấy user từ phiên đăng nhập; kiểm tra quyền sở hữu ở mọi thao tác |
| Ngày/thời gian | Thời điểm lưu theo UTC; ngày thực đơn và cân nặng xác định theo múi giờ user |
| Múi giờ mặc định | `Asia/Ho_Chi_Minh` |
| Khẩu phần | Dinh dưỡng định nghĩa trên một khẩu phần chuẩn; số khẩu phần có thể là số thập phân |
| Tổng dinh dưỡng | Tính từ dữ liệu món trong bữa ở backend; làm tròn khi hiển thị |
| Giáo án | Một giáo án đang hoạt động/user trong MVP |
| Hoàn thành buổi tập | Lưu log và chuyển lịch sang COMPLETED trong cùng giao dịch |
| Gửi lặp | Không tạo hai workout log cho cùng lịch tập |
| Cân nặng | Nhập lại cùng ngày cập nhật bản ghi hiện có |
| Cập nhật mục tiêu | Tính lại mục tiêu từ cân nặng mới cần hành động xác nhận rõ ràng |
| AI | Chỉ tư vấn; chưa tự động thay đổi thực đơn hoặc lịch |
| Lỗi AI | Lưu câu hỏi, hiển thị lỗi và cho thử lại |

Với tính sức khỏe, chốt cách triển khai theo công thức trong SRS:

- Đầu vào và đơn vị.
- Công thức áp dụng.
- Hệ số vận động.
- Quy tắc chọn calories trong khoảng đề xuất.
- Quy tắc tính macro.
- Xử lý thiếu dữ liệu hoặc trường hợp công thức chưa bao phủ.
- Số chữ số hiển thị.

Không để đến lúc code mới quyết định. Quy tắc chưa có cơ sở trong SRS cần ghi “cần xác nhận”, thay vì tự xem là yêu cầu đã duyệt.

- [ ] Đơn vị và cách làm tròn thống nhất.
- [ ] Quy tắc dinh dưỡng đủ rõ để viết test ngày 5.
- [ ] Có quy tắc bảo toàn dữ liệu lịch sử.
- [ ] Có xử lý thao tác gửi lặp.
- [ ] Có quy tắc lỗi AI và quyền sở hữu dữ liệu.

## Bước 4 — Viết hợp đồng API

**Thời gian:** 90 phút.

Trong `05-api-contract.md`, dùng tiền tố `/api/v1`:

| Nhóm | Endpoint |
|---|---|
| Auth | `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout` |
| Hồ sơ | `GET/PUT /health-profile/me` |
| Cân nặng | `GET/POST /weight-logs` |
| Bài tập | `GET /exercises`, `GET /exercises/{id}` |
| Giáo án | `GET/POST /workout-programs`, `GET/PUT /workout-programs/{id}` |
| Lịch tập | `GET/POST /workout-schedules`, `PUT /workout-schedules/{id}` |
| Workout log | `POST /workout-logs`, `GET /workout-logs`, `GET /workout-logs/{id}` |
| Món ăn | `GET /foods`, `GET /foods/{id}` |
| Thực đơn | `GET /meal-plans?date=YYYY-MM-DD` |
| Món trong bữa | `POST /meal-plans/entries`, `PUT/DELETE /meal-plans/entries/{id}` |
| Dashboard | `GET /dashboard?date=YYYY-MM-DD` |
| AI | `POST /ai/coach/chat`, `GET /ai/conversations`, `GET /ai/conversations/{id}/messages` |

Không chỉ liệt kê đường dẫn. Mỗi API ghi:

```text
Method và URL:
Quyền truy cập:
Query/path parameters:
Request JSON:
Response JSON:
HTTP status:
Validation:
Lỗi có thể xảy ra:
```

Ví dụ thêm món:

```http
POST /api/v1/meal-plans/entries
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{
  "date": "2026-10-20",
  "mealType": "LUNCH",
  "foodId": "uuid-cua-mon-an",
  "servings": 1.5
}
```

Backend tự xác định chủ sở hữu từ token, tính dinh dưỡng từ dữ liệu server. App không gửi `userId` hoặc số kcal để backend tin và lưu trực tiếp. Ngày trong ví dụ là dữ liệu minh họa.

Thống nhất lỗi:

```json
{
  "code": "VALIDATION_ERROR",
  "message": "Dữ liệu không hợp lệ",
  "fieldErrors": {
    "servings": "Số khẩu phần phải lớn hơn 0"
  }
}
```

| Mã | Sử dụng |
|---|---|
| `200` | Đọc/cập nhật thành công |
| `201` | Tạo thành công |
| `204` | Xóa/đăng xuất thành công, không có body |
| `400` | Dữ liệu sai |
| `401` | Chưa xác thực hoặc token không hợp lệ |
| `403` | Đã xác thực nhưng thiếu quyền chức năng |
| `404` | Không tìm thấy; có thể dùng cho tài nguyên không thuộc user để tránh tiết lộ sự tồn tại |
| `409` | Xung đột dữ liệu, ví dụ email đã tồn tại |

Với danh sách, thống nhất phân trang và bộ lọc:

```http
GET /api/v1/exercises?page=0&size=20&keyword=squat
```

- [ ] Mỗi chức năng core có API tương ứng.
- [ ] API quan trọng có request/response mẫu.
- [ ] Có validation và mã lỗi.
- [ ] Danh sách có phân trang.
- [ ] API AI chỉ nhận câu hỏi và định danh hội thoại; context do backend lấy.
- [ ] Cách hoàn thành lịch tập không xung đột với tạo workout log.

## Bước 5 — Rà thiết kế bằng ba tình huống

**Thời gian:** 45 phút.

Thử “chạy bằng giấy” trước khi code.

### Tình huống 1: Thêm 1,5 khẩu phần món ăn

- App gọi API nào?
- Backend lấy giá trị dinh dưỡng từ đâu?
- Bản ghi được lưu thế nào?
- Dashboard lấy tổng mới ra sao?
- Nếu admin sửa món ngày mai, dữ liệu hôm nay có đổi không?

### Tình huống 2: Hoàn thành buổi tập

- Log chứa những bài và set nào?
- Lịch chuyển trạng thái ở bước nào?
- Bấm lưu hai lần có tạo trùng không?
- Sửa giáo án sau đó có làm thay đổi lịch sử không?

### Tình huống 3: Chat AI

- Backend xác định người đang hỏi bằng cách nào?
- Context lấy từ những bảng nào?
- User khác có đọc được hội thoại không?
- Nếu AI timeout, câu hỏi có còn và thử lại được không?

Nếu chưa trả lời được, quay lại sửa tài liệu liên quan.

## Checklist nghiệm thu ngày 2

Đưa danh sách vào `06-day-2-checklist.md`:

- [ ] Danh sách use case và actor đã chốt.
- [ ] Ba use case trọng tâm có luồng lỗi.
- [ ] ERD có quan hệ và khóa ngoại.
- [ ] Có mô tả cột cho các bảng core.
- [ ] Có ràng buộc chống trùng dữ liệu.
- [ ] Có quy tắc đơn vị, thời gian và tính toán.
- [ ] Có cách giữ lịch sử dinh dưỡng/luyện tập.
- [ ] API core có đầu vào, đầu ra và lỗi.
- [ ] Ba tình huống rà soát đều giải thích được.
- [ ] Tài liệu đã lưu vào Git.

## Mẫu nhật ký cuối ngày

```text
Ngày:
Đã hoàn thành:
Chưa hoàn thành:
Lỗi/vướng mắc:
Bằng chứng kiểm tra:
Việc đầu tiên ngày mai:
```

Bắt đầu bằng Bước 1: hoàn thành bảng use case và ba luồng trọng tâm. Chỉ chuyển sang khởi tạo chức năng ở ngày tiếp theo khi các quyết định thiết kế quan trọng đã rõ.
