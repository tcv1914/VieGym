# Ngày 2 — Rà soát thiết kế và checklist nghiệm thu

## 1. Rà thiết kế bằng ba tình huống

### Tình huống 1: Thêm 1,5 khẩu phần Phở bò vào bữa sáng

| Câu hỏi | Trả lời | Căn cứ |
|---|---|---|
| App gọi API nào? | `POST /api/v1/meal-plans/entries` với `{date, mealType: "BREAKFAST", foodId, servings: 1.5}` | API §10 |
| Backend lấy dinh dưỡng từ đâu? | Bảng `foods` theo `foodId` (kiểm tra `is_active`); bỏ qua mọi số kcal app gửi | BR-N04 |
| Bản ghi lưu thế nào? | Upsert `meal_plans(user_id, plan_date)`; INSERT `meal_entries` với `servings = 1.50` và snapshot tên, khẩu phần chuẩn, kcal/macro một khẩu phần | DB §6, §9 |
| Dashboard lấy tổng mới ra sao? | `GET /dashboard` tính `SUM(servings × *_per_serving_snapshot)` trên `meal_entries` của ngày; không có bảng tổng riêng nên không lệch | NUT-BR03 |
| Admin sửa món ngày mai, dữ liệu hôm nay có đổi? | Không — tổng tính từ snapshot, không đọc lại `foods` | BR-N05 |

### Tình huống 2: Hoàn thành buổi tập

| Câu hỏi | Trả lời | Căn cứ |
|---|---|---|
| Log chứa bài và set nào? | Bài và set thực tế app gửi (có thể khác kế hoạch, ít nhất 1 bài 1 set), lưu vào `workout_log_exercises` + `workout_set_logs` kèm tên bài snapshot | UC06, BR-W08 |
| Lịch chuyển trạng thái ở bước nào? | Bước cuối của cùng giao dịch `POST /workout-logs`, sau khi INSERT log; lỗi bất kỳ → rollback toàn bộ | BR-W05 |
| Bấm lưu hai lần có tạo trùng? | Không — `SELECT ... FOR UPDATE` trên lịch + UNIQUE `workout_logs.schedule_id`; request thứ hai nhận `409 WORKOUT_ALREADY_LOGGED` kèm `workoutLogId` | BR-W06 |
| Sửa giáo án có đổi lịch sử? | Không — log không tham chiếu `workout_exercises`; buổi bị gỡ được archive, không xóa | BR-W07 |
| `PUT /workout-schedules` có xung đột? | Không — API này không nhận `COMPLETED` | BR-W04 |

### Tình huống 3: Chat AI

| Câu hỏi | Trả lời | Căn cứ |
|---|---|---|
| Backend xác định người hỏi bằng cách nào? | `userId` từ access token; request không có `userId` | BR-G01 |
| Context lấy từ bảng nào? | `health_profiles`, `nutrition_targets`, `meal_plans` + `meal_entries` hôm nay, `workout_logs` gần đây, `workout_schedules` 7 ngày tới, `ai_messages` của hội thoại (≤ 10) | BR-AI03 |
| User khác đọc được hội thoại? | Không — mọi truy vấn lọc `ai_conversations.user_id`; không thuộc user → `404` | AI-BR03, BR-G02 |
| AI timeout, câu hỏi còn không? | Còn — câu hỏi + request `PROCESSING` được commit **trước** khi gọi AI; timeout → `FAILED/AI_TIMEOUT`; app gửi lại cùng `clientRequestId` để thử lại trên cùng câu hỏi | BR-AI05, BR-AI06 |

Cả ba tình huống đều trả lời được từ tài liệu; không cần quay lại sửa.

## 2. Checklist nghiệm thu ngày 2

- [x] Danh sách use case và actor đã chốt — `02-use-cases.md`
- [x] Ba use case trọng tâm có luồng lỗi — UC06, UC07, UC10
- [x] ERD có quan hệ và khóa ngoại — `03-database-design.md` §2
- [x] Có mô tả cột cho các bảng core — `03-database-design.md` §3–7
- [x] Có ràng buộc chống trùng dữ liệu — `03-database-design.md` §8
- [x] Có quy tắc đơn vị, thời gian và tính toán — `04-business-rules.md` §1, §3
- [x] Có cách giữ lịch sử dinh dưỡng/luyện tập — snapshot, `04-business-rules.md` §8
- [x] API core có đầu vào, đầu ra và lỗi — `05-api-contract.md`
- [x] Ba tình huống rà soát đều giải thích được — mục 1
- [x] Tài liệu đã lưu vào Git — commit `8b429b9`

## 3. Việc cần xác nhận

Đã chốt (chuyển sang **[Đã chốt]** trong `04-business-rules.md`):

- [x] Khoảng tuổi hợp lệ 18–80.
- [x] Calories giảm cân (TDEE − 500) và ngưỡng tối thiểu.
- [x] Toàn bộ quy tắc macro (protein g/kg, trần protein 35%, fat 25%).
- [x] Không cho ghi log buổi tập ở ngày tương lai.
- [x] Khoảng ngày cho phép lập thực đơn.
- [x] Con số giới hạn tần suất AI.
- [x] Kênh gửi mã đặt lại mật khẩu (SMTP; dev dùng log/Mailpit).
- [x] Giới hạn đặt lại mật khẩu: tối đa 5 lần sai/mã và 10 yêu cầu/IP/15 phút (BR-A06).

Không còn mục nào chờ xác nhận.

## 4. Nhật ký cuối ngày

```text
Ngày: 2026-10-22
Đã hoàn thành: Use case + actor; thiết kế 20 bảng, ERD, ràng buộc; quy tắc nghiệp vụ và công thức có bộ số kiểm thử; hợp đồng API cho toàn bộ UC01–UC12; rà ba tình huống.
Chưa hoàn thành: Không.
Lỗi/vướng mắc: Repo chưa có SRS nên công thức chốt theo số liệu kich-ban-demo.md (Mifflin‑St Jeor, +300 kcal tăng cơ).
Bằng chứng kiểm tra: Bảng rà soát ba tình huống ở mục 1; bộ số kiểm thử tại 04-business-rules.md §3.7.
Việc đầu tiên ngày mai: Khởi tạo Spring Boot backend, cấu hình Flyway và viết migration V1 theo 03-database-design.md.
```
