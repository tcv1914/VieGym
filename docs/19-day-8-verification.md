# Kiểm tra ngày 8 — ghi nhận buổi tập và lịch sử

Thiết kế: `18-workout-log-design.md`. Ngày kiểm tra: 2026-11-04.

## 1. Môi trường

Như ngày 4–7 (`10-day-4-verification.md` §1). Flyway local: **V8 `create workout logs`** áp dụng thành công (DB lên v8). App cài bản debug qua `adb install`, gọi backend qua `adb reverse tcp:8080 tcp:8080`.

## 2. Kiểm thử tự động

| Phần | Lệnh | Kết quả |
|---|---|---|
| Backend | `.\mvnw.cmd test` (PostgreSQL thật qua Testcontainers) | 86/86 đạt (12 test mới trong `WorkoutLogIntegrationTests`) |
| Mobile | `flutter analyze` | No issues found |
| Mobile | `flutter test` | 55/55 đạt (15 test mới trong `test/workout_log_test.dart`) |

Lỗi tìm ra và đã sửa trong lúc test:
- Jackson mặc định nhận `"reps": 10.5` và cắt thành 10. Đã tắt `accept-float-as-int` cho toàn bộ backend → 400 (bộ test cũ vẫn đạt).
- Form: khi server trả 409 `WORKOUT_ALREADY_LOGGED`, hộp thoại "Đã có kết quả" mở trong lúc nút còn ở trạng thái đang gửi. Đã mở khóa nút trước khi hiện hộp thoại.

## 3. Bộ nghiệm thu plan ngày 8

Fixture: Goblet Squat 10×20 kg, 8×22,5 kg; Chống đẩy 12×0, 10×0 → 2 bài, 4 hiệp, 40 lần, volume tạ ngoài 380.

| Mã | Tình huống | Bằng chứng | Kết quả |
|---|---|---|---|
| L01 | Lưu fixture 2 bài/4 hiệp | `logFixtureCompletesSchedule` | Đạt: 201, 2/4/40/380, lịch COMPLETED, `workoutLogId` có trong lịch |
| L02 | Gửi lại cùng payload | `resendReturnsExistingLog` | Theo BR-W06: 409 `WORKOUT_ALREADY_LOGGED` + cùng `workoutLogId`, vẫn 1 log (plan muốn 200, docs/18 §1) |
| L03 | Gửi lại khác reps | `resendReturnsExistingLog` | Đạt: 409, log cũ giữ nguyên (40 lần) |
| L04 | Hai request đồng thời cùng payload | `concurrentLogsCreateOne` | Đạt: một 201, một 409, 1 log |
| L05 | Hai request đồng thời khác payload | `concurrentLogsCreateOne` | Đạt (như L04) |
| L06 | Lỗi sau khi đã chèn một phần | `failureMidwayRollsBackEverything` (trigger chỉ có trong test chặn hiệp thứ 2) | Đạt: 500 thông điệp chung, không thêm log/bài/hiệp nào, lịch vẫn SCHEDULED; gửi lại sau đó thành công |
| L07 | A gửi scheduleId của B | `ownershipIsEnforced` | Đạt: 404, lịch B không đổi |
| L08 | A đọc log/lịch của B | `ownershipIsEnforced` | Đạt: 404; danh sách của A rỗng |
| L09 | ID bài lạ | `invalidPayloadsAreRejected` | Đạt: 400 `exercises[0].exerciseId`. (Không có ID bài-trong-lịch riêng — docs/18 §1) |
| L10 | Reps 0/âm/>1000/10.5, tạ âm/>999,99/3 số lẻ/trống/NaN, bài trùng, 21 hiệp, giờ sai | `invalidPayloadsAreRejected`; unit test bản nháp | Đạt: 400 đúng trường, không lưu |
| L11 | Tạ 0 và số thập phân | `logFixtureCompletesSchedule`; widget test | Đạt: 0 và 22,5 đọc lại đúng |
| L12 | Lịch đã hủy / lịch tương lai | `cancelledAndFutureSchedulesAreRejected`; widget test | Đạt: 409 `INVALID_STATE`; app khóa nút "Chưa tới ngày tập" |
| L13 | Ghi muộn (lịch đã qua) | `lateLogKeepsScheduledDateAndFiltersByRange` | Đạt: `workoutDate` = ngày của lịch. (Không có MISSED — docs/16 §1) |
| L14 | Hủy và hoàn thành đồng thời | `cancelAndCompleteRace` | Đạt: một bên 409; COMPLETED ⇔ có đúng 1 log, CANCELLED ⇔ 0 log |
| L15 | MISSED đồng thời hoàn thành | Thiết kế | Không áp dụng: server không ghi MISSED |
| L16 | Sửa tên buổi/tên bài sau khi ghi | `snapshotsAndInactiveExercises` | Đạt: log giữ tên cũ |
| L17 | Bài trong buổi bị ẩn sau khi xếp lịch | `snapshotsAndInactiveExercises` | Đạt: ghi được; bài ngoài buổi đã ẩn → 422 |
| L18 | Lọc lịch sử sát ranh giới ngày | `lateLogKeepsScheduledDateAndFiltersByRange` | Đạt: khoảng đóng theo DATE, phân trang ổn định |
| L19 | Server đã lưu nhưng mất response | Widget test "Mất mạng sau khi gửi, server đã lưu" | Đạt: app hỏi lại lịch, thấy `workoutLogId`, mở kết quả, không gửi lại |
| L20 | Đóng/mở app sau khi lưu | Test tay §4 bước 12 | Đạt |
| L21 | JWT sai / thiếu | `requiresAuthentication` | Đạt: 401, không ghi |
| L22 | Bỏ một bài chưa tập | `snapshotsAndInactiveExercises`; unit test bản nháp | Đạt: log chỉ có bài đã tập |

## 4. Test tay trên Android

Người dùng tự thao tác trên điện thoại thật (tài khoản phonea/phoneb), 2026-11-04. 13/13 bước đạt.

| # | Thao tác | Kết quả |
|---|---|---|
| 1 | Xếp Buổi A hôm nay | Đạt |
| 2 | Xếp Buổi B ngày mai, mở chi tiết | Đạt: nút "Chưa tới ngày tập" bị khóa |
| 3 | Bấm Hoàn thành khi chưa nhập | Đạt: báo "Nhập số lần", không gửi |
| 4 | Nhập fixture 2 bài/4 hiệp, bỏ các bài còn lại, lưu | Đạt: xác nhận "2 bài, 4 hiệp"; kết quả 40 lần, 380 kg, hiện "22,5" |
| 5 | Quay lại lịch | Đạt: "Đã tập", có "Xem kết quả đã ghi" |
| 6 | Mở lịch sử, mở chi tiết | Đạt |
| 7 | Dời Buổi B về 01/11 (sửa DB vì app không cho xếp ngày đã qua), ghi muộn | Đạt: form báo ghi muộn, lưu theo ngày 01/11, không có giờ |
| 8 | Lọc 01/11–01/11, bỏ lọc | Đạt |
| 9 | Tắt backend, bấm Hoàn thành (Buổi C) | Đạt: banner "chưa xác nhận", dữ liệu còn |
| 10 | Bật backend, bấm lại | Đạt: lưu, mở kết quả, không trùng |
| 11 | Rời form khi đã nhập | Đạt: hỏi "Bỏ dữ liệu đang nhập?" |
| 12 | Đóng/mở app, xem lịch sử | Đạt |
| 13 | Đăng nhập phoneb | Đạt: lịch sử trống |

Bằng chứng phía server (DB local sau test):

| Người dùng | Ngày tập | Buổi | Lịch | Có giờ | Bài | Hiệp | Lần | Volume |
|---|---|---|---|---|---|---|---|---|
| phonea | 2026-11-04 | Buổi A | COMPLETED | có | 2 | 4 | 40 | 380,00 |
| phonea | 2026-11-01 | Buổi B | COMPLETED | không | 1 | 1 | 10 | 0 |
| phonea | 2026-11-04 | Buổi C | COMPLETED | có | 1 | 1 | 15 | 0 |

Lịch COMPLETED mà không có log: 0. Lịch có hơn một log: 0. phoneb: 0 log. Flyway: v8.

## 5. Tồn đọng

- Không sửa/xóa log, không tập tự do, không PR/1RM/biểu đồ (ngoài phạm vi ngày 8).
- Nháp chỉ giữ khi còn ở màn hình.
- Dashboard dùng dữ liệu log ở ngày 11.
