# Kiểm tra ngày 10 — Meal Planner và tổng dinh dưỡng trong ngày

Thiết kế: `23-meal-planner-design.md`. Ngày kiểm tra: 2026-11-05.

## 1. Môi trường

Như ngày 4–9. Flyway local: **V11 `create meal plans`** áp dụng thành công (DB lên v11). App cài bản debug qua `adb install -r`, gọi backend qua `adb reverse tcp:8080 tcp:8080`.

## 2. Kiểm thử tự động

| Phần | Lệnh | Kết quả |
|---|---|---|
| Backend | `.\mvnw.cmd test` (PostgreSQL thật qua Testcontainers) | **107/107** đạt (12 mới: `MealNutritionTest` 3, `MealPlanIntegrationTests` 9) |
| Mobile | `flutter analyze` | No issues found |
| Mobile | `flutter test` | **75/75** đạt (12 mới trong `test/meal_test.dart`) |

Món fixture A/B được chèn riêng cho từng test và xóa sau test, để `FoodLibraryIntegrationTests` (đếm đúng 928 món) không bị lệch.

Phép tính fixture (plan §4), kiểm ở cả unit test lẫn API:

| Bước | kcal / P / C / F |
|---|---|
| A × 1,5 + B × 2 | 500 / 25 / 75 / 10 |
| Sửa A thành 1 phần | 400 / 20 / 60 / 8 |
| Xóa B | 200 / 10 / 30 / 4 |

Ngoài ra: hai mục 0,5 × 0,01 kcal → mỗi mục 0,01, tổng 0,01 (chỉ làm tròn tổng cuối); HALF_UP 0,125 → 0,13; remaining âm khi vượt.

## 3. Bộ nghiệm thu plan ngày 10

| Mã | Tình huống | Bằng chứng | Kết quả |
|---|---|---|---|
| M01 | Thêm/sửa/xóa theo fixture | `fixtureAddUpdateDelete`: số khớp bảng trên; đổi bữa giữ tổng; xóa hết → thực đơn vẫn còn (BR-N06); xóa lần hai → 404 | Đạt |
| M02 | Servings 0/âm/quá lớn | `invalidInputIsRejected`: 0, -1, 20,01, 21, 1,255, null, "abc", bữa lạ, thiếu món/ngày, ngày < 2000 → 400 `VALIDATION_ERROR` theo trường, không tạo thực đơn; biên 0,01 và 20 hợp lệ; PUT rỗng/sai → 400 | Đạt |
| M03 | Cùng POST gửi lại | Theo NUT-BR08 (docs/23 §1): không có khóa chống lặp, mỗi lần là một mục; app khóa nút khi gửi, mất mạng → tải lại và nhắc kiểm tra (widget test + Android bước 12) | Đạt theo quyết định ngày 2 |
| M04 | Hai lần thêm có chủ ý | `eachAddIsSeparateEntryAndClientNutritionIgnored`: 2 mục, 1 thực đơn; kcal/userId app gửi bị bỏ qua (BR-N04) | Đạt |
| M05 | Hai request tạo thực đơn cùng lúc | `concurrentFirstAddCreatesOnePlan`: 2 × 201, 1 thực đơn, 2 mục | Đạt |
| M06 | Admin sửa món | `foodEditDoesNotChangeEntries`: đổi tên/kcal/revision món trong DB → mục cũ giữ tên và số cũ, sửa số phần tính từ snapshot cũ; mục thêm sau lấy số mới, `food_revision` = 2 | Đạt |
| M07 | Món bị ẩn | `inactiveFoodBlocksNewEntriesOnly`: thêm mới → 422 `FOOD_INACTIVE`; món không tồn tại → 404; mục cũ vẫn xem/sửa/xóa được | Đạt |
| M08 | A tác động mục của B | `entriesAreIsolatedPerUser`: PUT/DELETE chéo → 404, mục của A không đổi; không token → 401 | Đạt |
| M09 | Đổi mục tiêu | `comparesWithCurrentTarget`: chưa hồ sơ → `targets` null; có hồ sơ → remaining = target − tổng; vượt → âm; đổi cân nặng → ngày cũ so với mục tiêu **mới** (NUT-BR09, khác plan), mục không đổi | Đạt theo quyết định ngày 2 |
| M10 | Múi giờ / gần nửa đêm | `datesFollowUserTimezone`: user UTC+14 và UTC−11 (luôn khác ngày) — GET không `date` trả hôm nay của từng người; hôm nay + 7 được, + 8 → 400; cùng ngày đó với user múi giờ chậm → 400; ngày quá khứ được | Đạt |

## 4. Kiểm tra tay trên Android

Người dùng tự thao tác theo bảng 14 bước, **đạt cả 14**:

| # | Nội dung | Kết quả |
|---|---|---|
| 1 | Tab Thực đơn hôm nay: 4 bữa trống, "Đã ăn 0 kcal / 2.084,6 kcal", ghi chú mục tiêu hiện tại | Đạt |
| 2–3 | Chọn món qua tìm kiếm ngày 9, nhập "1,5", xem trước, thêm | Đạt |
| 4 | Thêm món bữa tối 2 phần, tổng cộng đúng | Đạt |
| 5–6 | Sửa số phần; đổi bữa sang Bữa phụ | Đạt |
| 7 | Xóa có xác nhận | Đạt |
| 8 | 0 / 25 / 1,234 → báo lỗi, nút Thêm khóa | Đạt |
| 9 | 20 phần → "Vượt … kcal" màu đỏ | Đạt |
| 10 | Đổi ngày, nút › khóa ở hôm nay + 7, nút "Hôm nay" | Đạt |
| 11 | Tìm khi chọn món không đổi ô tìm của tab Món ăn | Đạt |
| 12 | Tắt backend khi đang gửi → giữ form, báo "không rõ đã tới máy chủ"; bật lại, tải lại không có mục giả | Đạt |
| 13 | Đăng nhập B: không thấy món của A, mục tiêu 1.486,8 kcal | Đạt |
| 14 | Tài khoản chưa có hồ sơ: "Chưa có mục tiêu để so sánh", không hiện "/ 0 kcal" | Đạt |

Trạng thái DB local sau khi test tay (đã sửa/xóa trong lúc test):

```text
phonea | 2026-11-05 | SNACK     | Phở bò chín   |  1.00 × 448.50 = 448.50 | food_revision 1
phonea | 2026-11-05 | BREAKFAST | Bánh bao chay | 20.00 ×  33.00 = 660.00 | food_revision 1
phonea | 2026-11-05 | BREAKFAST | Bánh bèo      |  1.00 × 451.10 = 451.10 | food_revision 1
meal_plans: phonea 1, phoneb 0
```

Snapshot lưu số liệu **một khẩu phần**; tổng mục = servings × snapshot. B không có thực đơn nào (không trộn tài khoản).

## 5. Lỗi và giới hạn còn lại

- Không tìm thấy lỗi mới trong ngày. Test widget đầu tiên hỏng do màn test 800×600 không dựng bữa phụ (ListView lười) — sửa bằng màn test cao hơn, không phải lỗi app.
- Không chống thêm trùng ở server và không khóa lạc quan (docs/23 §6).
- Ngày cũ so với mục tiêu hiện tại, không phải mục tiêu lúc đó (NUT-BR09).
- Khẩu phần theo "phần ăn" của nguồn, không quy đổi gram.
- Tổng hợp lên dashboard: ngày 11.
