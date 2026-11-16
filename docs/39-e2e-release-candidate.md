# E2E Android và release candidate — ngày 18 (2026-11-15)

Plan gọi file này là `docs/38-e2e-release-candidate.md` (số docs lệch +1).

## 0. Trạng thái gate (cập nhật khi có kết quả)

| Tiêu chí RC (plan §6) | Trạng thái |
|---|---|
| Không còn P0/P1 mở | **Chưa đạt**: AI-01 (P1 cho demo, hết hạn mức Gemini miễn phí), xem docs/33 |
| Luồng chính PASS trên ít nhất một thiết bị thật | **Chưa chạy** (§2, §3) |
| APK trỏ đúng môi trường, không có secret hay endpoint lạ | Đạt (§1) |
| Công thức, snapshot, ownership regression | Một phần: oracle 109/109; journey bước 1–3, 5–6, 7.1–7.6 đạt. Ma trận truy cập 72/72 chạy ngày 17 **trước** khi nâng Tomcat/Jackson, cần chạy lại khi có AI |
| Timeout/retry và session trong release build | **Chưa chạy** trên thiết bị |
| P2/P3 còn lại có ghi chú | Có (docs/33 §2) |
| Commit, version, checksum, kết quả test | §1 |

**Chưa tag release candidate:** gate chưa đạt.

## 1. Artifact

| Mục | Giá trị |
|---|---|
| Commit mã nguồn | `91b4d09` + cấu hình mạng Android của ngày 18 (`network_security_config`) |
| APK | `mobile/build/app/outputs/flutter-apk/app-release.apk`, 54,1 MB |
| SHA-256 | `1e4e6ee45d8e9296996b545b11831426d44e4801ff9464f04ab28cded6206306` |
| Version | `versionName 1.0.0-rc.1`, `versionCode 1` (`--build-name/--build-number`) |
| Build | `flutter build apk --release --build-name=1.0.0-rc.1 --build-number=1 --dart-define=API_BASE_URL=http://127.0.0.1:18080`; trước đó `flutter analyze` sạch và `flutter test` 115/115 |
| API | STAGING nội bộ `http://127.0.0.1:18080` qua `adb reverse` (docs/34 §3). Đã kiểm trong `libapp.so`: URL duy nhất là `127.0.0.1:18080`; không có `10.0.2.2`, khóa `AIza…`, PEM hay mật khẩu test |
| Quyền Android | Chỉ `INTERNET` (cộng quyền nội bộ Flutter `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`); không `debuggable` |
| HTTP thường | Release chặn cleartext trừ `127.0.0.1`/`localhost` (`src/main/res/xml/network_security_config.xml`), để dùng staging qua USB. Debug giữ hành vi cũ (`src/debug/res/xml`). Bản công khai phải dùng `https://` |
| Ký | **Khóa debug** (`CN=Android Debug`, SHA-256 cert `90836d67…be10bd2`). **Không phải artifact phát hành cuối**; plan ngày 19 rà quy trình ký và lưu khóa |
| Backend/ai-service/admin | Ảnh staging build lại từ `91b4d09`: backend 173/173 test, ai-service 16/16, admin 9/9 |

Thiết bị: model `CPH2565`, Android 15, màn 1080×2400, nối USB với `adb reverse tcp:18080`. Đã gỡ bản cũ và cài APK release (cài mới). Chưa thử emulator.

## 2. E2E hành trình chính (test tay, NOT_RUN)

| ID | Thao tác | Điểm kiểm tra | Kết quả |
|---|---|---|---|
| E01 | Mở app (cài mới) → đăng ký `rc1@staging.viegym.vn` → đăng nhập → tạo hồ sơ (170,5 cm) | Không thiếu bước; BMI và mục tiêu hiện ra | NOT_RUN |
| E02 | Bài tập → Giáo án mẫu → kích hoạt → Lịch: tạo lịch hôm nay → ghi 2 hiệp (22,5 kg) → Hoàn thành → Lịch sử | Lịch "Hoàn thành", lịch sử 1 buổi, Tổng quan đúng | NOT_RUN |
| E03 | Món ăn: tìm "pho" → thêm bữa trưa 1,5 phần → sửa thành 2 → xóa | Tổng đúng sau mỗi bước, Tổng quan cập nhật | NOT_RUN |
| E04 | Cân nặng 64,6 → "không cập nhật hồ sơ" → biểu đồ | Ngày hôm nay, đơn vị kg; hồ sơ vẫn số cũ | NOT_RUN |
| E05 | Chat một câu → vuốt đóng app → mở lại → mở hội thoại | Lịch sử còn, không loading treo | NOT_RUN (phụ thuộc AI-01) |
| E06 | Đăng xuất → Quên mật khẩu → mã ở http://127.0.0.1:18025 → đặt lại → đăng nhập | Đăng nhập bằng mật khẩu mới được; phiên cũ (máy khác/script) bị chặn | NOT_RUN |
| E07 | Admin http://127.0.0.1:15173: ẩn món vừa dùng; khóa `rc1` | App: món không tìm được, thực đơn cũ vẫn còn; sau khi khóa, thao tác kế tiếp về màn đăng nhập "bị khóa" | NOT_RUN |

## 3. Mạng và vòng đời (test tay, NOT_RUN)

| ID | Thao tác | Kết quả đúng | Kết quả |
|---|---|---|---|
| N01 | Rút cáp USB (mất `adb reverse`) → thêm món | Báo lỗi mạng, giữ lựa chọn | NOT_RUN |
| N02 | Bấm Hoàn thành buổi tập rồi rút cáp ngay → cắm lại, `adb reverse` → mở lại lịch | App xác minh qua `workoutLogId`, không có log trùng | NOT_RUN |
| N03 | Gửi câu chat → đưa app xuống nền 30 s → quay lại | Không loading vô hạn; có câu trả lời hoặc nút thử lại | NOT_RUN |
| N04 | Rút cáp → đóng app → mở app | Màn "không kết nối" + Thử lại, **không** bị đăng xuất; cắm lại → Thử lại → vào app | NOT_RUN |
| N05 | Để app hơn 15 phút → mở Tổng quan (gọi nhiều API cùng lúc) | Không bị đăng xuất (một lần refresh) | NOT_RUN |
| N06 | Đăng xuất → đăng nhập tài khoản khác | Không thấy dữ liệu tài khoản trước, kể cả thoáng qua | NOT_RUN |
| N07 | App chỉ xin INTERNET | Không có hộp thoại xin quyền | Đạt (badging §1) |

App không hỗ trợ offline: ghi dữ liệu cần mạng; khi mất mạng thì báo lỗi và giữ input.

## 4. Thiết bị và trải nghiệm

| ID | Thao tác | Kết quả |
|---|---|---|
| U01 | Cỡ chữ hệ thống lớn nhất: Tổng quan, Thực đơn, form ghi buổi, chat | NOT_RUN |
| U02 | Bàn phím mở ở form hồ sơ/ghi buổi: nút Lưu vẫn bấm được; nút Back hỏi khi có thay đổi | NOT_RUN |
| U03 | Món tên dài, bài tập không có ảnh (Plank) | NOT_RUN |
| U04 | Cuộn hết danh sách món (912) và lịch sử | NOT_RUN |
| U05 | Ranh giới 00:00 / tuần theo múi giờ user | Đạt bằng test đồng hồ cố định phía server (T-D01, docs/36 §4); không đổi giờ thiết bị |

## 5. Hồi quy tự động trên staging (build trên)

| Bộ | Kết quả |
|---|---|
| `formula_oracle.py` (100 ca, seed 18) | 109/109 |
| `journey_smoke.py` | Mọi bước không dùng AI đều đạt. 4.3–4.5 FAIL: 502, provider hết quota (AI-01). Script dừng ở 7.7 vì cần hội thoại của bước 4 |
| `access_matrix.py` | Không chạy được hôm nay (fixture cần một câu trả lời AI). Lần 72/72 của ngày 17 chạy trước khi nâng Tomcat/Jackson |
