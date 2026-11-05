# Thực đơn trong ngày (Meal Planner) — thiết kế ngày 10

UC07. Bảng gốc: `03-database-design.md` §6, quy tắc: `04-business-rules.md` §5 (BR-N02..N07), API: `05-api-contract.md` §10. Migration: `V11__create_meal_plans.sql`. Dữ liệu món: `20-food-data-policy.md`. Kết quả kiểm tra: `24-day-10-verification.md`.

## 1. Khác với plan ngày 10

Như ngày 5–9, dự án **giữ quyết định ngày 2** và chỉ bổ sung phần ngày 2 còn thiếu.

| Điểm | Plan ngày 10 | Áp dụng |
|---|---|---|
| Mục tiêu so sánh | Chụp `target_snapshot` khi tạo plan; `targetSource` PREVIEW/SNAPSHOT | **So với mục tiêu hiện tại** (NUT-BR09). Response có `targetsCalculatedAt`; app ghi rõ "so với mục tiêu hiện tại (tính ngày …), kể cả khi xem ngày cũ". So theo lịch sử mục tiêu là hướng mở rộng |
| Chống gửi lặp | `clientEntryId` + UNIQUE + payload hash, retry → 200 | Không có. Mỗi lần thêm là **một mục riêng** (NUT-BR08); app khóa nút khi đang gửi. Mất mạng khi đang thêm → app **tự tải lại thực đơn** và nhắc kiểm tra trước khi gửi lại (không tự gửi lại) |
| Khóa lạc quan | `revision` ở plan/entry, PUT gửi revision, conflict 409 | Không có (PUT docs/05 không có revision). Mọi thao tác ghi khóa hàng `users` nên chạy tuần tự; hai thiết bị cùng sửa một mục → bản sau thắng. Ghi vào giới hạn |
| Response sau ghi | Tùy chọn | POST/PUT/DELETE đều trả **toàn bộ thực đơn ngày** (docs/05); DELETE `200`, không `204` |
| Retry POST hợp lệ | `200` | Luôn `201` (không có idempotency) |
| Món ẩn | 404/400 | `422 FOOD_INACTIVE`; món không tồn tại `404` (docs/05) |
| `servings` | NUMERIC(8,2), ≤ 100 | NUMERIC(5,2), > 0, ≤ 20, tối đa 2 chữ số lẻ (BR-N02) |
| Ngày ghi | Không giới hạn | Quá khứ được, tối đa **7 ngày tới** theo múi giờ user (BR-N07); trước 2000-01-01 → 400 |
| Bảng `meal_plans` | Cột `timezone`, `target_snapshot`, `revision` | Không cần: ngày đã tính theo `users.timezone`, không chụp mục tiêu, không revision |
| Ghi chú mục | "Size ghi chú có giới hạn" | MVP không có ghi chú mục |

Thêm so với ngày 2 (đã cập nhật docs/03, docs/05):
- `meal_entries`: `food_revision`, `serving_description_snapshot`, `data_quality_snapshot` (nguồn chỉ ghi "1 phần ăn", không có gram — docs/20 §2); `serving_size_snapshot`/`serving_unit_snapshot` được NULL như `foods`. Tên món 150 ký tự như `foods.name`.
- Response: `entryCount`, `mealTotals` (tổng từng bữa), `targetsCalculatedAt`; mỗi mục có `mealType`, `servingDescription`, `kcalPerServing`/`proteinPerServingG`/`carbsPerServingG`/`fatPerServingG` (snapshot, để app xem trước khi sửa số phần), `dataQuality`, `createdAt`.
- Giới hạn 100 mục/ngày → `422 MEAL_PLAN_LIMIT`.

## 2. Quy tắc

| Nội dung | Quy tắc |
|---|---|
| Thực đơn | Một thực đơn/user/ngày (UNIQUE). Tạo khi thêm món đầu tiên; GET không tạo dữ liệu; xóa hết món không xóa thực đơn (BR-N06) |
| Ngày | Theo `users.timezone`. GET không có `date` → hôm nay của user. Ghi: ≥ 2000-01-01 và ≤ hôm nay + 7 |
| Bữa | `BREAKFAST`, `LUNCH`, `DINNER`, `SNACK` |
| Thêm | `foodId` phải tồn tại và đang hiển thị. Chụp tên, khẩu phần, kcal/P/C/F **một khẩu phần**, chất lượng dữ liệu và `foods.revision` |
| Sửa | Chỉ `servings` và/hoặc `mealType`, ít nhất một. Không đọc lại `foods`: tính từ snapshot. Món đã ẩn vẫn sửa/xóa được (NUT-BR06). Đổi món = xóa rồi thêm |
| Kcal/macro từ app | Bỏ qua (BR-N04); trường lạ trong body không gây lỗi |
| Quyền | Mục của user khác → `404` như không tồn tại (A9) |
| Mục tiêu | `nutrition_targets` hiện tại; chưa có hồ sơ → `targets`/`remaining` = `null` (A8), app hiện "chưa có mục tiêu", không hiện 0 kcal như mục tiêu |
| Vượt mục tiêu | Vẫn lưu; `remaining` **âm**, không kẹp về 0; app hiện "Vượt X kcal" (A7) |

## 3. Tính tổng

```text
mục           = servings × *_per_serving_snapshot          (BigDecimal, chính xác 4 chữ số lẻ)
tổng bữa/ngày = Σ mục chưa làm tròn                        (cùng một vòng lặp, cùng nguồn)
remaining     = target − tổng chưa làm tròn
response      = làm tròn HALF_UP 2 chữ số (NUT-BR07)
```

Không cộng các giá trị đã làm tròn; không suy kcal từ macro. Ví dụ: hai mục 0,5 × 0,01 kcal → mỗi mục hiện 0,01, tổng 0,01 (không phải 0,02). `MealNutrition` (unit test) và `MealPlanService.view` dùng chung.

Fixture plan §4: A 200 kcal/P10/C30/F4, B 100/P5/C15/F2. A×1,5 + B×2 → **500/25/75/10**; A còn 1 phần → **400/20/60/8**; xóa B → **200/10/30/4**.

## 4. Giao dịch và đồng thời

```text
POST   1. SELECT users FOR UPDATE           (cùng điểm khóa với hồ sơ, giáo án, lịch, log tập)
       2. Kiểm tra ngày theo múi giờ user; đọc món → 404 / 422 FOOD_INACTIVE
       3. Tìm hoặc tạo meal_plans (user, ngày); đếm mục → 422 MEAL_PLAN_LIMIT
       4. INSERT meal_entries (snapshot), cập nhật meal_plans.updated_at, flush
       5. Đọc lại các mục của ngày → tính tổng → trả về
PUT/DELETE: 1. khóa users  2. mục kèm user (join meal_plans) → 404  3. sửa/xóa, flush  4. trả thực đơn ngày
```

- Hai request thêm món đầu ngày song song: request sau chờ khóa, thấy thực đơn vừa tạo → một thực đơn, hai mục. UNIQUE (`user_id`, `plan_date`) là lớp cuối.
- Lỗi giữa chừng → rollback cả thực đơn mới lẫn mục.
- Không gọi dịch vụ ngoài trong giao dịch.

## 5. App

```text
lib/features/nutrition/meal/
├── data/         meal_api.dart, meal_models.dart (MealType, parseServings, previewKcal)
├── application/  meal_plan_controller.dart
└── presentation/ meal_plan_page.dart, meal_entry_sheet.dart
```

- Tab mới **"Thực đơn"** (trước tab "Món ăn"). Thanh ngày: ‹ ngày trước, chọn ngày (2000 → hôm nay + 7), ngày sau ›, "Hôm nay".
- Thẻ tổng: "Đã ăn X / mục tiêu Y kcal", thanh tiến độ, "Còn lại" hoặc "Vượt" (màu lỗi), đạm/bột đường/béo, ghi chú nguồn mục tiêu.
- Bốn bữa, mỗi bữa có tổng kcal, nút "Thêm món" (khóa khi ngày > hôm nay + 7) và danh sách mục (tên snapshot, "1,5 × 1 phần ăn theo nguồn", kcal, P/C/F).
- Thêm: mở màn tìm món ngày 9 ở chế độ chọn (trạng thái tìm kiếm riêng, không đổi từ khóa của tab Món ăn; nút ⓘ xem chi tiết) → sheet nhập số khẩu phần (nhận "1,5"/"1.5") + đổi bữa → xem trước kcal → "Thêm". Nút khóa khi đang gửi hoặc số phần sai.
- Sửa/xóa: chạm mục → cùng sheet, có "Xóa" (hỏi xác nhận). Chỉ gửi trường đã đổi; không đổi gì → đóng, không gọi API.
- Lỗi: giữ form và số đã nhập. Mất mạng hoặc mục không còn (404) → tải lại thực đơn. `FOOD_INACTIVE` → "hãy chọn món khác".
- Đổi ngày khi đang tải: response ngày cũ bị bỏ qua; kết quả ghi của ngày khác không ghi đè ngày đang xem. Đăng xuất/đổi tài khoản → controller dựng lại, không còn dữ liệu người trước.
- "Hôm nay" của app = ngày trên máy (MVP chỉ hỗ trợ Asia/Ho_Chi_Minh, BR-G04); server kiểm tra lại theo `users.timezone`.

## 6. Giới hạn

- Không chống thêm trùng ở server: mất mạng đúng lúc server đã lưu, người dùng bấm thêm lại → hai mục (xóa được). App tự tải lại để giảm khả năng này.
- Không khóa lạc quan: hai thiết bị cùng sửa một mục → bản sau thắng, không báo xung đột.
- Ngày cũ so với mục tiêu **hiện tại**, không phải mục tiêu lúc đó (NUT-BR09).
- Khẩu phần theo "phần ăn" của nguồn, không có gram (docs/20 §8) → chưa nhập được "200 g phở".
- Chưa có dashboard (ngày 11) và chưa sửa món ở admin (ngày 14); M06 kiểm bằng cập nhật trực tiếp DB trong test.
