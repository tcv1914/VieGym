# Ngày 3 — Kết quả kiểm tra bộ khung

Ngày kiểm tra: 2026-10-23. Chỉ ghi kết quả đã chạy thật; mục chưa chạy ghi rõ **Chưa kiểm tra**.

## 1. Môi trường

| Thành phần | Phiên bản |
|---|---|
| JDK | 24.0.2 (project biên dịch `release 21`; máy chưa có JDK 21) |
| Spring Boot | 4.1.1 (Initializr), Flyway 12.4.0 |
| PostgreSQL | 17 (Docker, `infra/compose.yaml`, cổng `127.0.0.1:5432`) |
| Flutter | 3.47.7 stable; `http` ^1.6.0, `flutter_riverpod` ^3.4.3 |
| Python | 3.13.7; FastAPI 0.161.1, uvicorn 0.54.0 |
| Thiết bị Android | **Chưa kết nối** (`adb devices` trống) |

## 2. Kết quả

| Tình huống | Kết quả mong đợi | Kết quả thực tế |
|---|---|---|
| PostgreSQL nhận kết nối | `pg_isready` OK | ✅ `accepting connections` |
| Backend khởi động lần đầu | Flyway chạy V1 | ✅ `Successfully applied 1 migration ... now at version v1` |
| Lịch sử Flyway | V1 `success = t` | ✅ `1 \| create system probe \| t` |
| Health backend + DB | Trả message đọc từ DB | ✅ `{"status":"UP","service":"viegym-backend","database":"UP","message":"VieGym database connected"}` |
| Khởi động lại backend | Không chạy lại V1, không trùng bản ghi | ✅ `Schema "public" is up to date`; `flyway_schema_history` = 1 dòng, `system_probe` = 1 dòng |
| Dừng PostgreSQL | Không báo database UP giả | ✅ HTTP 500 sau 5,1 giây |
| Chạy lại PostgreSQL | Kết nối khôi phục, không cần khởi động lại backend | ✅ HTTP 200 ngay khi DB sẵn sàng |
| FastAPI health | Trả UP độc lập | ✅ `{"status":"UP","service":"viegym-ai"}` |
| FastAPI docs | Mở được | ✅ `/docs` HTTP 200 |
| `flutter analyze` | Không lỗi | ✅ `No issues found!` |
| Widget test màn kiểm tra | Thành công và lỗi + Thử lại | ✅ 2/2 test qua (provider giả lập) |
| App trên Android: thành công | Hiện message của DB | **Chưa kiểm tra** — chưa có thiết bị |
| App: dừng backend | Báo lỗi trong 10 giây | **Chưa kiểm tra** |
| App: chạy lại backend + Thử lại | Kết nối thành công | **Chưa kiểm tra** |

## 3. Lỗi gặp và cách xử lý

| Lỗi | Nguyên nhân | Xử lý |
|---|---|---|
| `Docker Desktop is unable to start` | Log: `WSL update required` | Cập nhật WSL rồi mở lại Docker Desktop |
| `spring-boot-starter-parent:pom:4.1.1.RELEASE` không tìm thấy | Initializr ghi `4.1.1.RELEASE` trong pom, Maven Central chỉ có `4.1.1` | Sửa `<version>4.1.1</version>` |
| `FATAL: invalid value for parameter "TimeZone": "Asia/Saigon"` | JVM trên Windows dùng tên múi giờ cũ, PostgreSQL 17 từ chối khi JDBC gửi lúc kết nối | Đặt `TimeZone.setDefault(UTC)` trong `BackendApplication` (khớp BR-G03: lưu UTC) |
| Dừng DB, request treo 30 giây | `connection-timeout` mặc định của Hikari là 30 giây, dài hơn timeout 10 giây của app | `spring.datasource.hikari.connection-timeout: 5000` |
| `ai-service/requirements.txt` mã hóa UTF‑16 | Tạo bằng `Out-File` của PowerShell 5.1 | Tạo lại bằng `pip freeze >` (UTF‑8) |

## 4. Cách chạy lại

```powershell
# Thư mục gốc
docker compose --env-file infra/.env -f infra/compose.yaml up -d

# Backend (terminal 1) — mật khẩu khớp infra/.env, không lưu vào YAML
cd backend
$env:DB_PASSWORD = '<mật khẩu PostgreSQL local>'
.\mvnw.cmd spring-boot:run

# AI service (terminal 2)
cd ai-service
.\.venv\Scripts\python.exe -m uvicorn main:app --reload --host 127.0.0.1 --port 8000

# Mobile (terminal 3) — adb nằm trong Android SDK
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:8080 tcp:8080
cd mobile
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

## 5. Còn tồn tại

- Chưa chạy app trên Android thật/emulator, chưa có ảnh màn hình.
- `adb` chưa có trong PATH; gọi bằng đường dẫn đầy đủ.
- Máy chưa có JDK 21; đang dùng JDK 24 (không phải LTS).
