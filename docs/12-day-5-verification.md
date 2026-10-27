# Ngày 5 — Kết quả kiểm tra hồ sơ sức khỏe và mục tiêu dinh dưỡng

Ngày kiểm tra: 2026-10-27. Quy tắc tính: `11-health-calculation-rules.md` (`MSJ-v1`). Chỉ ghi kết quả đã chạy thật.

## 1. Môi trường

Như ngày 4 (`10-day-4-verification.md` §1). Flyway local: V1, V2, **V3 `create health tables`** đều `success = t`. App cài bản debug mới qua `adb install`, gọi backend qua `adb reverse tcp:8080 tcp:8080`.

## 2. Kiểm thử tự động

| Lệnh | Kết quả |
|---|---|
| `backend> .\mvnw.cmd test` | ✅ 42/42: `HealthCalculatorTest` 18, `HealthProfileIntegrationTests` 9, `AuthFlowIntegrationTests` 14, `BackendApplicationTests` 1 |
| `mobile> flutter analyze` | ✅ `No issues found!` |
| `mobile> flutter test` | ✅ 19/19: `health_test` 9, `auth_repository_test` 8, `widget_test` 2 |

`HealthCalculatorTest` không cần Spring/DB; giá trị mong đợi tính tay (ghi trong comment test). Integration test chạy trên PostgreSQL container riêng (Testcontainers).

## 3. Kết quả theo mã kiểm tra

| Mã | Kiểm tra | Mong đợi | Thực tế | Bằng chứng |
|---|---|---|---|---|
| H01 | Công thức ca cố định | Khớp bảng `11` §5 | ✅ 4 ca (demo, trần protein, ngưỡng nữ, ngưỡng nam) + Android A/B | `demoCaseMaleGainMuscle`, `proteinCapCaseFemaleLoseWeight`, `femaleTargetRaisedToFloor`, `maleTargetRaisedToFloorAndCarbsRoundHalfUp`; Android bước 3, 5, 9 |
| H02 | 5 mức vận động | Đúng hệ số | ✅ | `activityFactors` |
| H03 | 3 mục tiêu | Đúng delta và g/kg protein | ✅ | `goalDeltaAndProtein` |
| H04 | Trước/sau sinh nhật, 29/2 | Tuổi tròn đúng | ✅ | `ageInWholeYears` |
| H05 | Ngày sinh tương lai, < 18, > 80, chiều cao 0 hoặc 2 số lẻ, cân nặng âm hoặc > 300, thiếu trường | 400 theo trường, hồ sơ cũ giữ nguyên | ✅; biên 18 và 80 tuổi được chấp nhận | `invalidValuesAreRejectedWithoutChangingSavedProfile`, `ageBoundariesAreAccepted`; Android bước 2, 6 |
| H06 | Enum lạ (`OTHER`, `HIGH`), ngày `2004-13-40` | 400 `VALIDATION_ERROR` chỉ rõ trường | ✅ | `unknownEnumOrBadDateReturnsFieldError` |
| H07 | Chưa có hồ sơ | 404 `HEALTH_PROFILE_REQUIRED`; `hasHealthProfile=false` | ✅ | `getWithoutProfileIsProfileRequired`; Android bước 1, 8 |
| H08 | PUT rồi GET / mở lại app | Dữ liệu giữ nguyên | ✅ | `putCalculatesAndGetReturnsSavedTargets`; Android bước 4 |
| H09 | Hai PUT đầu tiên đồng thời | Cả hai 200, đúng 1 hồ sơ + 1 mục tiêu | ✅ | `concurrentFirstPutsCreateOneProfile` |
| H10 | Không JWT / phiên đã logout | 401 | ✅ | `requiresValidSession` |
| H11 | A/B đọc và sửa hồ sơ | Tách biệt | ✅ | `usersOnlySeeAndChangeTheirOwnProfile`; Android bước 8–10 |
| H12 | Client gửi `userId` của A, `bmi`, `targetKcal` | Bị bỏ qua, A không đổi | ✅ | `usersOnlySeeAndChangeTheirOwnProfile` |
| H13 | Lỗi khi ghi mục tiêu | Rollback, không có hồ sơ | ✅ 500, 0 dòng ở cả hai bảng | `failureWhileSavingTargetRollsBackProfile` |
| H14 | Chuyển sang UNSPECIFIED | — | **Không áp dụng**: chỉ có `MALE`/`FEMALE` (`11` §2, §8) | — |
| H15 | Mất mạng khi lưu | Báo lỗi, giữ dữ liệu, không báo thành công giả | ✅ | `health_test` (mất mạng ≠ chưa có hồ sơ); Android bước 7 |
| H16 | Revision khi sửa | — | **Không áp dụng**: không có bảng lịch sử (BR-H03) | — |

## 4. Android (kiểm tra tay)

Người kiểm tra tự thao tác trên OPPO CPH2565 và xác nhận từng bước đúng như cột "Mong đợi". Lần này không chụp ảnh. Bằng chứng phía server ở mục 5.

| # | Thao tác | Mong đợi | Thực tế |
|---|---|---|---|
| 1 | Đăng nhập A (chưa có hồ sơ) | Màn "Tạo hồ sơ sức khỏe" | ✅ |
| 2 | Lưu khi trống | Lỗi dưới từng ô | ✅ |
| 3 | Nam, 10/05/2004, 170 cm, 65 kg, Vừa, Tăng cơ | 2.791,6 kcal; P 117,0 · C 406,4 · F 77,5; BMI 22,49; Tuổi 22 | ✅ |
| 4 | Tắt hẳn rồi mở lại app | Vào thẳng màn hồ sơ, số như cũ | ✅ |
| 5 | Sửa: cân nặng `70,5` (dấu phẩy), Giảm cân | 2.076,9 kcal; P 141,0 · C 248,4 · F 57,7; BMI 24,39 | ✅ |
| 6 | Chiều cao `170,25` | Báo tối đa 1 chữ số lẻ; thoát ra số không đổi | ✅ |
| 7 | Sửa cân nặng 71, rút USB, Lưu; cắm lại, Lưu | Báo lỗi kết nối, giữ form; lần 2 thành công | ✅ |
| 8 | Đăng xuất, đăng nhập B | Form tạo mới trống, không thấy số của A | ✅ |
| 9 | B: Nữ, 01/01/1996, 160 cm, 55 kg, Ít vận động, Giữ cân | 1.486,8 kcal; P 88,0 · C 190,8 · F 41,3; BMI 21,48; Tuổi 30 | ✅ |
| 10 | Đăng xuất B, đăng nhập A | Hồ sơ A, cân nặng 71,0 | ✅ |

## 5. Đối chiếu database sau kiểm tra tay

| User | Hồ sơ | BMI | BMR | TDEE | Mục tiêu | P / C / F | Đã sửa |
|---|---|---:|---:|---:|---:|---|---|
| A | MALE, 2004-05-10, 170,0 cm, 71,0 kg, MODERATE, LOSE_WEIGHT | 24,57 | 1.667,5 | 2.584,6 | 2.084,6 | 142,0 / 248,9 / 57,9 | có (`updated_at > created_at`) |
| B | FEMALE, 1996-01-01, 160,0 cm, 55,0 kg, SEDENTARY, MAINTAIN | 21,48 | 1.239,0 | 1.486,8 | 1.486,8 | 88,0 / 190,8 / 41,3 | không |

Kiểm tra tay giá trị cuối của A: BMR = 710 + 1.062,5 − 110 + 5 = 1.667,5; TDEE = 2.584,625; mục tiêu = 2.084,625; protein = min(2,0 × 71 = 142; 182,4) = 142; fat = 521,156 / 9 = 57,9; carbs = (2.084,625 − 568 − 521,156) / 4 = 248,87. ✅

Mỗi user đúng 1 hồ sơ (2 hồ sơ / 2 user), `formula_version = MSJ-v1`, `kcal_floor_applied = false`.

## 6. Dữ liệu và bảo mật

- Hồ sơ test là dữ liệu giả có chủ ý; không có dữ liệu sức khỏe thật trong repo hay báo cáo.
- `HealthProfileRequest` không có `userId`; chủ sở hữu luôn lấy từ phiên đã xác minh (BR-G01). Không có endpoint đọc hồ sơ theo userId.
- Log lỗi chỉ ghi đường dẫn request, không ghi body hồ sơ.

## 7. Còn tồn tại

| Vấn đề | Hướng xử lý |
|---|---|
| Mục tiêu không tự cập nhật sau sinh nhật (BR-H04) | Chủ ý trong MVP; app có thể nhắc lưu lại hồ sơ ở ngày làm dashboard |
| Ngưỡng dưới có thể làm mục tiêu "giảm cân" ≥ TDEE ở người rất nhẹ cân, ít vận động | Đã ghi `11` §8; cần chốt với giảng viên nếu muốn đổi |
| Chưa có nhánh "không khai báo giới tính" và lịch sử hồ sơ | Ngoài phạm vi đã chốt ngày 2 |
| Ca ngưỡng dưới (`kcalFloorApplied`) chưa kiểm tra tay trên Android | Đã có unit test; thông báo trên app sẽ kiểm khi làm dashboard |
