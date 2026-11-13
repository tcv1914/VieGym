# Kiểm tra ngày 13 — Cân nặng và quên mật khẩu

Thiết kế: `29-weight-reset-design.md`. Ngày kiểm tra: 2026-11-12.

## 1. Môi trường

Như ngày 4–12. Migration **V13** đã chạy trên DB local. Thêm container **Mailpit** (`infra/compose.yaml`, `docker compose up -d mailpit`): backend gửi SMTP tới `127.0.0.1:1025`, đọc thư ở `http://127.0.0.1:8025`. Backend không cần biến môi trường mới khi dùng Mailpit.

## 2. Kiểm thử tự động

| Phần | Lệnh | Kết quả |
|---|---|---|
| Backend | `.\mvnw.cmd test` (PostgreSQL thật qua Testcontainers) | **154/154** đạt (18 mới: 8 `WeightLogIntegrationTests`, 10 `PasswordResetIntegrationTests` với `ResetCodeMailer` giả) |
| Mobile | `flutter analyze` | No issues found |
| Mobile | `flutter test` | **115/115** đạt (15 mới trong `test/weight_reset_test.dart`) |

## 3. Bộ nghiệm thu plan ngày 13

| Mã | Tình huống | Bằng chứng | Kết quả |
|---|---|---|---|
| W01 | Ba điểm fixture 70 / 69,5 / 69,8 | `fixtureIsListedAscendingByDate` (tăng dần theo ngày); mobile: `WeightChange` = -0,2 kg, màn hiện "Từ … đến …: -0,2 kg", một điểm vẫn có chấm + "Cần ít nhất 2 lần cân" | Đạt |
| W02 | Sửa bản ghi cũ | `logsDoNotChangeProfileAndDashboardShowsLatest`: ghi ngày cũ sau cùng, `latestWeightLog` vẫn là ngày mới nhất; mobile: sửa lần cân cũ không hỏi cập nhật hồ sơ | Đạt (theo BR-H02) |
| W03 | Xóa điểm mới nhất | Cùng test: xóa → `latestWeightLog` lùi về bản trước, cân nặng hồ sơ + mục tiêu giữ nguyên | Đạt (theo BR-H02) |
| W04 | B sửa/xóa log A | `otherUsersLogsAreInvisible`: DELETE → 404, GET của B rỗng, `userId` lạ trong body bị bỏ qua | Đạt |
| P01 | Email có/không tồn tại | `forgotPasswordAnswersTheSameForUnknownEmail`: cả hai `204` body rỗng; chỉ email thật được gửi; email chuẩn hóa (hoa/khoảng trắng) | Đạt |
| P02 | Mã hết hạn / đã dùng / sai | `wrongCodeFiveTimesInvalidatesTheCode` (5 lần sai → `used_at`, mã đúng sau đó cũng 400), `expiredCodeIsRejected`, `newCodeInvalidatesPreviousOne`, `unknownEmailOnResetIsInvalidCode`; mật khẩu giữ nguyên | Đạt |
| P03 | Hai request cùng mã | `concurrentResetsWithSameCodeSucceedOnce`: đúng một 204, một 400; chỉ một mật khẩu đăng nhập được | Đạt |
| P04 | Đặt lại thành công | `successfulResetChangesPasswordAndRevokesSessions`: mật khẩu cũ 401, mới 200, access token cũ 401, refresh cũ 401, mã dùng lại 400; DB chỉ có hash 64 ký tự | Đạt |
| P05 | Email/điện thoại thật | §5 | Không thử (user quyết định); test tay qua Mailpit 16/16 |

Thêm: `sameDateUpdatesExistingLog` (200, cùng id), `concurrentSameDateSavesKeepOneRow` (201 + 200, 1 dòng), `invalidInputIsRejected` (tương lai, 29,9 / 300,1 / 64,65 / 0, ghi chú 501 ký tự; biên 30 và 300 nhận), `rangeIsValidatedAndDefaultsToNinetyDays`, `forgotIsLimitedPerEmailSilently` (lần 4 vẫn 204, không tạo mã), `resetIsLimitedPerIp` (lần 11 → 429 + `Retry-After`, IP khác không ảnh hưởng), `invalidInputIsValidationError` (mã chữ, mật khẩu yếu, > 72 byte UTF-8).

Lỗi tìm được khi chạy test: lần đầu đặt lại "thành công" nhưng mật khẩu không đổi — câu UPDATE hàng loạt (`clearAutomatically`) xóa persistence context trước khi entity `User` kịp flush. Sửa: đổi mật khẩu rồi `flush()` trước các UPDATE hàng loạt.

## 4. Kiểm tra trên backend local

`POST /auth/forgot-password` cho `phonea` → 204; Mailpit nhận thư "VieGym - Mã đặt lại mật khẩu" (tiếng Việt hiển thị đúng) sau vài giây. Mã thử này đã xóa khỏi DB để không tính vào giới hạn 3 mã/giờ khi test tay.

## 5. Test tay Android

2026-11-13, điện thoại thật qua `adb reverse`, tài khoản `phonea` (cân nặng) và `phoneb` (quên mật khẩu), thư đọc qua Mailpit. User báo **16/16 đạt**.

| # | Nội dung | Kết quả |
|---|---|---|
| 1–3 | Màn trống; ghi 10/11 = 70 và 11/11 = 69,5; hỏi cập nhật hồ sơ → "Để sau"; một điểm vẫn có chấm | Đạt |
| 4–5 | Ghi hôm nay 69,8 rồi 69,7 (cùng ngày → vẫn 3 dòng, mất ghi chú) → "Cập nhật" hồ sơ | Đạt |
| 6 | Sửa 10/11 → 70,2: khóa ngày, không hỏi cập nhật hồ sơ, chênh lệch -0,5 kg | Đạt |
| 7–8 | Chặn 29,9 / 300,1 / 64,65 / ngày tương lai; đổi khoảng 30 ngày / 1 năm / 90 ngày | Đạt |
| 9–10 | Tổng quan: cân nặng hồ sơ + lần cân gần nhất; xóa lần cân hôm nay → lần cân gần nhất lùi về 11/11, hồ sơ giữ 69,7 | Đạt |
| 11 | `phoneb` không thấy lần cân của `phonea` | Đạt |
| 12–13 | Email lạ và email thật: cùng thông báo; chỉ email thật có thư, tiếng Việt đúng | Đạt |
| 14 | Mã sai → báo lỗi; mật khẩu yếu bị chặn ở app | Đạt |
| 15 | Đặt lại → về đăng nhập, email điền sẵn; mật khẩu cũ bị từ chối, mật khẩu mới vào được | Đạt |
| 16 | Gửi mã + "Gửi lại mã": mã cũ bị từ chối, mã mới đặt lại về `Matkhau123` | Đạt (user báo), xem ghi chú |

Đối chiếu DB sau test: `phonea` hồ sơ 69,7, còn đúng 2 lần cân (10/11 = 70,2; 11/11 = 69,5); `phoneb` không có lần cân, 7 phiên bị thu hồi, 1 phiên còn hoạt động; mã lưu dạng hash 64 ký tự; mã sai ở bước 14 tăng `attempt_count` lên 1.

**Ghi chú bước 16:** DB và Mailpit chỉ có **một** mã/thư mới trong bước này (14:04), và mã đó có `attempt_count = 0`; log backend không có dòng bỏ qua do giới hạn. Nghĩa là yêu cầu "Gửi lại mã" và lần nhập mã cũ không được ghi nhận phía server, dù user báo đã làm đúng các bước. Chưa rõ nguyên nhân (code app gọi cùng `POST /auth/forgot-password` như "Gửi mã"). Phía backend hành vi "mã mới vô hiệu mã cũ" đã có test tự động `newCodeInvalidatesPreviousOne`. Nên thử lại nút "Gửi lại mã" khi rà soát trước demo.

**P05 (email thật):** không thử theo quyết định của user; chỉ kiểm tra qua Mailpit.
