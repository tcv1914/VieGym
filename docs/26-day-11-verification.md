# Kiểm tra ngày 11 — Dashboard cá nhân

Thiết kế: `25-dashboard-design.md`. Ngày kiểm tra: 2026-11-09.

## 1. Môi trường

Như ngày 4–10. Không có migration mới (DB local vẫn v11). App debug cài qua `adb install -r`, backend qua `adb reverse tcp:8080 tcp:8080`.

## 2. Kiểm thử tự động

| Phần | Lệnh | Kết quả |
|---|---|---|
| Backend | `.\mvnw.cmd test` (PostgreSQL thật qua Testcontainers) | **116/116** đạt (9 mới: `DashboardIntegrationTests`) |
| Mobile | `flutter analyze` | No issues found |
| Mobile | `flutter test` | **87/87** đạt (12 mới trong `test/dashboard_test.dart`) |

## 3. Bộ nghiệm thu plan ngày 11

| Mã | Tình huống | Bằng chứng | Kết quả |
|---|---|---|---|
| D01 | User mới | `newUserGetsEmptyButCompleteShape`: đủ các khối, `hasProfile=false`, `targets`/`remaining`/`next` null, tuần 0/0/0, GET không tạo `meal_plans`. Widget: CTA Thêm món / Lên lịch / Hoàn thiện hồ sơ, không "/ 0 kcal" | Đạt |
| D02 | Fixture ngày 10 | `nutritionMatchesMealPlanFixture`: 500/25/75/10, targets/remaining trùng `GET /meal-plans`; BMI 22,49; ngày khác = 0 | Đạt |
| D03 | 3 lịch, 2 xong, +1 hủy | `weeklyProgressExcludesCancelled`: scheduled 3, completed 2, cancelled 1 | Đạt |
| D04 | Không lịch | Tuần 0 → app "chưa có lịch", `progress=null` (unit test model) | Đạt |
| D05 | Không mục tiêu | `targets`/`remaining` null; app không hiện mục tiêu 0 | Đạt |
| D06 | Thêm món / hoàn thành buổi | `reflectsWritesImmediately`: kcal 200, lịch COMPLETED kèm `workoutLogId`, `next` mất, 1/1. App: thêm món → dashboard tải lại (provider test) | Đạt |
| D07 | A/B, đổi tài khoản | `usersSeeOnlyTheirOwnData`: B không thấy dữ liệu A, `?userId=` bị bỏ qua, không token → 401. App: khóa (userId, date), khóa cũ ném `SessionExpiredException`, ngày về hôm nay | Đạt |
| D08 | Ranh giới tuần, timezone | `weekBoundaryAndUserTimezone`: CN 08/11 thuộc tuần 02/11, T2 09/11 mở tuần mới; mặc định `date` theo `Pacific/Kiritimati` và `Pacific/Pago_Pago` | Đạt |
| D09 | Nhiều món + nhiều hiệp | `manyEntriesAndSetsAreNotMultiplied`: 3 món + 2 buổi × 6 hiệp → 500 kcal, 2/2 | Đạt |

Thêm: `nextIsRelativeToRealToday` (next theo hôm nay thực, bỏ lịch hủy, ngoài 30 ngày không tính), `rejectsInvalidDate` (1999-12-31, "abc" → 400). Widget: vượt mục tiêu (thanh = 100 %, "Vượt 500 kcal"), giữ số cũ khi tải lại lỗi, "Thêm món" sang Thực đơn đúng ngày đang xem, đổi ngày khi đang tải không ghi nhầm ngày.

## 4. Latency quan sát

`GET /dashboard` trên backend local (i7-13620H, 16 GB, PostgreSQL Docker), tài khoản `phonea`, 5 request khởi động + 50 request tuần tự bằng curl: min 21 ms, p50 54 ms, p95 94 ms, max 107 ms. Một máy, dữ liệu nhỏ — không dùng để kết luận P95 của SRS (đo chuẩn ở ngày 16).

## 5. Test tay Android

**Chưa thực hiện.** App debug đã cài và bảng 12 bước đã có sẵn, nhưng user chọn commit trước khi test. Cần chạy lại bảng này trước khi demo; kết quả bổ sung vào mục này.
