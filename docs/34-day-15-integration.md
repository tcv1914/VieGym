# Ngày 15 — Tích hợp, staging và đóng phạm vi (2026-11-15)

Plan ngày 15 gọi file này là `docs/33-day-15-integration.md`. Số docs lệch plan 1 vì docs/32 đã dùng cho ngày 14. Bảng trạng thái tính năng và backlog: `33-feature-freeze.md`.

## 1. Build và kiểm thử tự động

| Thành phần | Build | Kết quả |
|---|---|---|
| Backend | commit `602313d` + thay đổi ngày 15, `backend-0.0.1-SNAPSHOT.jar` → ảnh `viegym-backend:staging` | 167/167 test |
| Mobile | APK debug `viegym-staging-debug.apk`, `API_BASE_URL=http://127.0.0.1:18080` | 115/115 test |
| Admin | `admin/dist` (Vite build) phục vụ qua nginx | 7/7 Vitest |
| ai-service | ảnh `viegym-ai:staging` (python 3.13-slim) | 15/15 pytest |

## 2. Hành trình 7 bước bằng API trên staging

Script `infra/staging/journey_smoke.py` chạy plan §1 bằng HTTP vào backend staging, với Gemini thật. Kết quả: **39/39 PASS** (chạy lại 3 lần đều đạt).

| Bước plan | Kiểm tra | Kết quả |
|---|---|---|
| 1 Đăng ký → hồ sơ → mục tiêu | 201, login `hasHealthProfile=false`, PUT hồ sơ, có targets | Đạt |
| 2 Giáo án → lịch → ghi buổi → lịch sử | tạo từ mẫu, lịch hôm nay, log 201; **gửi lặp → 409 `WORKOUT_ALREADY_LOGGED` cùng `workoutLogId`**; lịch sử có đúng 1 buổi | Đạt |
| 3 Món → khẩu phần → bữa → tổng | tìm "pho" không dấu; 1,5 phần → tổng = 1,5 × kcal; có targets/remaining | Đạt |
| 4 Dashboard → chatbot | tổng kcal khớp thực đơn; buổi hôm nay COMPLETED, tuần completed = 1; chatbot nêu đúng món vừa ghi và số kcal còn thiếu (~2 s); gửi lặp cùng `clientRequestId` → cùng `requestId`, không gọi AI lần 2 | Đạt |
| 5 Cân nặng | ghi 64,6 → dashboard `latestWeightLog` = 64,6, hồ sơ giữ 65 (BR-H02); dữ liệu biểu đồ có bản ghi | Đạt |
| 6 Admin ẩn catalog | ẩn món → user 404, thêm vào bữa → 422, thực đơn cũ giữ mục và tổng; ẩn bài → thư viện 404, lịch sử buổi vẫn hiện tên bài; hiện lại cả hai | Đạt |
| 7 Đăng xuất A → B | refresh A → 401, access token A → 401; B: thực đơn, dashboard, lịch sử rỗng; B mở log/hội thoại của A → 404 | Đạt |

Lỗi tìm được: lần chạy đầu bước 6 báo 400 `region`. Lỗi nằm ở script: nó gửi lại nguyên body GET, trong đó `region`/`category` là object. Trang admin đã đổi đúng sang mã (`admin/src/pages/FoodForm.tsx:43`). API và trang admin không có lỗi. Câu trả lời của chatbot dùng dấu chấm thập phân, ghi thành BUG-03 (P3).

## 3. Staging

### 3.1 Cấu trúc

`infra/staging/compose.yaml` (project `viegym-staging`) tách hẳn khỏi DEV (`infra/compose.yaml`):

```
postgres (healthy: pg_isready) ──┐
ai-service (healthy: GET /health) ─┼─> backend (Flyway migrate lúc khởi động; healthy: GET /api/v1/system/health, có truy vấn DB) ──> admin (nginx)
mailpit (started) ────────────────┘
```

- Chỉ mở ra `127.0.0.1`: backend `18080`, admin `15173`, Mailpit `18025`. **PostgreSQL và ai-service không publish cổng**, chỉ nằm trong mạng nội bộ compose.
- Database `viegym_staging`, volume `viegym-staging_pgdata`: không dùng chung với dữ liệu DEV, cũng không phải dữ liệu demo cuối.
- Secret nằm trong `infra/staging/.env` và `infra/staging/secrets/` (khóa JWT RSA riêng). Cả hai bị `.gitignore` chặn (`git status --ignored` đã kiểm tra). File mẫu được commit: `infra/staging/.env.example`. Mật khẩu DB và `AI_INTERNAL_KEY` sinh ngẫu nhiên, khác DEV.
- Ảnh ai-service chỉ copy `main.py`, `providers.py`, `requirements.txt` (`.dockerignore`), nên không mang `.env` của DEV vào ảnh. Backend và ai-service chạy bằng user không phải root.
- Container chạy giờ UTC, còn máy DEV chạy +07. Ngày "hôm nay" vẫn đúng theo `users.timezone`, vì mọi chỗ dùng `clock.withZone(user timezone)`.
- Khởi động lạnh (`down` → `up`, giữ volume): 21 giây tới khi admin trả lời. Healthcheck chạy 2 giây/lần lúc khởi động, sau đó 30 giây/lần.
- Log đã rà sau smoke: chỉ có requestId, userId, thời lượng, kết quả. Không có token, mật khẩu hay số liệu sức khỏe. Khóa Gemini gửi qua header, không nằm trong URL hay log.

### 3.2 Chạy staging

```powershell
# 1. Build (mỗi lần đổi code)
backend> .\mvnw.cmd -DskipTests package
admin>   npm run build
mobile>  F:\flutter\bin\flutter.bat build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:18080

# 2. Chạy (lần đầu cần infra/staging/.env và secrets/ — xem .env.example, docs/09 §6 để sinh khóa)
infra\staging> docker compose up -d --build
infra\staging> docker compose ps          # tất cả healthy

# 3. Điện thoại thật qua USB
adb reverse tcp:18080 tcp:18080

# 4. Smoke
python -I -X utf8 infra/staging/journey_smoke.py
```

Dừng: `docker compose stop` (giữ dữ liệu). Xóa sạch: `docker compose down -v`.

### 3.3 Ma trận cấu hình

| | DEV | STAGING | RELEASE (chưa dựng) |
|---|---|---|---|
| API URL cho app | `http://127.0.0.1:8080` qua `adb reverse` | `http://127.0.0.1:18080` qua `adb reverse` | HTTPS, host công khai |
| Backend | `mvnw spring-boot:run` trên máy, nghe `127.0.0.1` | container `viegym-backend:staging`, publish `127.0.0.1:18080` | container sau reverse proxy TLS |
| Database | `infra-postgres-1`, DB `viegym`, `127.0.0.1:5432` | container riêng, DB `viegym_staging`, **không publish cổng** | PostgreSQL riêng, không mở Internet, có backup |
| Migration | Flyway khi backend khởi động | như DEV, sau khi postgres healthy | như STAGING |
| AI | uvicorn trên máy, `ai-service/.env` | container, `gemini-2.5-flash`, khóa trong `infra/staging/.env` | khóa riêng, có hạn mức |
| Email | Mailpit `:8025` | Mailpit riêng `:18025` | SMTP thật (`MAIL_*`) |
| Admin | Vite `:5173`, proxy `/api`, `/media` | nginx `:15173`, `admin/dist`, proxy sang backend | như STAGING, sau TLS |
| Allowed origins | không bật CORS: admin cùng origin qua proxy, mobile không phải trình duyệt | như DEV | như DEV, chỉ một origin admin |
| Log level | INFO | INFO (`LOGGING_LEVEL_*`) | INFO/WARN |
| Secret | `infra/.env`, `infra/secrets/`, `ai-service/.env` | `infra/staging/.env`, `infra/staging/secrets/` | secret manager / biến môi trường máy chủ |
| Admin bootstrap | `admin@viegym.vn` | `admin.staging@viegym.vn` (mật khẩu trong `infra/staging/.env`) | tạo một lần, đổi mật khẩu |

**Chưa xác nhận:** HTTPS, truy cập qua Internet/LAN, và điện thoại không cắm USB. Staging hiện là staging nội bộ trên máy dev.

Ghi chú truy cập:
- Điện thoại thật dùng `adb reverse`. `127.0.0.1` trên điện thoại là chính điện thoại, chỉ trỏ về PC nhờ reverse.
- Emulator dùng `10.0.2.2`.
- Từ container, gọi service khác bằng tên service (`backend`, `ai-service`).
- Muốn dùng qua Wi-Fi phải đổi `ports` sang IP LAN và build APK với IP đó. Chưa làm.

LIM-01: backend trong container thấy mọi client qua IP gateway Docker, nên giới hạn theo IP của reset dùng chung cho mọi máy. Release thật phải đọc IP client từ proxy tin cậy.

## 4. Hành trình trên Android + admin (test tay)

APK staging đã cài bản mới (gỡ app cũ), `adb reverse tcp:18080` đã bật, bảng 13 bước đã đưa user.

**Chưa thực hiện.** User báo "test xong đúng hết", nhưng lúc đối chiếu (13:57 UTC) DB staging không có dấu vết:
- không có tài khoản `a1@`/`b1@staging.viegym.vn`, user mới nhất là của script smoke (13:46);
- `admin_audit_logs` chỉ có 10 dòng của script smoke;
- app mới cài được vài phút, chưa đủ cho bước 13 (chờ 15 phút);
- không có yêu cầu tắt backend ở bước 10.

User chọn commit luôn, giống ngày 11 và 14. Bảng 13 bước là việc đầu tiên của ngày 16:

| # | Thao tác | Kết quả đúng |
|---|---|---|
| 1 | Đăng ký `a1@staging.viegym.vn`, rồi đăng nhập | Vào màn tạo hồ sơ |
| 2 | Hồ sơ, chiều cao 170,5 | BMI và mục tiêu kcal/macro |
| 3 | Giáo án mẫu → lịch hôm nay → ghi 22,5 kg → Hoàn thành | Lịch hoàn thành, lịch sử có 1 buổi |
| 4 | Tìm "pho", thêm bữa trưa 1,5 phần | Tổng = 1,5 × kcal |
| 5 | Tổng quan → chatbot "Hôm nay tôi ăn gì và tập gì?" | Số khớp, chatbot nêu đúng món và buổi |
| 6 | Cân 64,6, không cập nhật hồ sơ | Biểu đồ và Tổng quan hiện 64,6 |
| 7 | Admin ẩn món và bài vừa dùng | App không tìm thấy; thực đơn và lịch sử vẫn hiện. Hiện lại |
| 8 | Đăng xuất → `b1@` | Không còn dữ liệu A |
| 9 | Admin khóa B | B về đăng nhập, báo bị khóa. Mở khóa |
| 10 | Tắt backend, thêm món | Lỗi mạng, giữ input; thử lại chỉ 1 mục |
| 11 | Cỡ chữ lớn nhất | Không tràn, bàn phím không che nút |
| 12 | Gửi mã → Gửi lại mã → mã cũ → mã mới (Mailpit :18025) | Mã cũ bị từ chối, mã mới đổi được (BUG-02) |
| 13 | Để app mở hơn 15 phút, chuyển tab | Không bị đăng xuất (BUG-06) |

## 5. Rà trạng thái UI và dữ liệu (plan §2–§3)

Rà code mobile:
- Mọi màn có tải dữ liệu đều có loading, lỗi kèm "Thử lại" (`ErrorRetry` dùng chung) và trạng thái rỗng.
- Form giữ input khi lỗi server.
- 401 refresh single-flight. Lỗi mạng (`NetworkException`) không xóa phiên.
- 409: `VERSION_CONFLICT` của giáo án hỏi tải bản mới. `WORKOUT_ALREADY_LOGGED` mở log hiện có. Lịch đã hủy/hoàn thành thì tải lại.
- 429 chatbot hiện số giây chờ.
- Ghi buổi tập không tự retry POST: sau mất mạng thì xác minh qua `workoutLogId`. Chatbot retry bằng cùng `clientRequestId`.
- Mọi provider dữ liệu user `watch(authControllerProvider)` (dashboard khóa theo `userId`). Tab về Tổng quan sau khi đăng xuất.

Dữ liệu:
- Số hiển thị vi-VN, nhập nhận cả `,` và `.`.
- Chưa có hồ sơ thì `targets = null`, hiện "Chưa có mục tiêu" thay vì 0 (docs/24 bước 14).
- `?? 0` chỉ còn ở `version` giáo án.

Phần cần mắt người (cỡ chữ lớn, màn nhỏ, bàn phím che nút) nằm ở §4.

## 6. Checklist nghiệm thu

- [ ] Hành trình 7 bước chạy xuyên module trên staging. API: đạt 39/39. Android/admin: §4.
- [x] Có bảng trạng thái tính năng và backlog ưu tiên (docs/33).
- [x] Loading/rỗng/lỗi/retry nhất quán (rà code §5). Kiểm tra mắt §4.
- [x] Đổi user không lộ cache (API §2 bước 7, code §5). Timeout ghi không gây trùng (workout log 409, chatbot cùng `clientRequestId`).
- [x] Staging tách biệt, không có secret trong source.
- [ ] Ghi kết quả test tay §4 (chưa thực hiện, chuyển sang ngày 16).
