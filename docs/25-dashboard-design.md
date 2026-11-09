# Dashboard cá nhân — thiết kế ngày 11

UC09. API: `05-api-contract.md` §11. Wireframe: `07-ui-wireframes.md` §3.3. Kết quả kiểm tra: `26-day-11-verification.md`. Không có migration mới.

## 1. Khác với plan ngày 11

Như ngày 5–10, dự án **giữ quyết định ngày 2** (shape response docs/05 §11) và chỉ bổ sung phần còn thiếu.

| Điểm | Plan ngày 11 | Áp dụng |
|---|---|---|
| Số docs | `24-dashboard-contract.md`, `25-day-11-verification.md` | docs/24 đã dùng cho kiểm tra ngày 10 → **docs/25** (thiết kế), **docs/26** (kiểm tra) |
| Shape | `profileStatus`, `nutrition.consumedCalories/targetCalories/...`, `workouts`, `body` | Giữ nhóm của docs/05: `health`, `nutrition`, `training` |
| Mục tiêu | `targetSource` SNAPSHOT/PREVIEW | Không có snapshot (NUT-BR09, docs/23 §1): luôn **mục tiêu hiện tại**, kèm `targetsCalculatedAt` |
| Thiếu hồ sơ | `body=null`, `profileStatus=MISSING` | `health.hasProfile=false`, các trường còn lại `null` (đã có trong docs/05) |
| Cân nặng | Health profile; ngày 13 nối weight logs | Như plan: `health.weightKg` lấy từ hồ sơ; `latestWeightLog` luôn `null` tới ngày 13 |
| Buổi tiếp theo | `next` | Thêm `training.next` (docs/05 chưa có) |
| Tuần | `weeklyCompleted/weeklyScheduled` | `training.week` của docs/05 (`scheduled`, `completed`, `cancelled`) + `from`/`to` |
| Thêm so với docs/05 | — | `timezone`, `generatedAt`, `health.heightCm`, `nutrition.entryCount`/`remaining`/`targetsCalculatedAt`, `training.today[].scheduledDate/startTime/programName` |

## 2. Quy tắc

| Nội dung | Quy tắc |
|---|---|
| Người dùng | Chỉ người trong token; không nhận `userId` (tham số lạ bị bỏ qua) |
| Ngày | `date` tùy chọn, mặc định hôm nay theo `users.timezone` (BR-G04). Ngoài 2000-01-01..2099-12-31 hoặc sai định dạng → 400 |
| Dinh dưỡng | Lấy nguyên kết quả `MealPlanService.get` (docs/23 §3): cùng phép cộng BigDecimal, cùng làm tròn. Chưa có mục tiêu → `targets`/`remaining` = `null`, không 0 giả. `remaining` âm = vượt |
| Lịch ngày | Mọi lịch của `date` kể cả CANCELLED (app gạch ngang), kèm `workoutLogId` khi COMPLETED |
| Tuần | Thứ Hai–Chủ nhật chứa `date`. `scheduled` = số lịch **không hủy** (mẫu số); `completed` = số lịch COMPLETED; `cancelled` chỉ để hiển thị. `scheduled = 0` → app ghi "chưa có lịch", không chia 0 |
| Ghi muộn | Tiến độ tính theo `scheduled_date` của lịch; lịch sử buổi tập (ngày 8) tính theo ngày tập thực tế |
| Buổi tiếp theo | Lịch SCHEDULED sớm nhất trong [hôm nay, hôm nay + 29] theo **hôm nay thực**, không theo `date` đang xem. Lịch hôm nay đã qua giờ vẫn tính (chưa hoàn thành) |
| Cơ thể | `weightKg`, `heightCm`, `goal` từ hồ sơ; `bmi` từ `nutrition_targets` (đã tính ngày 5). App không diễn giải BMI thành chẩn đoán |
| Không tính | "Calories đã đốt" (chưa có mô hình kiểm chứng); gợi ý AI (ngày 12) |

## 3. Tổng hợp

```text
DashboardService.get  @Transactional(readOnly, REPEATABLE_READ)
  1. users → timezone → today; date mặc định
  2. health      : health_profiles + nutrition_targets theo user
  3. nutrition   : MealPlanService.get(user, date)             (truy vấn riêng)
  4. training    : WorkoutScheduleService.list(user, tuần, null)  → today + week
                   WorkoutScheduleService.list(user, today..+29, SCHEDULED).first → next
```

- Không viết lại công thức: tái dùng service ngày 5/7/10, các service con tham gia cùng giao dịch.
- Mỗi nhóm truy vấn riêng rồi mới ghép — không JOIN `meal_entries` với lịch/log nên không nhân dòng (test D09: 3 món + 2 buổi × 6 hiệp vẫn đúng 500 kcal, 2/2).
- REPEATABLE READ chỉ đọc: PostgreSQL dùng một snapshot cho cả request, các khối không lệch nhau khi có ghi song song. Giao dịch chỉ đọc không gây lỗi tuần tự hóa.
- Không cache phía server. GET không tạo thực đơn hay sửa mục tiêu.

## 4. App

```text
lib/features/dashboard/
├── data/         dashboard_api.dart, dashboard_models.dart
├── application/  dashboard_providers.dart (dashboardDateProvider, dashboardProvider)
└── presentation/ dashboard_page.dart
lib/app/home_tab.dart   (HomeTab, homeTabProvider)
```

- Tab mới **"Tổng quan"** đứng đầu (7 tab; nhãn chỉ hiện ở tab đang chọn). Sau đăng nhập mở ở Tổng quan.
- Thanh ngày giống Thực đơn (‹ ngày ›, chọn ngày, "Hôm nay"); xem tới 365 ngày tới.
- Thẻ dinh dưỡng: kcal số nguyên "645 / 2.792 kcal", thanh tiến độ tối đa 100%, "Còn lại"/"Vượt" (màu lỗi), đạm/bột đường/béo 1 chữ số. Chưa ăn → "Chưa ghi nhận bữa ăn nào trong ngày này" (không nói "bạn chưa ăn"). Chạm thẻ / "Thêm món" → tab Thực đơn **đúng ngày đang xem**.
- Thẻ lịch tập: từng lịch (giờ · giáo án), SCHEDULED quá khứ/hôm nay → "Bắt đầu" (mở chi tiết lịch), tương lai → "Chưa tới ngày", COMPLETED → mở kết quả buổi (`workoutLogId`), CANCELLED gạch ngang. Không có lịch → "Lên lịch". Tiến độ tuần "x/y buổi hoàn thành" + số buổi đã hủy không tính. Buổi tiếp theo, chạm để mở.
- Thẻ cơ thể: "Cân nặng 65 kg (theo hồ sơ)", "BMI 22,49 · Mục tiêu: Tăng cơ". Chưa có hồ sơ → "Hoàn thiện hồ sơ" (tab Sức khỏe).
- Kéo để làm mới; lỗi lần đầu → "Thử lại"; tải lại lỗi khi đã có số → giữ số cũ + thẻ "Không tải được dữ liệu mới, đang hiện số liệu lúc HH:mm".

### Làm mới và cô lập dữ liệu

- `dashboardProvider` là family theo khóa **(userId, date)**: response của ngày cũ về muộn không ghi vào ngày đang xem; đổi tài khoản → khóa mới, không có "giá trị cũ" của người trước; khóa của user cũ ném `SessionExpiredException`. `dashboardDateProvider` về hôm nay khi đổi phiên.
- `ref.invalidate(dashboardProvider)` (mọi ngày đã tải) sau: thêm/sửa/xóa món (`MealPlanController._apply`, kể cả khi đã đổi ngày xem), lưu buổi tập, tạo/dời/hủy lịch, sửa giáo án, lưu hồ sơ. Quay về tab Tổng quan cũng tải lại (lưới an toàn); quay về từ màn được mở từ Tổng quan cũng vậy.
- Không cache ngoài Riverpod; provider `autoDispose`, đăng xuất gỡ HomeShell nên không còn dữ liệu.

## 5. Giới hạn

- So với mục tiêu **hiện tại** cả khi xem ngày cũ (NUT-BR09).
- Cân nặng là số trong hồ sơ, chưa phải nhật ký cân nặng (ngày 13 nối `latestWeightLog`).
- "Hôm nay" của app theo giờ máy (MVP chỉ hỗ trợ Asia/Ho_Chi_Minh); server dùng `users.timezone`.
- Mỗi lần mở tab Tổng quan gọi lại API (một request, ~50 ms local) — chấp nhận ở MVP thay vì cache.
- Chưa có lối vào AI (ngày 12).
