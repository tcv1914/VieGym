# Thiết kế xác thực và phiên đăng nhập — VieGym

Áp dụng từ ngày 4. Quy tắc nghiệp vụ gốc: BR-A01..A05 (`04-business-rules.md`); hợp đồng API: `05-api-contract.md` §2. Kết quả kiểm tra: `10-day-4-verification.md`.

## 1. Quyết định chốt

| Thành phần | Quyết định |
|---|---|
| Access token | JWT RS256, hạn **15 phút** (BR-A03) |
| Refresh token | 32 byte ngẫu nhiên (`SecureRandom`), Base64 URL-safe; hạn **30 ngày** nhưng không vượt hạn phiên |
| Phiên (`auth_sessions`) | Một lần đăng nhập trên một thiết bị; hạn tuyệt đối **30 ngày**, refresh không kéo dài mốc này |
| Claim JWT | `sub` (UUID user), `sid` (UUID phiên), `iss=viegym-backend`, `aud=viegym-mobile`, `iat`, `exp`; header `typ=JWT` |
| Không nằm trong JWT | Email, role, trạng thái, dữ liệu sức khỏe. Role đọc từ DB ở mỗi request |
| Lưu refresh ở DB | Chỉ SHA-256 (hex). Token gốc chỉ trả cho client một lần |
| Mật khẩu | `DelegatingPasswordEncoder` → BCrypt, hash có tiền tố `{bcrypt}`. Tối đa 72 byte UTF-8 |
| Mobile | Access token chỉ trong bộ nhớ; refresh token trong `flutter_secure_storage` |
| Refresh | Xoay vòng mỗi lần; khóa hàng `SELECT ... FOR UPDATE` |
| Logout | Thu hồi **phiên hiện tại** và mọi refresh token của phiên đó; các thiết bị khác không ảnh hưởng |
| Tài khoản `LOCKED` | Chặn login (sau khi đúng mật khẩu), refresh và mọi API riêng tư: `403 ACCOUNT_LOCKED` |

Đây là JWT **có kiểm tra trạng thái phiên** ở database, không phải stateless hoàn toàn. Đổi lại, logout và khóa tài khoản có hiệu lực ngay ở request tiếp theo, không phải đợi access token hết hạn.

## 2. Mô hình dữ liệu (migration `V2__create_auth_tables.sql`)

```text
User 1 ── n AuthSession 1 ── n RefreshToken
```

| Bảng | Cột chính | Ghi chú |
|---|---|---|
| `users` | `email` UNIQUE, `password_hash`, `role`, `status`, `timezone` | Email lưu dạng trim + lowercase (BR-A01) |
| `auth_sessions` | `user_id`, `expires_at`, `revoked_at` | `revoked_at` khác NULL = đã logout/thu hồi |
| `refresh_tokens` | `session_id`, `token_hash` UNIQUE, `expires_at`, `consumed_at`, `revoked_at` | `consumed_at` = đã đổi lấy token mới; giữ lại để phát hiện dùng lại |

Khác thiết kế ngày 2: `refresh_tokens` gắn với `session_id` thay vì `user_id`, và dùng `consumed_at` thay cho `replaced_by_id`. Lý do: logout cần thu hồi đúng một thiết bị, và JWT cần `sid` để backend biết phiên còn sống không. `03-database-design.md` đã cập nhật theo.

## 3. Luồng

```text
Đăng ký   POST /auth/register → 201 user (không cấp token; app chuyển sang đăng nhập)

Đăng nhập POST /auth/login
          → tạo auth_session (expires_at = now + 30d)
          → cấp access JWT (sid = session.id) + refresh ngẫu nhiên (lưu hash)
          → app ghi refresh vào secure storage XONG rồi mới coi là đã đăng nhập

Gọi API   Authorization: Bearer <access>
          → Resource Server kiểm tra chữ ký RS256, exp, iss, aud, typ, sub, sid
          → SessionJwtConverter: phiên tồn tại, đúng user, chưa thu hồi, chưa hết hạn; user không LOCKED

Refresh   POST /auth/refresh { refreshToken }
          → khóa hàng token (FOR UPDATE)
          → token đã consumed  → BR-A04: thu hồi MỌI phiên của user, trả 401
          → token hết hạn/thu hồi, phiên không còn hiệu lực → 401 INVALID_REFRESH_TOKEN
          → user LOCKED → 403
          → đánh dấu consumed, cấp cặp token mới trong CÙNG phiên

Logout    POST /auth/logout { refreshToken } → 204 (idempotent)
          → thu hồi phiên chứa token đó (nhận cả token đã consumed)
          → app xóa refresh + access trong bộ nhớ, kể cả khi mất mạng
```

Endpoint `/auth/*` bỏ qua header `Authorization`: app còn giữ access token hết hạn vẫn login/refresh/logout được thay vì bị 401 ở filter.

## 4. Phía mobile

| Tình huống | Hành vi |
|---|---|
| Mở app | Có refresh đã lưu → refresh rồi gọi `/users/me`; không có → màn đăng nhập |
| Access hết hạn (401) | Refresh **một lần** rồi gửi lại request **tối đa một lần** |
| Nhiều request cùng gặp 401 | Single-flight: chờ chung một lần refresh, không gửi cùng một refresh token hai lần |
| Refresh trả 401/403 | Xóa phiên local, về màn đăng nhập kèm lý do |
| Mất mạng / 5xx khi refresh | **Giữ** refresh token, hiện màn lỗi có nút "Thử lại" |
| Không ghi được refresh mới | Buộc đăng nhập lại (token cũ đã bị tiêu thụ ở backend) |
| Logout khi mất mạng | Vẫn xóa phiên local, báo "chưa xác nhận được với máy chủ" |
| Đổi tài khoản | `meProvider` phụ thuộc trạng thái đăng nhập nên tính lại; không còn dữ liệu tài khoản trước |

## 5. Lưu ý thiết kế đã biết

- **Refresh đồng thời cùng một token (BR-A04).** Request thứ hai chờ khóa, sau đó thấy token đã consumed và coi là dùng lại. Kết quả là mọi phiên của user bị thu hồi, **kể cả phiên request đầu vừa nhận token mới**. Đây là hành vi chủ ý vì backend không phân biệt được "client bị lỗi" với "token bị lộ". App tránh được nhờ single-flight. Client khác (Postman, script) gửi song song sẽ bị đăng xuất. Integration test AUTH-13 kiểm tra đúng một request trả 200.
- **Mỗi request riêng tư tốn một truy vấn** `auth_sessions JOIN users`. Ở quy mô MVP thì chấp nhận được. Nếu cần tối ưu thì thêm cache ngắn hạn, nhưng logout sẽ trễ tương ứng.
- **Không có giới hạn tần suất đăng nhập** ở ngày 4. Rate limit hiện chỉ chốt cho `/auth/reset-password` (BR-A06); login sẽ làm cùng lúc.
- **Bảng phiên và token chỉ tăng.** Chưa có job dọn bản ghi hết hạn; thêm khi làm phần vận hành.
- Mã lỗi khi access token hết hạn là `401 UNAUTHORIZED` (không tách `TOKEN_EXPIRED`), vì app xử lý mọi 401 như nhau.

## 6. Khóa ký JWT

Khóa nằm ngoài Git: `infra/secrets/jwt-private.pem` (PKCS#8) và `infra/secrets/jwt-public.pem` (X.509). `.gitignore` chặn `secrets/` và `*.pem`. Đường dẫn mặc định trong `application.yaml` (chạy từ thư mục `backend/`); ghi đè bằng `JWT_PRIVATE_KEY_LOCATION`, `JWT_PUBLIC_KEY_LOCATION`.

Tạo khóa mới (RSA 2048):

```bash
mkdir -p infra/secrets
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out infra/secrets/jwt-private.pem
openssl pkey -in infra/secrets/jwt-private.pem -pubout -out infra/secrets/jwt-public.pem
```

- Khóa phải **ổn định giữa các lần khởi động**. Sinh khóa mới mỗi lần chạy sẽ làm mọi access token đang dùng mất hiệu lực (AUTH-16).
- Đổi khóa thì mọi access token cũ bị từ chối; app tự refresh được vì refresh token không phụ thuộc khóa.
- Test dùng khóa sinh lúc chạy (`TestcontainersConfiguration`), không đọc file trong `infra/secrets/`.

Chạy backend local:

```powershell
$env:DB_PASSWORD = "<POSTGRES_PASSWORD trong infra/.env>"
cd backend; .\mvnw.cmd spring-boot:run
```
