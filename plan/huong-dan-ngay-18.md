# VieGym — Ngày 18: Kiểm thử E2E Android và chốt release candidate

**Mục tiêu:** Có bản ứng viên phát hành chạy trên điện thoại thật, kèm kết quả hồi quy. **Thời lượng:** 7–8 giờ.

## 0. Chuẩn bị — 30 phút

- [ ] P0/P1 ngày 16–17 đã sửa hoặc vẫn được đánh dấu chặn phát hành.
- [ ] Có điện thoại Android thật, emulator bổ sung nếu có.
- [ ] Staging có dữ liệu demo, AI/email thật cấu hình trong hạn mức.
- [ ] Có build number/version và commit cho từng artifact.

Tạo `docs/38-e2e-release-candidate.md`. Ghi model thiết bị, Android version, kích thước màn, mạng, build mode và API environment. Kết quả trên emulator không thay thế hoàn toàn thiết bị thật.

## 1. Tạo bản kiểm thử gần release — 45 phút

Build với cấu hình staging, không dùng debug server hoặc dữ liệu mock ngoài ý muốn. Trước khi chạy lệnh, xác nhận dự án đọc biến API_BASE_URL; `--dart-define` không tự tạo logic đọc biến.

```powershell
# Chạy trong thư mục Flutter; thay URL bằng staging thật
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://staging.example.invalid
```

Domain trên là placeholder, phải thay trước build. Signing phải theo cấu hình release của dự án; không coi APK dùng debug signing là artifact phát hành cuối. Quy trình ký và lưu khóa được rà lại ngày 19.

## 2. E2E hành trình chính — 120 phút

| ID | Chuỗi thao tác | Điểm kiểm tra |
|---|---|---|
| E01 | Cài mới → đăng ký → login → profile | Không thiếu bước, target đúng |
| E02 | Thư viện → giáo án → lịch → hoàn thành | Log/lịch/history nhất quán |
| E03 | Tìm món → thêm → sửa → xóa | Tổng chính xác và dashboard refresh |
| E04 | Thêm cân nặng → biểu đồ | Ngày/đơn vị và current profile đúng |
| E05 | Chat → đóng app → mở lại | Lịch sử và trạng thái request đúng |
| E06 | Forgot password → email → reset | Login mới được, session cũ bị chặn |
| E07 | Admin vô hiệu món/khóa user | Mobile phản ánh đúng ở request kế tiếp |

Chụp ảnh hoặc video ngắn những mốc quan trọng bằng dữ liệu demo. Gắn evidence với ID case, tránh ghi lại token hoặc thông tin email cá nhân.

## 3. Mạng và vòng đời ứng dụng — 90 phút

1. Tắt mạng trước gửi: có lỗi và giữ dữ liệu nhập.
2. Tắt mạng ngay sau gửi meal/log: sau kết nối lại tải trạng thái hoặc retry cùng key, không trùng bản ghi.
3. Đưa app xuống nền khi chat chờ: khi quay lại đồng bộ lịch sử, không loading vô hạn.
4. Đóng app rồi mở: refresh flow hợp lệ, không buộc login vì lỗi mạng tạm thời.
5. Hết hạn access khi nhiều API chạy: chỉ một refresh cùng lúc, request chờ được xử lý.
6. Đăng xuất rồi login B: không flash dữ liệu A từ cache.
7. Từ chối quyền không cần thiết: app vẫn dùng được các chức năng không phụ thuộc quyền đó.

Không ghi “offline supported” chỉ vì màn cũ còn hiển thị. Nếu chưa có queue/sync được thiết kế, hiển thị rõ cần mạng để ghi dữ liệu.

## 4. Thiết bị, ngày giờ và trải nghiệm — 60 phút

- Thử bàn phím che form, nút Back, màn nhỏ, text scaling và tên món dài.
- Thử ngày địa phương gần 00:00 và ranh giới tuần bằng test clock hoặc fixture server, tránh thay giờ thiết bị làm hỏng TLS rồi hiểu nhầm lỗi app.
- Kiểm tra ngày meal theo date user chọn, lịch theo timezone, log theo thời gian thực hiện.
- Màn ảnh lỗi có fallback; không kẹt màn trống khi thiếu media.
- Cuộn danh sách nhiều phần tử và mở lịch sử không crash hoặc tải vô hạn.

## 5. Hồi quy sau sửa — 60 phút

Chạy lại smoke suite sau mỗi nhóm sửa: login, đọc dashboard, tạo meal, hoàn thành workout, chat, logout. Chạy full suite liên quan nếu sửa auth/schema hoặc service dùng chung.

Mỗi lỗi có bước tái hiện, build bị lỗi, commit sửa và build retest. Không đổi code sau lần test cuối rồi giữ nhãn “đã kiểm thử” cho artifact mới.

## 6. Tiêu chí release candidate — 30 phút

- [ ] Không còn P0/P1 mở.
- [ ] Tất cả luồng chính PASS trên ít nhất một thiết bị thật.
- [ ] APK trỏ đúng môi trường, không có secret hoặc endpoint local.
- [ ] Công thức, snapshot và ownership regression PASS.
- [ ] Timeout/retry và session được kiểm tra trong release build.
- [ ] P2/P3 còn lại có workaround và được ghi rõ trong release notes.
- [ ] Có commit, version/build, checksum APK và kết quả test đi kèm.

Tạo nhãn release candidate theo quy ước Git của dự án sau khi kiểm tra trạng thái working tree. Không tag nếu vẫn có thay đổi chưa kiểm thử. Nếu fail gate, dùng buffer và lùi phần trang trí báo cáo; không đổi FAIL thành PASS để đúng lịch.

Tham khảo: [Flutter — Build and release an Android app](https://docs.flutter.dev/deployment/android).
