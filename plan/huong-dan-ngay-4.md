# VieGym — Ngày 4: Đăng ký, đăng nhập, JWT và quản lý phiên

**Mục tiêu:** Người dùng đăng ký, đăng nhập từ Android, gọi API riêng tư, gia hạn phiên và đăng xuất được. Dữ liệu tài khoản lưu PostgreSQL; mật khẩu được hash; refresh token có thể thu hồi.

**Thời lượng dự kiến:** 6–8 giờ nếu bộ khung ngày 3 đã chạy. Nếu chưa hoàn thành, tiếp tục ngày 4 sang buổi kế tiếp, không bỏ kiểm thử phiên để chạy theo lịch.

Tài liệu này là hướng dẫn triển khai và các đoạn minh họa, không phải toàn bộ mã nguồn có thể chạy ngay. Bạn cần tạo đủ class, cấu hình và kiểm tra với phiên bản Spring Boot/Flutter thực tế. Chỉ đánh dấu checklist sau khi chạy kiểm tra thành công.

## 0. Kiểm tra đầu vào — 15 phút

- [ ] Android gọi thành công endpoint kiểm tra ngày 3.
- [ ] Backend đọc được PostgreSQL.
- [ ] Flyway chạy được và đã biết số migration tiếp theo.
- [ ] Có use case và hợp đồng API ngày 2.
- [ ] Đã lưu thay đổi trước khi chỉnh cấu hình bảo mật.

Các đường dẫn dưới đây tính từ thư mục gốc VieGym. Giữ nguyên package và phiên bản framework của dự án hiện có. Không khởi tạo lại project.

## 1. Chốt cách quản lý phiên — 30 phút

Thiết kế đề xuất cho MVP:

| Thành phần | Quyết định |
|---|---|
| Access token | JWT ký bởi backend, thời hạn đề xuất 15 phút |
| Refresh token | Chuỗi ngẫu nhiên mật mã tối thiểu 32 byte, thời hạn phiên đề xuất 7 ngày |
| JWT subject | UUID tài khoản, không dùng email làm khóa định danh |
| JWT claims | `sub`, `iss`, `aud`, `iat`, `exp`, `sid`; quyền lấy từ dữ liệu server hiện tại |
| Database | Lưu hash SHA-256 của refresh token ngẫu nhiên; không lưu token thô |
| Mật khẩu | Dùng PasswordEncoder của Spring Security, không mã hóa có thể giải ngược |
| Mobile | Access token trong bộ nhớ; refresh token trong secure storage |
| Refresh | Xoay refresh token mỗi lần dùng thành công, giao dịch có khóa chống dùng đồng thời |
| Logout | Thu hồi phiên hiện tại và mọi refresh token trong phiên đó |
| Token đã cấp sau logout | Bị từ chối vì backend kiểm tra phiên `sid` đã thu hồi |
| Tài khoản khóa | Login, refresh và API riêng tư đều bị chặn |

Đây là JWT có kiểm tra trạng thái phiên ở database, không phải hệ thống hoàn toàn không lưu trạng thái. Đổi lại, logout và khóa tài khoản có hiệu lực ngay với request tiếp theo. Không tuyên bố JWT tự mất hiệu lực ngay chỉ vì xóa token ở điện thoại.

Luồng:

```text
Đăng nhập đúng
→ tạo auth session
→ cấp access JWT + refresh ngẫu nhiên
→ app lưu refresh an toàn
→ app gọi API bằng Authorization: Bearer <access>
→ backend xác minh JWT + user + session

Access hết hạn
→ app dùng refresh token một lần
→ backend thay token mới trong cùng session
→ app lưu refresh mới, nhận access mới

Logout
→ backend thu hồi session
→ app xóa refresh và dữ liệu phiên trong bộ nhớ
```

- [ ] Ghi quyết định vào `docs/09-auth-design.md`.
- [ ] Chốt thời hạn và hành vi logout.
- [ ] Không chứa thông tin sức khỏe, password hoặc secret trong JWT.

## 2. Tạo migration tài khoản và phiên — 45 phút

Nếu V1 là migration ngày 3, tạo `backend/src/main/resources/db/migration/V2__create_auth_tables.sql`. Nếu đã có bảng hoặc migration khác, viết migration tiếp theo dựa trên schema thực tế, không chạy CREATE trùng và không sửa migration đã áp dụng.

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(254) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'USER',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT users_role_check CHECK (role IN ('USER', 'ADMIN')),
    CONSTRAINT users_status_check CHECK (status IN ('ACTIVE', 'LOCKED'))
);

CREATE TABLE auth_sessions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ
);

CREATE INDEX idx_auth_sessions_user ON auth_sessions(user_id);

CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES auth_sessions(id),
    token_hash CHAR(64) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ
);

CREATE INDEX idx_refresh_tokens_session ON refresh_tokens(session_id);
```

Quy tắc:

- Backend sinh UUID trước khi lưu.
- Email được trim và lowercase theo chính sách ứng dụng trước khi ghi/tìm kiếm.
- Không trim hoặc lowercase mật khẩu.
- JPA dùng `Instant` cho thời điểm; enum lưu STRING, không ordinal.
- `updated_at` cần được cập nhật bởi ứng dụng hoặc cơ chế đã chọn; DEFAULT không tự cập nhật mỗi lần sửa.
- Unique email ở database xử lý cả hai đăng ký đồng thời; kiểm tra exists trước đó chỉ hỗ trợ thông báo sớm.

- [ ] Migration chạy thành công.
- [ ] Entity khớp kiểu cột và `ddl-auto: validate` không lỗi.
- [ ] Email trùng bị database từ chối.
- [ ] Đã cập nhật ERD: `User → AuthSession → RefreshToken`.

## 3. Tạo cấu trúc module Auth và DTO — 30 phút

```text
backend/src/main/java/com/viegym/backend/
├── auth/
│   ├── AuthController.java
│   ├── AuthService.java
│   ├── SessionService.java
│   ├── TokenService.java
│   ├── dto/
│   ├── entity/
│   └── repository/
├── user/
│   └── MeController.java
└── common/
    ├── security/
    └── exception/
```

DTO cần có: RegisterRequest, LoginRequest, RefreshRequest, LogoutRequest, TokenResponse và UserResponse.

Ví dụ đầu vào đăng ký:

```java
public record RegisterRequest(
    @NotBlank @Email @Size(max = 254) String email,
    @NotBlank @Size(min = 8, max = 64) String password,
    @NotBlank @Size(max = 100) String fullName
) {}
```

Thêm imports `jakarta.validation.constraints.*`, gọi `@Valid` ở controller. Nếu chọn BCrypt, kiểm tra thêm độ dài UTF-8 không vượt 72 byte trước encode để tránh giới hạn của thuật toán; số ký tự và số byte không giống nhau. Không log DTO có mật khẩu bằng toString.

Không nhận role/status từ request đăng ký. Server luôn đặt USER và ACTIVE. Không trả entity trực tiếp vì dễ lộ password_hash và quan hệ phiên.

## 4. Chốt API Auth — 30 phút

Tất cả đường dẫn dưới đây có tiền tố `/api/v1`.

| Method | Endpoint | Đầu vào | Thành công |
|---|---|---|---|
| POST | `/auth/register` | email, password, fullName | 201 + thông tin user an toàn |
| POST | `/auth/login` | email, password | 200 + TokenResponse |
| POST | `/auth/refresh` | refreshToken | 200 + TokenResponse mới |
| POST | `/auth/logout` | refreshToken | 204, thu hồi phiên |
| GET | `/users/me` | Authorization Bearer | 200 + user hiện tại |

Đăng ký xong chuyển sang đăng nhập để luồng rõ ràng. Không tự cấp token ở endpoint register trong thiết kế này.

Ví dụ register:

```json
{
  "email": "student@example.com",
  "password": "mat-khau-test-local",
  "fullName": "Sinh viên VieGym"
}
```

TokenResponse đề xuất:

```json
{
  "tokenType": "Bearer",
  "accessToken": "<access-jwt>",
  "expiresIn": 900,
  "refreshToken": "<opaque-refresh-token>",
  "user": {
    "id": "<uuid>",
    "email": "student@example.com",
    "fullName": "Sinh viên VieGym",
    "role": "USER"
  }
}
```

Mã lỗi: 400 validation, 409 email trùng, 401 thông tin đăng nhập/token không hợp lệ, 403 thiếu quyền. Với login sai/khóa tài khoản có thể dùng cùng phản hồi 401 chung để tránh lộ trạng thái tài khoản. Refresh hết hạn/đã dùng/thu hồi đều trả 401 rõ ràng cho app. Lỗi nội bộ trả thông báo chung, không trả stacktrace.

Auth responses chứa token nên đặt `Cache-Control: no-store`. Không log request/response body của các endpoint này.

## 5. Triển khai đăng ký và đăng nhập — 60 phút

### Đăng ký

1. Validate đầu vào và chuẩn hóa email.
2. Kiểm tra trùng email để trả lỗi dễ hiểu.
3. Hash mật khẩu bằng PasswordEncoder.
4. Sinh UUID, đặt role USER và status ACTIVE.
5. Lưu trong transaction.
6. Xử lý riêng vi phạm unique email khi có race, trả 409.
7. Trả UserResponse không có hash/token.

### Đăng nhập

1. Chuẩn hóa email và tìm tài khoản.
2. Kiểm tra mật khẩu bằng `matches`, không so sánh hai chuỗi hash.
3. Nếu không tồn tại/sai/khóa: trả lỗi chung; cân nhắc dummy hash check khi không tìm thấy tài khoản để giảm khác biệt thời gian.
4. Tạo AuthSession hạn 7 ngày.
5. Tạo refresh ngẫu nhiên bằng SecureRandom, encode URL-safe.
6. Lưu SHA-256 của refresh và hạn dùng, không lưu chuỗi thô.
7. Phát JWT chứa sid/sub và các claims xác thực.
8. Trả token chỉ qua response thành công.

Bean PasswordEncoder có thể dùng factory chính thức:

```java
@Bean
PasswordEncoder passwordEncoder() {
    return PasswordEncoderFactories.createDelegatingPasswordEncoder();
}
```

Hash có thể có tiền tố `{bcrypt}`; giữ nguyên tiền tố để matches nhận đúng encoder. SHA-256 ở phần refresh phù hợp vì token có entropy cao; không dùng cách hash nhanh này thay thế PasswordEncoder cho mật khẩu người dùng.

- [ ] Tài khoản lưu được trong PostgreSQL.
- [ ] Cột password_hash khác mật khẩu gốc.
- [ ] Login dùng matches thành công.
- [ ] Login sai không cấp token.
- [ ] Client không tự gán ADMIN.

## 6. Cấu hình JWT và bảo vệ API — 60 phút

Thêm Spring Security và OAuth2 Resource Server phù hợp phiên bản Boot hiện có. Dùng dependency management của Boot, không tự trộn phiên bản Security khác. Kiểm tra có hỗ trợ JOSE để encode/decode JWT.

Chọn một thuật toán ký, ví dụ RS256. Private key chỉ ở backend, public key dùng xác minh. Key phải được giữ ổn định qua restart và nằm ngoài Git; không sinh key tạm mỗi lần khởi động rồi vô tình vô hiệu hóa mọi JWT cũ.

Thực hiện:

1. Cấu hình JwtEncoder để ký, JwtDecoder để xác minh đúng thuật toán.
2. Bắt buộc kiểm tra chữ ký, hạn exp, issuer, audience và sub/sid hợp lệ.
3. Không chỉ decode Base64 payload rồi tin dữ liệu.
4. Sau xác minh JWT, tải user và session theo sub/sid.
5. Kiểm tra session thuộc user, chưa thu hồi, chưa hết hạn; user đang ACTIVE.
6. Ánh xạ quyền hiện tại từ database thành `ROLE_USER` hoặc `ROLE_ADMIN`.
7. Mọi API riêng tư đều phải đi qua bước kiểm tra phiên, không chỉ `/users/me`.

Resource Server hỗ trợ xác minh Bearer JWT, nhưng không tự viết endpoint login hay tự kiểm tra AuthSession cho bạn. Có thể bổ sung converter/provider phù hợp hoặc filter sau bước xác thực JWT; khi chặn phải dừng xử lý và trả JSON lỗi, không tiếp tục filter chain.

Quy tắc SecurityFilterChain:

```text
GET  /api/v1/system/health          public, chỉ thông tin kiểm tra cần thiết
POST /api/v1/auth/register          public
POST /api/v1/auth/login             public
POST /api/v1/auth/refresh           public theo Bearer, xác minh refresh riêng
POST /api/v1/auth/logout            public theo Bearer, xác minh refresh riêng
/api/v1/admin/**                    ADMIN
mọi endpoint còn lại               authenticated
```

Logout dùng refresh để vẫn hoạt động khi access token đã hết hạn. Token lạ/đã thu hồi có thể trả 204 theo chính sách idempotent; token nhận diện được thì thu hồi toàn bộ session tương ứng. Không nhận userId do client gửi để quyết định phiên bị logout.

Cấu hình session HTTP là STATELESS, không bật form login/basic auth cho mobile API. Có thể tắt CSRF cho API chỉ dùng Bearer và refresh trong JSON như thiết kế này; nếu đổi sang cookie thì phải đánh giá và cấu hình CSRF lại. CORS cấu hình riêng khi làm React admin; không mở wildcard để sửa lỗi mobile.

Khi `/users/me` trả lời, lấy ID từ Authentication đã xác minh. Không thêm query `userId` để đọc tài khoản người khác.

- [ ] Thiếu/sai/hết hạn JWT trả 401 JSON.
- [ ] Sai quyền trả 403 JSON.
- [ ] JWT có chữ ký khác bị từ chối.
- [ ] User đã khóa/session đã thu hồi bị chặn.
- [ ] API chưa khai báo vẫn được bảo vệ, không permitAll toàn bộ `/api/**`.

## 7. Refresh và logout — 45 phút

### Refresh rotation

Trong cùng transaction:

1. Hash refresh nhận được và tìm bản ghi bằng hash.
2. Khóa bản ghi/phiên cần thiết bằng cơ chế database phù hợp để hai request không cùng dùng token cũ.
3. Kiểm tra hạn token, consumed/revoked, hạn session và trạng thái user.
4. Đánh dấu token cũ đã dùng.
5. Sinh và lưu hash refresh mới trong cùng session.
6. Hạn refresh mới không vượt hạn tuyệt đối của session.
7. Trả access mới và refresh mới.

Chỉ một request đồng thời được thành công. Với token cũ dùng lại, chính sách MVP có thể từ chối 401 mà không tự thu hồi toàn bộ session; ghi rõ đây chưa phải cơ chế phát hiện và xử lý đánh cắp token hoàn chỉnh. Không xóa ngay lịch sử token đã dùng nếu logout cần nhận diện session từ token trước đó.

### Logout

1. Tìm phiên từ hash refresh, kể cả token cũ của phiên nếu còn lưu.
2. Đặt revoked_at cho session và các refresh token chưa thu hồi trong phiên.
3. Trả 204; app xóa refresh trong secure storage và access trong bộ nhớ.
4. Request tiếp theo bằng access cũ bị từ chối do kiểm tra sid.

Nếu logout mất mạng, app có thể xóa phiên local nhưng phải hiểu server chưa xác nhận thu hồi. Không hiển thị như đã thu hồi thành công trên server; cần chính sách thử lại hoặc thông báo phù hợp.

- [ ] Refresh thành công cấp cặp token mới.
- [ ] Refresh cũ không dùng lại được.
- [ ] Logout chặn cả refresh và access của phiên hiện tại.
- [ ] Phiên khác không bị thu hồi nếu thiết kế logout chỉ phiên hiện tại.

## 8. Flutter: đăng ký, đăng nhập và giữ phiên — 60–90 phút

Trong `mobile`:

```powershell
flutter pub add flutter_secure_storage
```

Kiểm tra yêu cầu Android SDK/build của phiên bản package được giải quyết và rebuild app sau khi thêm native plugin.

Cấu trúc gợi ý:

```text
lib/features/auth/
├── data/
│   ├── auth_api.dart
│   ├── auth_repository.dart
│   └── token_store.dart
├── application/
│   └── auth_controller.dart
└── presentation/
    ├── login_page.dart
    ├── register_page.dart
    └── session_page.dart
```

Minh họa secure storage:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  Future<void> saveRefresh(String token) =>
      storage.write(key: 'refresh_token', value: token);

  Future<String?> readRefresh() => storage.read(key: 'refresh_token');

  Future<void> clear() => storage.delete(key: 'refresh_token');
}
```

Không lưu mật khẩu. Access giữ trong AuthController/Repository; không ghi token vào SharedPreferences hoặc log.

Thứ tự triển khai:

1. Màn đăng ký: email, họ tên, mật khẩu và xác nhận mật khẩu; validation ở client hỗ trợ UX, backend vẫn kiểm tra đầy đủ.
2. Màn đăng nhập: loading, lỗi, disable nút trong lúc gửi.
3. Login thành công: ghi refresh bằng await; chỉ chuyển sang trạng thái authenticated sau khi ghi thành công.
4. Tạo màn phiên đăng nhập tạm hiển thị dữ liệu `/users/me`, không làm dashboard nghiệp vụ sớm.
5. Lớp API đính Bearer access token cho request riêng tư.
6. App mở lại: đọc refresh → refresh một lần → lưu token mới → gọi me → vào app.
7. 401 do access hết hạn: chỉ chạy một refresh chung cho các request đồng thời, cập nhật token, gửi lại request tối đa một lần.
8. Không tự retry login/refresh khi 401 để tránh vòng lặp. Request ghi dữ liệu không được tự retry vô điều kiện; giữ cơ chế chống trùng khi cần.
9. Refresh trả 401: xóa phiên và về login. Lỗi mạng/server 5xx: giữ refresh và cho thử lại, không tự coi là phiên không hợp lệ.
10. Logout: gửi refresh hiện có, xóa phiên local khi xử lý xong và invalidation toàn bộ provider dữ liệu cá nhân của user cũ.

Nếu ghi refresh mới vào secure storage thất bại sau rotation, không tiếp tục dùng refresh cũ đã tiêu thụ; chuyển sang yêu cầu đăng nhập lại có thông báo phù hợp.

Giữ URL và cách kết nối Android như ngày 3. HTTP local chỉ cho debug; bản triển khai dùng HTTPS.

- [ ] Đăng ký/đăng nhập được trên điện thoại.
- [ ] Không bấm gửi nhiều lần trong lúc loading.
- [ ] Đăng nhập lại sau khi đóng app hoạt động.
- [ ] Nhiều request hết hạn cùng lúc chỉ thực hiện một refresh.
- [ ] Logout không còn dữ liệu tài khoản trước trên UI.
- [ ] Có trạng thái mất mạng và thử lại.

## 9. Kiểm thử bắt buộc — 45–60 phút

Kiểm tra API bằng Postman hoặc công cụ tương đương trước, sau đó chạy toàn luồng Android. Tạo hai tài khoản test A và B. Không đưa token thật vào ảnh chụp hoặc file báo cáo.

| Mã | Tình huống | Kết quả mong đợi |
|---|---|---|
| AUTH-01 | Register hợp lệ | 201, tài khoản USER |
| AUTH-02 | Email trùng, kể cả khác hoa/thường theo quy tắc | 409 |
| AUTH-03 | Dữ liệu thiếu/sai | 400, lỗi trường rõ ràng |
| AUTH-04 | Client gửi role ADMIN | Không thể tự tạo Admin |
| AUTH-05 | Login đúng | 200, có cặp token |
| AUTH-06 | Sai mật khẩu/email không tồn tại | 401 chung, không có token |
| AUTH-07 | Gọi me không có token | 401 |
| AUTH-08 | JWT giả, hết hạn, sai issuer/audience | 401 |
| AUTH-09 | Token A gọi me | Chỉ trả A |
| AUTH-10 | User gọi API admin nếu đã có endpoint test được bảo vệ | 403 |
| AUTH-11 | Refresh hợp lệ | Token mới, token cũ bị tiêu thụ |
| AUTH-12 | Gửi refresh cũ lần nữa | 401 |
| AUTH-13 | Hai refresh đồng thời | Chỉ một thành công |
| AUTH-14 | Logout rồi dùng refresh/access cũ | Bị từ chối |
| AUTH-15 | Khóa tài khoản test ở DB local | Login/refresh/API riêng tư bị chặn |
| AUTH-16 | Restart backend với key ổn định | Phiên chưa hết hạn vẫn dùng được |
| AUTH-17 | Đóng/mở app | Refresh khôi phục phiên |
| AUTH-18 | Mất mạng khi khôi phục phiên | Không xóa refresh chỉ vì lỗi mạng |
| AUTH-19 | Đổi tài khoản A sang B | Không còn dữ liệu/cache của A |

Để kiểm tra access hết hạn, có thể dùng cấu hình TTL ngắn chỉ trong môi trường test; không sửa đồng hồ hệ thống. Sau thử nghiệm trả TTL về giá trị đã chốt.

Viết integration test có ý nghĩa cho đăng ký trùng, token không hợp lệ, rotation và logout. Dùng database test riêng; không chạy test xóa dữ liệu vào database demo. Nếu test chưa triển khai được trong ngày, ghi rõ kết quả kiểm tra API thủ công và phần tự động còn thiếu.

Chạy `flutter analyze` trong mobile và kiểm thử backend phù hợp cấu hình dự án. Đừng xem việc build thành công là bằng chứng refresh/logout đúng.

Lưu kết quả vào `docs/10-day-4-verification.md`: đầu vào, kết quả mong đợi, thực tế, đạt/không đạt, ảnh đã che token và lỗi còn lại.

## 10. Lỗi thường gặp

| Lỗi | Kiểm tra |
|---|---|
| Login luôn 401 | PasswordEncoder, tiền tố hash, chuẩn hóa email và trạng thái user |
| Public endpoint trả 401 | Matcher, thứ tự rule, method HTTP; client có gửi Bearer cũ sai vào auth endpoint không |
| JWT tự mất hiệu lực sau restart | Key ký có bị sinh mới mỗi lần chạy không |
| JWT hợp lệ nhưng 403 | Quyền hiện tại và tiền tố ROLE_ có khớp hasRole không |
| Logout mà access cũ vẫn dùng được | Chưa kiểm tra session sid ở toàn bộ request riêng tư |
| Refresh chạy vòng lặp | Đã loại auth endpoints và giới hạn retry tối đa một lần chưa |
| Refresh đôi khi 401 | Nhiều request đồng thời thiếu single-flight hoặc thiếu transaction/khóa |
| App mở lại luôn logout | Chưa await ghi secure storage, hoặc xóa token khi chỉ lỗi mạng |
| Validation lỗi 500 | Thiếu exception handler cho validation/unique email |
| Dữ liệu A còn sau login B | Chưa xóa cache/provider theo phiên |

## 11. Checklist đóng ngày 4

- [ ] Migration tài khoản và phiên chạy được.
- [ ] Đăng ký không cho tự gán ADMIN.
- [ ] Password hash an toàn; refresh chỉ lưu hash.
- [ ] JWT xác minh chữ ký, issuer, audience và expiry.
- [ ] API riêng tư kiểm tra user và session hiện tại.
- [ ] Refresh rotation và chống xử lý đồng thời hoạt động.
- [ ] Logout thu hồi đúng phiên, token cũ bị chặn.
- [ ] Android đăng ký, login, khôi phục phiên và logout thành công.
- [ ] Các kiểm tra quan trọng có kết quả thực tế.
- [ ] Secret/key/token không nằm trong Git hoặc báo cáo.
- [ ] Tài liệu ngày 2 được cập nhật theo thiết kế phiên thực tế.

Kiểm tra thay đổi rồi commit tại thư mục gốc:

```powershell
git status
git diff
git add .
git diff --cached --stat
git diff --cached
git commit -m "feat: implement authentication and session lifecycle"
```

Không commit nếu staged diff có secret. Đánh dấu những mục chưa hoàn thành thay vì khẳng định Auth xong khi mới login được.

### Nhật ký cuối ngày

```text
Đường dẫn dự án:
Phiên bản Spring Boot/Security và Flutter:
Đã hoàn thành:
Kết quả register/login/me:
Kết quả refresh rotation:
Kết quả logout và dùng lại token:
Kết quả đóng/mở app:
Lỗi còn lại:
Commit:
Việc đầu tiên ngày mai:
```

**Điều kiện sang ngày 5:** Tài khoản thật đăng nhập từ Android; endpoint riêng tư được bảo vệ; refresh và logout đã kiểm tra. Ngày 5 làm hồ sơ sức khỏe và các phép tính dựa trên tài khoản đã xác thực. Reset mật khẩu, Google Login và giao diện admin chưa thuộc ngày 4.

## Tài liệu chính thức tham khảo

- [Spring Security — JWT Resource Server](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html): xác minh Bearer JWT và cấu hình decoder; dùng nhánh tài liệu khớp dependency hiện có.
- [Spring Security — Password Storage](https://docs.spring.io/spring-security/reference/features/authentication/password-storage.html): PasswordEncoder và DelegatingPasswordEncoder.
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage): API đọc/ghi/xóa và yêu cầu nền tảng của phiên bản sử dụng.
