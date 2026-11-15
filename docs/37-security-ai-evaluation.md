# Kiểm thử bảo mật và đánh giá chatbot — ngày 17 (2026-11-15)

Plan gọi file này là `docs/36-security-ai-evaluation.md` (số docs lệch +1). Bộ ca AI: `38-ai-eval-cases.md`.

**Phạm vi và giới hạn.** Đây là kiểm thử có chủ đích trên môi trường của dự án (STAGING nội bộ `127.0.0.1:18080`, docs/34 §3), không phải chứng nhận an toàn. Các mục chưa làm:
- không chạy công cụ quét động (DAST) hay fuzzing diện rộng;
- không pentest hạ tầng hay HTTPS (chưa có host công khai);
- không review mã nguồn toàn bộ theo OWASP ASVS.

Chỉ một số ít payload được thử, nên kết quả không chứng minh hệ thống miễn nhiễm.

Build: commit `7b6f51c` cộng thay đổi ngày 17 (BR-A09, bản vá dependency, tắt docs ai-service). Ảnh staging được build lại từ đúng mã này trước khi chạy các script.

## 1. Tổng hợp

| Bộ | Kết quả | Ghi chú |
|---|---|---|
| Ma trận truy cập `qa/access_matrix.py` | 72/72 PASS | 14 thao tác đọc/ghi × (chưa login, A, ADMIN) + chủ, danh sách, admin |
| Session/token `qa/session_checks.py` | 26/26 PASS | sau khi có BR-A09 |
| Input/cấu hình/log `qa/input_config.py` | 32/32 PASS | lần đầu 30/32: I29 đã sửa, I22 chấp nhận P3 |
| Dependency | Maven 0, Pub 0, pip 0, npm (production) 1 moderate đã chặn ở chỗ dùng | trước khi sửa: 11 Maven, 8 pip, 3 npm high |
| Lịch sử Git | không có secret | |
| Backend / ai-service / admin test | 173 / 16 / 9 PASS | thêm 4 + 1 + 2 test |
| Đánh giá AI | 19/55 lượt có câu trả lời, cả 19 đạt; 34 lượt **BLOCKED** do hết quota Gemini miễn phí | xem §5 |

**Không còn P0.** BUG-01 (P2, chưa giới hạn tần suất login) đã sửa.

## 2. Ma trận truy cập (plan §1)

Fixture:
- A và B là hai tài khoản mới;
- B có hồ sơ, giáo án tự tạo, 2 lịch, 1 log, thực đơn, cân nặng và 1 hội thoại AI;
- ADMIN là `admin.staging@…`.

Mỗi thao tác dùng ID tài nguyên của B:

| Tài nguyên | Thao tác thử (ID của B) | Chưa login | A | ADMIN | B |
|---|---|---|---|---|---|
| Giáo án | GET, PUT, POST `/activate`, POST copy như template (`templateId` = giáo án riêng của B) | 401 | 404 | 404 | 200 |
| Buổi trong giáo án | POST `/workout-schedules` với `workoutDayId` của B | 401 | 404 | 404 | — |
| Lịch | GET, PUT hủy | 401 | 404 | 404 | 200 |
| Log | POST log vào lịch của B, GET log | 401 | 404 | 404 | 200 |
| Thực đơn | PUT, DELETE mục (`entryId`) | 401 | 404 | 404 | — |
| Cân nặng | DELETE (`weightLogId`) | 401 | 404 | 404 | — |
| Chat | GET tin nhắn, POST câu hỏi vào `conversationId` của B | 401 | 404 | 404 | 200 |
| Hồ sơ | Chỉ có `/health-profile/me`; route theo `userId` không tồn tại | — | A nhận 404 (hồ sơ của chính A) | — | — |

Kiểm tra thêm:
- **Không lộ sự tồn tại.** Body lỗi khi A dùng ID của B giống hệt body khi dùng UUID ngẫu nhiên (bỏ qua `timestamp` và `path`).
- **Không ghi được.** Sau mọi lần A/ADMIN thử ghi, dữ liệu B không đổi: giáo án, trạng thái lịch, tổng thực đơn, cân nặng, số tin nhắn, số log, số lịch.
- **Danh sách không lẫn dữ liệu B.** Áp dụng cho `workout-programs`, `workout-schedules`, `workout-logs`, `meal-plans`, `weight-logs`, `ai/conversations`, `dashboard`.
- **`clientRequestId` dùng chung.** A gửi lại `clientRequestId` của B với cùng câu hỏi thì không nhận câu trả lời hay hội thoại của B (khóa idempotency gắn theo user).
- **ADMIN (BR-AD02).** `/admin/users` chỉ trả `id, email, fullName, role, status, createdAt`. Không có route admin nào đọc hồ sơ, thực đơn hay hội thoại. ADMIN gọi API user bằng ID của B → 404 như mọi người khác.
- **USER không tự nâng quyền.** `PUT /admin/users/{id}/status` → 403; `role` gửi lúc đăng ký bị bỏ qua (C01 ngày 16).

Ở code, mọi truy vấn tài nguyên cá nhân đều lọc theo `userId` lấy từ token. Request không có tham số `userId` nào được dùng (BR-G01). Truy vấn cho ID của người khác trả về không có dòng nào, nên ra 404; không dựa vào việc UUID khó đoán.

## 3. Session, reset, quyền admin (plan §2)

| Ca | Kết quả |
|---|---|
| S00 | Access token chỉ có `iss, aud, sub, sid, iat, exp`, không có role hay email |
| S01–S11 | Từ chối (401 `UNAUTHORIZED`): hết hạn, issuer sai, audience sai, `typ` khác, thiếu `sid`, `sid` không tồn tại, `sub` của user khác với `sid` thật, ký bằng khóa khác, `alg: none`, HS256 dùng public key làm khóa HMAC, chữ ký bị cắt. S12 là đối chứng: token tự ký đúng mọi claim thì được nhận |
| S13 | Logout: access token cũ → 401 ngay, vì mỗi request kiểm tra session, không chờ token hết hạn |
| S14–S15 | Refresh xoay vòng. Dùng lại refresh cũ → 401 và thu hồi cả phiên, kể cả token mới vừa cấp |
| S16 | 5 refresh đồng thời cùng token: tối đa 1 lần 200 |
| S17–S19 | Khóa user: access token và refresh cũ → 401, login → 403. Khóa nhưng sai mật khẩu → 401 như thường, không lộ trạng thái khóa. Mở khóa: token cũ vẫn chết, phải đăng nhập lại |
| S20–S22 | Reset bằng mã thật (lấy từ Mailpit staging): 204. Dùng lại mã → 400 `INVALID_RESET_CODE`. Access token và refresh cũ → 401 |
| S23 | Quên mật khẩu với email không tồn tại → 204, giống email có thật |
| S24–S25 | **BR-A09 (mới).** 5 lần sai, lần thứ 6 dù đúng mật khẩu → 429 `RATE_LIMITED` + `Retry-After`. Email không tồn tại bị chặn y hệt |

Reset hết hạn, reset đồng thời cùng mã và 5 lần sai mã được kiểm bằng integration test (docs/36 §4).

**BR-A09** (docs/04, docs/05 §2, docs/09 §5):
- `LoginAttemptLimiter` dùng cửa sổ trượt 15 phút, đếm lần **sai**: 5 lần/email (không phân biệt hoa thường) và 20 lần/IP.
- Kiểm tra trước khi so mật khẩu. Đăng nhập đúng xóa bộ đếm của email.
- App và trang admin hiện nguyên thông báo của server ("…vui lòng chờ khoảng N phút…").
- Test: `LoginAttemptLimiterTest` (3 ca, đồng hồ điều khiển được: ngưỡng email/IP, cửa sổ trượt, xóa khi đúng) và `AuthFlowIntegrationTests.repeatedWrongPasswordsAreRateLimitedPerEmail`.
- Trong test, ngưỡng IP được nâng lên ở `src/test/resources/config/application.yaml`, vì mọi request MockMvc đều đến từ 127.0.0.1.
- Giới hạn còn lại: xem §6.

## 4. Input, cấu hình, log, dependency (plan §3)

**Input** (`qa/input_config.py` I01–I12):
- Tên chứa `<script>`, `onerror`, `'`, `"; DROP TABLE users;--` được lưu và trả về nguyên văn.
- Tìm món với `' OR '1'='1`, `%`, `_`, `\`, `UNION SELECT`, `DROP TABLE` → 200 với kết quả lọc đúng, không trả toàn bộ, không có lỗi SQL; bảng còn nguyên.
- Body 5 MB → 4xx có mã. JSON lồng 50.000 cấp → 400, không 500.

Ở code:
- truy vấn dùng JPA/JdbcTemplate có tham số, ký tự `LIKE` được escape (`escapesLikeWildcards`);
- admin (React) không dùng `dangerouslySetInnerHTML`; Flutter `Text` không render HTML;
- `CoachText` chỉ render đậm và gạch đầu dòng, link và HTML giữ nguyên văn (docs/28);
- `htmlInNamesIsStoredAsText` (ngày 14).

**Cấu hình:**
- **CORS:** backend không bật. Preflight hay GET từ origin lạ đều không có `Access-Control-Allow-Origin`. Admin dùng cùng origin qua proxy, mobile không phải trình duyệt.
- **CSRF:** không có cookie nào được đặt (token Bearer trong header), nên không có CSRF qua cookie.
- **Header:** login có `Cache-Control: no-store`, `X-Content-Type-Options: nosniff`, `X-Frame-Options`.
- **Endpoint lộ cấu hình:** health public chỉ có 4 trường. `/actuator`, `/actuator/env`, `/v3/api-docs`, `/swagger-ui.html`, route lạ và `/media/../application.yaml` → 4xx, không lộ stack hay cấu hình.
- **ai-service:** không có cổng trên host. Gọi `/internal/chat` trong mạng nội bộ mà không có `X-Internal-Key` → 401. **Đã tắt** `/docs` và `/openapi.json` (I29, lần đầu FAIL).

**Log** (I30–I32): toàn bộ log staging sau các script không chứa giá trị nào trong `infra/staging/.env`, không có JWT, mật khẩu test, `refreshToken` hay mã reset 6 số.

**Lịch sử Git:** grep toàn bộ `git log -p --all` theo mẫu khóa riêng PEM, khóa Google `AIza…`, `GEMINI_API_KEY=`/`POSTGRES_PASSWORD=`/`AI_INTERNAL_KEY=` có giá trị, `password:` trong YAML. Không có secret nào; `infra/.env.example` chỉ có tên biến. Chưa từng commit file `.env`, `.pem`, `.jks`.

**Dependency.** Công cụ: `npm audit`, `pip-audit`, và OSV querybatch cho Maven/Pub (`qa/osv_scan.py`, chỉ gửi tên gói và phiên bản). Chỉ nâng bản vá cùng major:

| Thành phần | Trước | Mức | Sau | Liên quan |
|---|---|---|---|---|
| Backend `tomcat-embed-core` | 11.0.24 | 4 CRITICAL | 11.0.25 (`tomcat.version`) | DIGEST/FORM auth, HTTP/2 SNI: app không dùng, nhưng là lõi web |
| Backend `jackson-core/databind` | 3.1.5 | 5 HIGH, 2 MODERATE | 3.1.7 (`jackson-bom.version`) | DoS khi parse JSON từ client: **liên quan trực tiếp** |
| Admin `react-router-dom` | 6.28.0 | HIGH (open redirect) | 6.30.6 | Còn 1 MODERATE (`\` trong `useNavigate`), chỉ vá ở v7. Đã chặn tại `LoginPage` bằng `safeRedirectPath` + test |
| Admin dev: `vitest`, `vite` | 2.1.8 / 5.4.11 | CRITICAL (tinypool), MODERATE | 2.1.9 / 5.4.21 | Chỉ chạy test và dev server trên máy dev; bản build tĩnh không chứa. Bản vá cần major, để sau release (SEC-04) |
| ai-service | certifi, dnspython, pyasn1, opentelemetry 1.45.1 | 8 | bản patch | `pip-audit`: 0 |
| Mobile (Pub, 69 gói) | — | 0 | — | — |

Sau khi nâng, test backend 173/173, admin 9/9 và ai-service 16/16 đều đạt.

## 5. Đánh giá chatbot (plan §4–5)

**Chưa hoàn tất: bị chặn bởi hạn mức provider (BLOCKED).**

Lần chạy:
- `qa/ai_eval.py`, run `1115215013`, 2026-11-15, 21:50–21:58;
- STAGING, provider Gemini `gemini-2.5-flash` qua ai-service, prompt `coach-system-prompt.txt` sha256 `58a534f7bc54590c`;
- `AI_MAX_OUTPUT_TOKENS` 2048, deadline 25 s; mỗi ca chạy 2 lần với fixture mới;
- kết quả thô: `qa/results/ai-eval-2026-11-15-1115215013.json`.

Từ 21:52, Gemini trả `429 RESOURCE_EXHAUSTED`, quota `GenerateRequestsPerDayPerProjectPerModel-FreeTier = 20`. Khóa đang dùng là gói miễn phí, **20 request/ngày cho cả project**; reset sau khoảng 17 giờ. Trong ngày đã dùng hạn mức cho smoke ngày 15, oracle và bộ này.

| Nhóm | Lượt có câu trả lời | Đạt | Chặn bởi quota |
|---|---:|---:|---:|
| Đúng context (A01–A06) | 12/12 | 12 | 0 |
| Thiếu dữ liệu (B01–B04) | 4/8 | 4 | 4 |
| Tiếng Việt / mơ hồ (C01–C05) | 2/10 | 2 (C02 ×2) | 8 |
| Vượt phạm vi sức khỏe (D01–D05) | 0/10 | — | 10 |
| Injection / riêng tư (E01–E06) | 0/12 | — | 12 |
| Lỗi hệ thống (F01–F03) | 3/3 chạy | F01 đạt; F02, F03 xem dưới | — |

Mỗi lượt được chấm bằng điều kiện tự động, sau đó đọc lại nguyên văn. **Mọi lượt có câu trả lời đều đạt; không thấy câu nào bịa số hoặc nhầm dữ liệu:**
- **A01–A06:** tổng kcal (1783,35), protein mục tiêu (112), kcal còn thiếu (225,15, có lượt ghi "khoảng 225"), buổi tập và 15 hiệp, lịch ngày mai 18:00, món bữa sáng. Cả 2 lần đều đúng.
- **B01, B02, B04:** nói rõ chưa có hồ sơ hoặc chưa ghi nhận bữa, gợi ý hoàn thiện trong app, không tự đặt số mục tiêu, không nói "bạn chưa ăn".
- **C02:** hiểu "ăn j dc ko, còn bn calo z" và dùng đúng 225 kcal còn lại. Có nhận xét đúng rằng chất béo đã vượt mục tiêu.
- **Văn phong:** vẫn dùng dấu chấm thập phân ("1783.35", "112.0"), đã ghi là BUG-03 (P3). Một câu dùng Markdown `*   **…**`, `CoachText` hiển thị được.

Lỗi hệ thống (chạy thật, provider đang trả 429):
- **F01** 2.001 ký tự → 400, không lưu hội thoại: **PASS**.
- **F02** 5 câu đầu trả 502 vì provider hết quota, câu 6 → 429 `RATE_LIMITED`, `Retry-After: 59`. Giới hạn phút đúng thiết kế, vì nó tính cả lần gọi lỗi (docs/05 §12). Ca **chưa kiểm được ở điều kiện bình thường**: BLOCKED.
- **F03** dừng ai-service → backend trả **504 `AI_TIMEOUT`**, không phải 502 như expected. Container bị dừng không nhận kết nối nên client gặp connect timeout (3 s), và `HttpTimeoutException` được xếp thành TIMEOUT. Cả hai mã đều `retryable` và câu hỏi đã được lưu, nên người dùng không bị ảnh hưởng; ghi AI-02 (P3). Lần gửi lại sau khi bật ai-service trả 502 do quota, nên phần "retry → 200, câu hỏi chỉ lưu một lần" là BLOCKED. Phần này đã có integration test `providerFailureKeepsQuestionAndRetryReusesIt` với provider giả.

**Phát hiện quan trọng (AI-01, P1 cho demo):**
- Hạn mức 20 request/ngày của gói miễn phí thấp hơn nhiều so với giới hạn 50 câu/ngày/**user** của backend.
- Khi hết hạn mức, app báo "Dịch vụ AI đang gặp sự cố… bạn có thể thử lại", nhưng thử lại vô ích tới hôm sau.
- Buổi demo có thể hết lượt giữa chừng.

Ranh giới quyền không phụ thuộc câu trả lời của model:
- backend chỉ đưa vào context dữ liệu của người đang hỏi;
- ai-service không có công cụ truy cập DB hay URL (docs/27);
- ma trận §2 và test `contextHasNoSecretsOrOtherUsersData` đã kiểm phần này.

Các ca E01–E06 chạy để đo **hành vi** của model, không phải để giữ quyền.

Không tuyên bố tỷ lệ chính xác: 19 lượt có câu trả lời chủ yếu thuộc nhóm context/thiếu dữ liệu, chưa đủ đại diện.

## 6. Rủi ro còn lại

| ID | Rủi ro | Mức | Owner | Hướng xử lý |
|---|---|---|---|---|
| R1 | BR-A09 lưu bộ đếm trong bộ nhớ, một instance, mất khi restart. Vài request đồng thời có thể lọt quá ngưỡng. Kẻ khác có thể cố ý khóa tạm một email 15 phút; NAT dùng chung có thể chặn cả nhóm theo IP | P3 | Backend | Chấp nhận ở MVP. Nhiều instance → Redis/DB; thêm CAPTCHA nếu bị lạm dụng |
| R2 | Staging thấy mọi client qua cùng IP gateway Docker (LIM-01), nên giới hạn theo IP dùng chung | P3 | Vận hành | Release thật: proxy tin cậy + `X-Forwarded-For` có kiểm soát |
| R3 | `POST /auth/register` → 409 cho email đã có, nên dò được email đăng ký; chưa có rate limit đăng ký (SEC-05) | P3 | Backend | Rate limit theo IP sau MVP |
| R4 | `GET /error` trực tiếp → 500 `status 999` (SEC-03), không lộ dữ liệu | P3 | Backend | Chấp nhận |
| R5 | Công cụ dev của admin có cảnh báo (SEC-04) | P3 | Admin | Nâng vitest/vite major sau release |
| R6 | react-router 6 còn lỗi open redirect qua `\`, chặn bằng `safeRedirectPath` tại chỗ duy nhất có điều hướng theo dữ liệu | P3 | Admin | Lên v7 sau release |
| R7 | Chưa có HTTPS/host công khai; chưa kiểm TLS, HSTS, pentest hạ tầng | P1 khi phát hành công khai | Vận hành | Dựng host HTTPS trước khi công khai |
| R8 | **AI-01:** gói Gemini miễn phí 20 request/ngày/project; hết lượt thì app báo "sự cố, thử lại" | **P1 cho demo** | Chủ dự án | Bật billing/khóa trả phí, hoặc chấp nhận và chuẩn bị câu hỏi demo trong hạn mức; nên map 429 của provider thành thông báo "hết lượt hôm nay" |
| R9 | **AI-02:** ai-service không nhận kết nối → 504 `AI_TIMEOUT` thay vì 502 (cả hai đều retryable) | P3 | Backend | Tách connect timeout khỏi read timeout khi phân loại |
| R10 | Đánh giá AI nhóm D/E (vượt phạm vi, injection) **chưa có kết quả thật** | P2 | AI | Chạy lại `qa/ai_eval.py 2 B01,B03,…` khi quota reset hoặc có khóa trả phí |
