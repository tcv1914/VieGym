# Quy tắc nghiệp vụ — VieGym MVP

Ký hiệu: **[Đã chốt]** — quyết định thiết kế MVP; **[Cần xác nhận]** — chưa có căn cứ trong SRS/đề cương, cần giảng viên hướng dẫn hoặc nhóm duyệt trước khi coi là yêu cầu.

## 1. Quy tắc chung

| Mã | Nội dung | Quy tắc |
|---|---|---|
| BR-G01 | Quyền dữ liệu | Backend lấy `userId` từ access token, **không** nhận `userId` từ request. Mọi truy vấn dữ liệu cá nhân lọc theo `user_id` hiện tại. [Đã chốt] |
| BR-G02 | Tài nguyên không thuộc user | Trả `404` như không tồn tại, không tiết lộ sự tồn tại. [Đã chốt] |
| BR-G03 | Thời điểm | Lưu `TIMESTAMPTZ` UTC; API trả ISO‑8601 có `Z`. [Đã chốt] |
| BR-G04 | Ngày nghiệp vụ | Ngày thực đơn, cân nặng, lịch tập là `DATE` theo `users.timezone`; mặc định `Asia/Ho_Chi_Minh`. "Hôm nay" do backend tính theo múi giờ này. [Đã chốt] |
| BR-G05 | Đơn vị | Chiều cao cm, cân nặng/mức tạ kg, năng lượng kcal, macro gram, thời gian nghỉ giây. Không hỗ trợ đổi đơn vị trong MVP. [Đã chốt] |
| BR-G06 | Số thập phân | Lưu `NUMERIC`; tính bằng `BigDecimal` ở backend; làm tròn `HALF_UP` ở bước cuối. API nhận/trả số dạng JSON number, dấu chấm thập phân; app hiển thị theo locale vi‑VN (dấu phẩy). [Đã chốt] |
| BR-G07 | Danh mục | Bài tập, món ăn bị ẩn (`is_active = false`) không xuất hiện trong tìm kiếm của User, không thêm mới được, nhưng vẫn hiển thị trong lịch sử. [Đã chốt] |
| BR-G08 | Tài khoản LOCKED | Không đăng nhập/làm mới phiên được; refresh token hiện có bị thu hồi khi khóa. [Đã chốt] |

## 2. Tài khoản và phiên

| Mã | Quy tắc |
|---|---|
| BR-A01 | Email trim + lowercase trước khi kiểm tra trùng và lưu. Trùng → `409 EMAIL_ALREADY_EXISTS`. |
| BR-A02 | Mật khẩu 8–72 ký tự (giới hạn BCrypt), có ít nhất một chữ cái và một chữ số. |
| BR-A03 | Access token JWT hạn 15 phút; refresh token ngẫu nhiên hạn 30 ngày, lưu hash. |
| BR-A04 | Mỗi lần refresh: thu hồi token cũ, cấp token mới (xoay vòng). Dùng lại token đã thu hồi → thu hồi toàn bộ phiên của user đó. |
| BR-A05 | Đăng nhập sai không nói rõ sai email hay mật khẩu: `401 INVALID_CREDENTIALS`. |
| BR-A06 | Quên mật khẩu luôn trả `204` dù email có tồn tại hay không. Mã đặt lại 6 chữ số, hạn 15 phút, dùng một lần; tạo mã mới vô hiệu mã cũ. Nhập sai tối đa 5 lần/mã, lần thứ 5 vô hiệu mã (`used_at = now()`); `/auth/reset-password` giới hạn thêm 10 yêu cầu/IP/15 phút [Đã chốt]. Đặt lại thành công thu hồi mọi refresh token. |
| BR-A07 | Kênh gửi mã đặt lại: email qua SMTP; môi trường dev ghi ra log/Mailpit. [Đã chốt] [Ngày 13] Dev dùng Mailpit (`infra/compose.yaml`), không ghi mã ra log. Gửi sau khi mã đã commit, ngoài luồng request, thử tối đa 3 lần. |
| BR-A08 | [Ngày 13] `/auth/forgot-password` vượt giới hạn (3/email/giờ hoặc 10/IP/15 phút) vẫn trả `204` nhưng không tạo mã, không gửi. Đặt lại thành công không tự đăng nhập; mọi phiên (cả access token đang dùng) bị thu hồi. |

## 3. Chỉ số sức khỏe và mục tiêu dinh dưỡng

### 3.1 Đầu vào

| Trường | Đơn vị | Hợp lệ |
|---|---|---|
| Giới tính (dùng cho công thức) | — | `MALE`, `FEMALE` |
| Ngày sinh → tuổi | năm tròn, tính tại ngày tính theo múi giờ user | 18–80 [Đã chốt] — công thức Mifflin‑St Jeor áp dụng cho người trưởng thành |
| Chiều cao | cm | 100,0–250,0 |
| Cân nặng | kg | 30,0–300,0 |
| Mức vận động | — | 5 mức ở bảng 3.3 |
| Mục tiêu | — | `LOSE_WEIGHT`, `MAINTAIN`, `GAIN_MUSCLE` |

Thiếu bất kỳ trường nào → `400 VALIDATION_ERROR`, không tính và không lưu hồ sơ dở dang.

### 3.2 Công thức [Đã chốt — khớp số liệu `kich-ban-demo.md`]

```text
BMI  = weight_kg / (height_cm / 100)^2
BMR  = 10 × weight_kg + 6,25 × height_cm − 5 × age + s     (Mifflin‑St Jeor)
       s = +5 (MALE), −161 (FEMALE)
TDEE = BMR × hệ số vận động
```

### 3.3 Hệ số vận động

| Mã | Mô tả | Hệ số |
|---|---|---|
| `SEDENTARY` | Ít vận động | 1,2 |
| `LIGHT` | 1–3 buổi/tuần | 1,375 |
| `MODERATE` | 3–5 buổi/tuần | 1,55 |
| `ACTIVE` | 6–7 buổi/tuần | 1,725 |
| `VERY_ACTIVE` | Lao động nặng/tập 2 lần/ngày | 1,9 |

### 3.4 Calories mục tiêu

| Mục tiêu | Calories mục tiêu | Trạng thái |
|---|---|---|
| `GAIN_MUSCLE` | TDEE + 300 | [Đã chốt] theo kịch bản demo |
| `MAINTAIN` | TDEE | [Đã chốt] |
| `LOSE_WEIGHT` | TDEE − 500 | [Đã chốt] |

Giới hạn dưới: `target_kcal` không thấp hơn `max(BMR, 1.200)` với FEMALE và `max(BMR, 1.500)` với MALE; nếu chạm ngưỡng, API trả cờ `kcalFloorApplied = true` để app giải thích. [Đã chốt]

MVP dùng một giá trị cố định, không trả "khoảng đề xuất".

### 3.5 Macro [Đã chốt]

```text
protein_g = min(hệ số protein × weight_kg, 35% × target_kcal / 4)
            LOSE_WEIGHT 2,0 · MAINTAIN 1,6 · GAIN_MUSCLE 1,8 (g/kg)
fat_g     = 25% × target_kcal / 9
carbs_g   = (target_kcal − protein_g × 4 − fat_g × 9) / 4
```

Trần 35% cho protein đảm bảo carbs luôn ≥ 40% `target_kcal` (100% − 35% − 25%), nên `carbs_g` không âm với mọi đầu vào. Không có trần này, người nặng cân với mục tiêu giảm cân sẽ ra carbs âm (xem ca 2 ở §3.7). Code vẫn giữ kiểm tra `carbs_g < 0` → lỗi `500` nội bộ và ghi log, không lưu mục tiêu âm.

### 3.6 Làm tròn

Tính toàn bộ bằng giá trị chưa làm tròn, chỉ làm tròn khi lưu/hiển thị:

| Chỉ số | Lưu | Hiển thị |
|---|---|---|
| BMI | 2 chữ số thập phân | 2 chữ số (22,49) |
| BMR, TDEE, calories mục tiêu | 1 chữ số | 1 chữ số trong hồ sơ; số nguyên trên dashboard |
| Protein, carbs, fat mục tiêu | 1 chữ số | 1 chữ số |
| Tổng dinh dưỡng thực đơn | Không làm tròn (tính từ `NUMERIC`) | kcal số nguyên, macro 1 chữ số |

### 3.7 Bộ dữ liệu kiểm thử (dùng cho test ngày 5)

Nam, 22 tuổi, 170 cm, 65 kg, `MODERATE`, `GAIN_MUSCLE`:

| Chỉ số | Giá trị thô | Lưu |
|---|---|---|
| BMI | 22,4913… | 22,49 |
| BMR | 1.607,5 | 1.607,5 |
| TDEE | 2.491,625 | 2.491,6 |
| Calories mục tiêu | 2.791,625 | 2.791,6 |
| Protein | 117 | 117,0 |
| Fat | 77,545… | 77,5 |
| Carbs | 406,429… | 406,4 |

Ca 2 — biên trần protein: Nữ, 80 tuổi, 100 cm, 300 kg, `SEDENTARY`, `LOSE_WEIGHT`:

| Chỉ số | Giá trị thô | Lưu |
|---|---|---|
| BMI | 300 | 300,00 |
| BMR | 3.064 | 3.064,0 |
| TDEE | 3.676,8 | 3.676,8 |
| Calories mục tiêu | 3.176,8 (không chạm ngưỡng dưới) | 3.176,8 |
| Protein | min(600; 277,97) = 277,97 | 278,0 |
| Fat | 88,244… | 88,2 |
| Carbs | 317,68 | 317,7 |

### 3.8 Cập nhật hồ sơ và mục tiêu

| Mã | Quy tắc |
|---|---|
| BR-H01 | Lưu hồ sơ (`PUT /health-profile/me`) → tính lại và ghi `nutrition_targets` trong cùng giao dịch. |
| BR-H02 | Ghi cân nặng mới (`weight_logs`) **không** tự đổi `health_profiles.weight_kg` hay mục tiêu. App hỏi "Cập nhật hồ sơ và tính lại mục tiêu?"; chỉ khi user xác nhận mới gọi `PUT /health-profile/me`. |
| BR-H03 | Mục tiêu chỉ lưu bản hiện tại; so sánh thực đơn cũ dùng mục tiêu hiện tại (NUT-BR09). |
| BR-H04 | Mục tiêu chỉ tính lại khi user lưu hồ sơ (`PUT /health-profile/me`). **Hạn chế MVP:** tuổi trong công thức tăng theo thời gian nhưng mục tiêu không tự cập nhật, nên sau sinh nhật user có thể thấy mục tiêu lệch nhẹ (BMR giảm 5 kcal/năm tuổi) cho đến khi lưu lại hồ sơ. |

## 4. Luyện tập

| Mã | Quy tắc |
|---|---|
| BR-W01 | Mỗi user tối đa một giáo án `is_active` (DB partial UNIQUE). Kích hoạt giáo án mới tự tắt giáo án cũ trong cùng giao dịch. |
| BR-W02 | Chọn giáo án mẫu = sao chép thành giáo án của user. |
| BR-W03 | Lịch chỉ tạo từ `workout_day` thuộc giáo án của chính user, chưa archived. |
| BR-W04 | Chuyển trạng thái lịch: `SCHEDULED → CANCELLED` qua `PUT /workout-schedules/{id}`; `SCHEDULED → COMPLETED` **chỉ** qua `POST /workout-logs`. `COMPLETED`, `CANCELLED` là trạng thái cuối. |
| BR-W05 | Hoàn thành buổi tập: khóa dòng lịch, tạo log + bài + set, đổi lịch sang COMPLETED trong một giao dịch (WO-BR03). |
| BR-W06 | Gửi lặp: lịch đã COMPLETED hoặc vi phạm UNIQUE `schedule_id` → `409 WORKOUT_ALREADY_LOGGED` kèm `workoutLogId` để app mở log hiện có. |
| BR-W07 | Sửa giáo án: thay thế danh sách buổi/bài. Buổi bị gỡ mà còn lịch tham chiếu thì archive (`archived_at`) thay vì xóa; lịch `SCHEDULED` của buổi bị gỡ vẫn tập được theo bài hiện có của buổi đó. Log cũ không bị ảnh hưởng nhờ snapshot. |
| BR-W08 | Ghi log: `reps` 1–1000, `weightKg` 0–999,99, ít nhất 1 bài và 1 set; `setNo`/`orderNo` liên tục từ 1 do backend đánh lại theo thứ tự gửi lên. Cho phép bài ngoài kế hoạch nhưng phải là bài đang hoạt động. [Ngày 8] Bài **trong buổi** của lịch vẫn ghi được dù đã bị ẩn sau khi xếp lịch; một bài không lặp trong cùng log; `weightKg` bắt buộc (bỏ trống ≠ 0), tối đa 2 số lẻ; `startedAt`/`endedAt` không ở tương lai, ≤ 24 giờ (docs/18 §2). |
| BR-W09 | Không cho ghi log cho lịch có `scheduled_date` ở tương lai (theo múi giờ user). [Đã chốt] |

## 5. Dinh dưỡng

| Mã | Quy tắc |
|---|---|
| BR-N01 | Dinh dưỡng của món định nghĩa trên một khẩu phần chuẩn (`serving_size` + `serving_unit`). |
| BR-N02 | `servings` > 0, ≤ 20, tối đa 2 chữ số thập phân (0,5; 1,5; 0,25). |
| BR-N03 | Dinh dưỡng mục = `servings × *_per_serving_snapshot`; tổng ngày = tổng các mục (NUT-BR02, 03). |
| BR-N04 | App không gửi kcal/macro; nếu gửi, backend bỏ qua. |
| BR-N05 | Snapshot chụp lúc thêm; sửa `servings` không cập nhật snapshot. Đổi món = xóa mục và thêm mục mới. |
| BR-N06 | Thực đơn tạo tự động khi thêm món đầu tiên của ngày; xóa hết món không xóa `meal_plans`. |
| BR-N07 | Cho phép ghi thực đơn cho ngày quá khứ và tối đa 7 ngày tới. [Đã chốt] |

## 6. Cân nặng

| Mã | Quy tắc |
|---|---|
| BR-WL01 | Một bản ghi/user/ngày; `POST /weight-logs` cùng ngày → cập nhật bản ghi hiện có, trả `200` (tạo mới trả `201`). |
| BR-WL02 | Không ghi cho ngày tương lai. |
| BR-WL03 | [Ngày 13] Xóa bản ghi qua `DELETE /weight-logs/{id}`; bản ghi của user khác → `404`. Ghi/sửa/xóa không đổi hồ sơ (BR-H02). Gửi lại cùng ngày thay cả `weightKg` và `note`. |

## 7. AI Coach

| Mã | Quy tắc |
|---|---|
| BR-AI01 | AI chỉ tư vấn; không có API nào để AI tự ghi dữ liệu nghiệp vụ (AI-BR09). |
| BR-AI02 | Request gồm `message`, `clientRequestId`, `conversationId` (tùy chọn). Context do backend tự lấy (AI-BR06). |
| BR-AI03 | Context gửi đi: hồ sơ + mục tiêu, thực đơn hôm nay + tổng, tối đa 5 log tập gần nhất, lịch 7 ngày tới, tối đa 10 tin nhắn gần nhất của hội thoại. Không gửi email, tên đầy đủ, token. |
| BR-AI04 | Giới hạn: câu hỏi ≤ 2.000 ký tự; timeout gọi AI 30 giây; tối đa 5 câu hỏi/phút và 50 câu hỏi/ngày/user. [Đã chốt] |
| BR-AI05 | Luồng lưu: (1) lưu câu hỏi + request `PROCESSING` và commit; (2) gọi `ai-service` ngoài giao dịch; (3) lưu phản hồi + `SUCCEEDED`, hoặc `FAILED` + `error_code`. Câu hỏi không bao giờ mất khi AI lỗi. |
| BR-AI06 | Gửi lặp cùng `clientRequestId`: `SUCCEEDED` → trả lại kết quả cũ; `PROCESSING` → `409 AI_REQUEST_IN_PROGRESS`; `FAILED` → thử lại trên cùng tin nhắn câu hỏi (`attempt_count + 1`), không tạo câu hỏi mới. |
| BR-AI07 | Request `PROCESSING` quá 2 phút (ví dụ server khởi động lại) được coi là `FAILED / AI_TIMEOUT`. |
| BR-AI08 | Phản hồi rỗng/không hợp lệ → `FAILED / AI_EMPTY_RESPONSE`; không lưu tin nhắn ASSISTANT. |
| BR-AI09 | Câu hỏi về bệnh lý/chấn thương: system prompt yêu cầu không chẩn đoán, khuyên dừng bài gây đau và gặp chuyên gia y tế (AI-BR05). |
| BR-AI10 | Vượt giới hạn tần suất → `429 RATE_LIMITED`, không gọi AI, không lưu câu hỏi. |

[Ngày 12, docs/27] Bổ sung khi cài đặt: mỗi hội thoại chỉ một câu chờ AI (câu khác → `409 AI_REQUEST_IN_PROGRESS`); 5 lần/phút tính cả lần thử lại, 50 câu/ngày chỉ tính câu mới theo múi giờ user; BR-AI07 kiểm tra lười khi có request/đọc lịch sử, không có job nền; cùng `clientRequestId` khác nội dung → `409 CLIENT_REQUEST_ID_REUSED`; `AI_ENABLED=false` → `503 AI_DISABLED`.

## 8. Bảo toàn dữ liệu lịch sử

- Thực đơn: snapshot dinh dưỡng trong `meal_entries` (BR-N05).
- Luyện tập: log lưu tên bài, reps, mức tạ thực tế; không tham chiếu `workout_exercises` (BR-W07).
- Danh mục: ẩn thay vì xóa (BR-G07); FK `RESTRICT` chặn xóa cứng món/bài đang được tham chiếu.
- Hội thoại AI: không có API xóa trong MVP.

## 9. Quản trị (UC12) [Ngày 14, docs/31]

| Mã | Quy tắc |
|---|---|
| BR-AD01 | Mọi `/api/v1/admin/**` yêu cầu `role = ADMIN` đọc từ DB ở mỗi request; chưa đăng nhập `401`, USER `403 FORBIDDEN`. Không có API nâng vai trò hay đăng ký ADMIN; admin tạo từ biến môi trường máy chủ, không tự nâng quyền email USER có sẵn. |
| BR-AD02 | Admin không đọc hồ sơ sức khỏe, thực đơn, nhật ký tập, cân nặng hay hội thoại AI của user (không có API). |
| BR-AD03 | Sửa món/bài phải gửi `revision` đang xem; khác hiện tại → `409 VERSION_CONFLICT` + `currentRevision`. Lưu không đổi gì thì không tăng revision. |
| BR-AD04 | Không xóa món/bài: ẩn bằng `active = false` (BR-G07). Sửa danh mục không cập nhật snapshot thực đơn hay nhật ký đã ghi. |
| BR-AD05 | Món chỉ được hiển thị khi đủ nhãn khẩu phần, nguồn, mức tin cậy và kcal lệch ≤ 15% so với 4P + 4C + 9F (cùng ngưỡng seed, docs/20 §4; kcal = P = C = F = 0 hợp lệ). URL ảnh/nguồn chỉ `http(s)`; media bài tập là URL `http(s)` hoặc tệp tĩnh có sẵn `exercises/<tệp>`. |
| BR-AD06 | Chỉ khóa/mở tài khoản USER, không tự khóa mình; khóa phải có lý do. Khóa: đổi trạng thái + thu hồi mọi phiên và refresh token + audit trong một giao dịch (BR-G08). Mở khóa không phục hồi phiên cũ. |
| BR-AD07 | Mọi thay đổi của admin ghi `admin_audit_logs` trong cùng giao dịch; chỉ lưu tên trường đổi, không lưu mật khẩu, token hay giá trị dữ liệu cá nhân. |
