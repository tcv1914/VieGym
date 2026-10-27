# Quy tắc tính chỉ số sức khỏe và mục tiêu dinh dưỡng

Áp dụng từ ngày 5, mã công thức `MSJ-v1`. Quy tắc gốc đã chốt ở ngày 2: `04-business-rules.md` §3. Tài liệu này ghi cách triển khai, các điểm khác với `plan/huong-dan-ngay-5.md` và giới hạn còn lại. Kết quả kiểm tra: `12-day-5-verification.md`.

Code: `backend/.../health/HealthCalculator.java` (thuần tính toán, không gọi DB/HTTP/AI). Test: `HealthCalculatorTest` (giá trị mong đợi tính tay).

## 1. Đâu là yêu cầu, đâu là lựa chọn triển khai

| Nội dung | Nguồn |
|---|---|
| Công thức BMI, BMR Mifflin-St Jeor, TDEE = BMR × hệ số vận động, 5 hệ số | SRS VieGym |
| Mức tăng/giảm calories cụ thể, ngưỡng dưới, cách chia macro, tuổi 18–80, làm tròn | Lựa chọn của dự án, chốt ở ngày 2 (`04-business-rules.md`), khớp `kich-ban-demo.md` |
| Phương trình Mifflin-St Jeor | [Mifflin và cộng sự, 1990](https://pubmed.ncbi.nlm.nih.gov/2305711/): **ước tính** năng lượng nghỉ của người trưởng thành khỏe mạnh, không phải phép đo |

Tỷ lệ macro và ngưỡng calories là cấu hình của ứng dụng demo, không phải khuyến nghị dinh dưỡng cá nhân. App ghi rõ kết quả là ước tính.

## 2. Khác với plan ngày 5

Plan ngày 5 đưa một "chính sách demo đề xuất" và yêu cầu đối chiếu với lựa chọn ngày 2 trước khi áp dụng. Ngày 2 đã chốt và có số liệu kịch bản demo, nên dự án **giữ quyết định ngày 2**:

| Điểm | Plan ngày 5 | Áp dụng (ngày 2) |
|---|---|---|
| Mức vận động | `HIGH`, `VERY_HIGH` | `ACTIVE`, `VERY_ACTIVE` |
| Mục tiêu | `LOSE_WEIGHT`, `GAIN_WEIGHT`, `BUILD_MUSCLE`, `MAINTAIN` | `LOSE_WEIGHT`, `MAINTAIN`, `GAIN_MUSCLE` |
| Nhánh công thức | `MALE`/`FEMALE`/`UNSPECIFIED` | `sex`: `MALE`/`FEMALE`, bắt buộc |
| Calories | −300 / +300 / +200 / 0 | −500 / +300 / 0, có ngưỡng dưới |
| Macro | 25% protein / 50% carbs / 25% fat | Protein theo g/kg có trần 35%; fat 25%; carbs phần còn lại |
| Làm tròn | 2 chữ số; kcal số nguyên | BMI 2 chữ số; còn lại 1 chữ số |
| Tuổi | Ví dụ 18–65 | 18–80 |
| Lịch sử | Bảng `health_profile_revisions` | Không có (BR-H03: chỉ mục tiêu hiện tại) |
| Múi giờ | Trường `timezone` trong hồ sơ | Dùng `users.timezone` (BR-G04) |
| Mã 404 | `HEALTH_PROFILE_NOT_FOUND` | `HEALTH_PROFILE_REQUIRED` (`05-api-contract.md`) |
| Tên trường | `policyVersion`, `calculatedOn` | `formulaVersion`, `calculatedAt` |

Muốn đổi sang chính sách khác thì sửa `HealthCalculator`, tăng `FORMULA_VERSION`, cập nhật `04-business-rules.md` §3, tài liệu này và test cùng lúc.

## 3. Công thức

```text
age   = số năm tròn từ date_of_birth đến hôm nay theo users.timezone (Period.between)
BMI   = weight_kg / (height_cm / 100)²
BMR   = 10 × weight_kg + 6,25 × height_cm − 5 × age + s        s = +5 (MALE), −161 (FEMALE)
TDEE  = BMR × hệ số vận động

target = TDEE + delta                                          LOSE_WEIGHT −500 · MAINTAIN 0 · GAIN_MUSCLE +300
floor  = max(BMR, 1500 nếu MALE / 1200 nếu FEMALE)
nếu target < floor: target = floor, kcalFloorApplied = true

protein_g = min(hệ số × weight_kg, 35% × target / 4)           LOSE_WEIGHT 2,0 · MAINTAIN 1,6 · GAIN_MUSCLE 1,8 g/kg
fat_g     = 25% × target / 9
carbs_g   = (target − 4 × protein_g − 25% × target) / 4
```

| Mức vận động | Hệ số |
|---|---:|
| `SEDENTARY` | 1,2 |
| `LIGHT` | 1,375 |
| `MODERATE` | 1,55 |
| `ACTIVE` | 1,725 |
| `VERY_ACTIVE` | 1,9 |

**Tuổi khi sinh 29/2:** năm không nhuận được tính đủ tuổi từ ngày 1/3 (sinh 2008-02-29 → ngày 2026-02-28 là 17 tuổi, ngày 2026-03-01 là 18 tuổi).

## 4. Số học và làm tròn

- Backend tính bằng `BigDecimal`, tạo từ chuỗi hoặc số nguyên (không dùng `new BigDecimal(double)`). Phép chia không hết (BMI, fat) giữ 16 chữ số có nghĩa (`DECIMAL64`).
- Chỉ làm tròn ở bước cuối, kiểu `HALF_UP`: BMI 2 chữ số; BMR, TDEE, calories mục tiêu và macro 1 chữ số. Macro tính từ `target` **chưa làm tròn**.
- Carbs dùng `25% × target` (chính xác) thay vì `fat_g × 9`. Nếu dùng `fat_g` đã cắt ở chữ số thứ 16 rồi nhân lại 9, kết quả 181,25 sẽ thành 181,2499… và làm tròn sai thành 181,2.
- Tổng năng lượng từ macro đã làm tròn lệch tối đa 0,85 kcal so với mục tiêu (mỗi macro lệch ≤ 0,05 g).
- Nếu tính ra `carbs_g < 0` thì báo lỗi nội bộ và không lưu gì. Với trần protein 35% thì trường hợp này không xảy ra.

## 5. Ví dụ đối chiếu (có trong unit test)

| Ca | Đầu vào | BMI | BMR | TDEE | Mục tiêu | Protein | Carbs | Fat |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Demo | Nam 22t, 170 cm, 65 kg, MODERATE, GAIN_MUSCLE | 22,49 | 1.607,5 | 2.491,6 | 2.791,6 | 117,0 | 406,4 | 77,5 |
| Trần protein | Nữ 80t, 100 cm, 300 kg, SEDENTARY, LOSE_WEIGHT | 300,00 | 3.064,0 | 3.676,8 | 3.176,8 | 278,0 | 317,7 | 88,2 |
| Ngưỡng nữ | Nữ 80t, 150 cm, 40 kg, SEDENTARY, LOSE_WEIGHT | 17,78 | 776,5 | 931,8 | **1.200,0** ⚑ | 80,0 | 145,0 | 33,3 |
| Ngưỡng nam | Nam 30t, 160 cm, 50 kg, SEDENTARY, LOSE_WEIGHT | 19,53 | 1.355,0 | 1.626,0 | **1.500,0** ⚑ | 100,0 | 181,3 | 41,7 |

⚑ = `kcalFloorApplied = true`.

Tính tay ca demo: BMR = 650 + 1.062,5 − 110 + 5 = 1.607,5; TDEE = 1.607,5 × 1,55 = 2.491,625; mục tiêu = 2.791,625; protein = min(1,8 × 65 = 117; 0,35 × 2.791,625 / 4 = 244,3) = 117; fat = 697,906 / 9 = 77,545; carbs = (2.791,625 − 468 − 697,906) / 4 = 406,43.

## 6. Đầu vào hợp lệ

| Trường | Quy tắc | Lỗi |
|---|---|---|
| `sex` | `MALE`/`FEMALE`, bắt buộc | 400 `fieldErrors.sex` |
| `dateOfBirth` | `YYYY-MM-DD`, không ở tương lai, tuổi 18–80 theo `users.timezone` | 400 `fieldErrors.dateOfBirth` |
| `heightCm` | 100,0–250,0, tối đa 1 chữ số lẻ | 400 `fieldErrors.heightCm` |
| `weightKg` | 30,0–300,0, tối đa 1 chữ số lẻ | 400 `fieldErrors.weightKg` |
| `activityLevel`, `goal` | Đúng mã ở trên | 400 theo trường |
| `userId`, `bmi`, `targetKcal`… do client gửi | Bị bỏ qua | — |

Giá trị enum lạ hoặc ngày sai định dạng cũng trả `VALIDATION_ERROR` chỉ rõ trường lỗi (không trả `MALFORMED_JSON` chung chung). Khoảng chiều cao/cân nặng là giới hạn kỹ thuật của MVP, không phải định nghĩa "bình thường".

## 7. Lưu trữ và giao dịch

- `health_profiles` và `nutrition_targets` mỗi user một dòng (`UNIQUE user_id`). `PUT /health-profile/me` ghi cả hai trong **một giao dịch** (BR-H01). Lỗi ở bất kỳ bước nào thì không lưu gì.
- PUT khóa hàng `users` (`SELECT … FOR UPDATE`) trước khi đọc/ghi hồ sơ. Hai PUT đầu tiên chạy đồng thời sẽ nối tiếp nhau thay vì cùng INSERT rồi vấp UNIQUE.
- `GET` chỉ đọc mục tiêu đã lưu, không tính lại. `profile.age` trong response là tuổi **hôm nay**, có thể lớn hơn tuổi lúc tính mục tiêu (BR-H04).
- `kcal_floor_applied` được lưu (thêm so với ERD ngày 2) vì GET không tính lại mà app vẫn cần cờ này.
- `/users/me` và `user` trong response login/refresh có `hasHealthProfile` thật (ngày 4 luôn trả `false`).

## 8. Giới hạn đã biết

- **Mục tiêu không tự cập nhật theo tuổi** (BR-H04): sau sinh nhật, BMR thật giảm 5 kcal/năm cho tới khi user lưu lại hồ sơ.
- **Ngưỡng dưới có thể cao hơn TDEE** với người nhỏ con, ít vận động, chọn giảm cân (ví dụ ca "Ngưỡng nam": mục tiêu 1.500 > TDEE 1.626 − 500, nhưng vẫn < TDEE). Nếu BMR < 1.500 và TDEE < 1.500 thì mục tiêu "giảm cân" sẽ lớn hơn TDEE. App hiện thông báo khi `kcalFloorApplied`. Muốn xử lý khác thì phải chốt lại với giảng viên.
- **Chỉ hai nhánh `sex`.** Người không muốn khai báo chưa dùng được luồng tự tính. Thêm nhánh "chưa tính được" cần đổi API (`targets` nullable) và màn hình.
- **Không có lịch sử thay đổi hồ sơ.** Lịch sử cân nặng làm ở ngày 13 (`weight_logs`). So sánh thực đơn cũ dùng mục tiêu hiện tại (BR-H03).
- **Chưa cho đổi múi giờ.** Mọi user dùng mặc định `Asia/Ho_Chi_Minh`.
