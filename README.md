# VieGym

Ứng dụng Android hỗ trợ luyện tập và dinh dưỡng,
tích hợp chatbot AI theo ngữ cảnh người dùng.

## Công nghệ

- Flutter và Riverpod (`mobile/`)
- Spring Boot và Spring Security (`backend/`)
- PostgreSQL (`infra/`)
- Python FastAPI + Gemini (`ai-service/`)
- React và TypeScript (`admin/`)

## Trạng thái

Bản release candidate `1.0.0-rc.1` (ngày 18), chưa tag: còn chờ test tay E2E và quyết định hạn mức Gemini. Chi tiết ở `docs/39-e2e-release-candidate.md`.

## Cài đặt và chạy (Windows, PowerShell)

Dữ liệu mẫu (bài tập, món ăn, giáo án, ảnh bài tập) nằm sẵn trong migration Flyway, backend tự nạp ở lần chạy đầu. **Secret không có trong Git**: mỗi người tự tạo mật khẩu DB, khóa JWT và khóa Gemini theo các bước dưới.

### 0. Công cụ cần cài

- Git, Docker Desktop
- JDK 21
- Python 3.13
- Node.js (trang admin)
- Flutter SDK (Dart ≥ 3.13), Android SDK/adb (app điện thoại)
- OpenSSL (có sẵn trong Git for Windows)

### 1. Lấy mã nguồn

```powershell
git clone https://github.com/tcv1914/VieGym.git
cd VieGym
```

### 2. Tạo secret

```powershell
# Mật khẩu PostgreSQL: mở infra\.env và điền POSTGRES_PASSWORD=<mật khẩu tự đặt>
copy infra\.env.example infra\.env

# Khóa ký JWT (đường dẫn mặc định backend đọc)
mkdir infra\secrets
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out infra/secrets/jwt-private.pem
openssl pkey -in infra/secrets/jwt-private.pem -pubout -out infra/secrets/jwt-public.pem

# AI: mở ai-service\.env, điền GEMINI_API_KEY (lấy ở Google AI Studio)
# và AI_INTERNAL_KEY (chuỗi ngẫu nhiên dài, backend dùng cùng giá trị)
copy ai-service\.env.example ai-service\.env
```

### 3. Database và hộp thư test

```powershell
cd infra
docker compose up -d
cd ..
```

- PostgreSQL: `127.0.0.1:5432` (database và user `viegym`)
- Mailpit (xem email quên mật khẩu): http://127.0.0.1:8025

### 4. ai-service (terminal riêng)

```powershell
cd ai-service
python -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt
.\.venv\Scripts\python.exe -m uvicorn main:app --host 127.0.0.1 --port 8000
```

### 5. Backend (terminal riêng)

```powershell
cd backend
$env:DB_PASSWORD = '<giống POSTGRES_PASSWORD>'
$env:AI_INTERNAL_KEY = '<giống trong ai-service\.env>'
# Chỉ cần ở lần chạy đầu để tạo tài khoản admin:
$env:ADMIN_EMAIL = 'admin@viegym.vn'
$env:ADMIN_PASSWORD = '<mật khẩu admin>'
.\mvnw.cmd spring-boot:run
```

Backend chạy ở http://127.0.0.1:8080. Chạy test: `.\mvnw.cmd test` (dùng Testcontainers, cần Docker Desktop đang chạy).

### 6. Trang admin (tùy chọn)

```powershell
cd admin
npm ci
npx vite
```

Mở http://127.0.0.1:5173 và đăng nhập bằng tài khoản admin ở bước 5. Vite proxy `/api` và `/media` sang backend.

### 7. App Android

Cắm điện thoại qua USB, bật USB debugging:

```powershell
cd mobile
flutter pub get
adb reverse tcp:8080 tcp:8080
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

- Emulator: dùng `API_BASE_URL=http://10.0.2.2:8080`, không cần `adb reverse`.
- Cài APK: `flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:8080` rồi `adb install -r build\app\outputs\flutter-apk\app-debug.apk`.
- Bản release chỉ cho HTTP thường tới `127.0.0.1`/`localhost`; máy chủ khác phải dùng `https://`.

### Lưu ý

- DB mới chưa có tài khoản người dùng: đăng ký trong app.
- Gemini bản miễn phí chỉ khoảng 20 request/ngày; hết hạn mức thì chatbot trả lỗi.
- Môi trường staging chạy toàn bộ bằng Docker: xem `docs/34-day-15-integration.md` §3 và `infra/staging/.env.example`.

## Tài liệu

- Phạm vi: `docs/pham-vi-mvp.md`, `docs/33-feature-freeze.md`
- Use case, database, nghiệp vụ, API: `docs/02`–`docs/05`
- Kịch bản demo: `docs/kich-ban-demo.md`
- Kế hoạch theo ngày: `plan/`
