# Trang quản trị tối thiểu — thiết kế ngày 14

UC12 (Admin quản trị dữ liệu). Quy tắc: `04-business-rules.md` §1 (BR-G07, BR-G08), §9 (BR-AD01..07). API: `05-api-contract.md` §13. Bảng: `03-database-design.md` §5, §6, §10, migration `V14__admin_revision_and_audit.sql`. Kết quả kiểm tra: `32-day-14-verification.md`.

## 0. Khác với plan ngày 14

Như các ngày 5–13, dự án **giữ quyết định ngày 2** (docs/03–05) và chỉ bổ sung phần còn thiếu.

| Điểm | Plan ngày 14 | Áp dụng |
|---|---|---|
| Số docs | `30-admin-design.md`, `31-day-14-verification.md` | docs/30 đã dùng cho ngày 13 → **docs/31** (thiết kế), **docs/32** (kiểm tra) |
| Prefix | `/api/admin/...` | `/api/v1/admin/...` (docs/05 §1) |
| Ẩn/hiện | `PATCH /admin/foods/{id}/status` riêng | Trường `active` trong `PUT /admin/foods/{id}` (docs/05 §13: "Có `isActive`"); không có `DELETE` |
| Khóa tài khoản | `PATCH /admin/users/{id}/status` nhận `locked` | `PUT /admin/users/{id}/status` nhận `status: ACTIVE \| LOCKED` + `reason` (docs/05 §13) |
| Revision bài tập | Có sẵn | `exercises` chưa có cột → V14 thêm `revision` |
| Thêm so với docs ngày 2 | — | Bảng `admin_audit_logs`; tạo admin từ biến môi trường; `GET /admin/{foods,exercises}/{id}`, `GET /admin/food-options` cho form |

## 1. Ma trận quyền

| Tài nguyên | USER | ADMIN |
|---|---|---|
| Danh mục món/bài **active** (`/foods`, `/exercises`) | Đọc | Đọc |
| Danh mục cả món/bài ẩn, tạo, sửa, ẩn/hiện (`/admin/foods`, `/admin/exercises`) | Không (403) | Có |
| Danh sách tài khoản, khóa/mở (`/admin/users`) | Không (403) | Có — chỉ tài khoản USER, không tự khóa |
| Hồ sơ sức khỏe, thực đơn, nhật ký tập, cân nặng, chat của người khác | Không | **Không** trong MVP (không có API) |
| Nâng/hạ vai trò | Không | Không có API; admin tạo bằng cấu hình máy chủ (§2) |

Kiểm tra ở backend: `SecurityConfig` yêu cầu `ROLE_ADMIN` cho `/api/v1/admin/**`; role lấy từ DB ở **mỗi** request (`SessionService.authenticate`), không lấy từ claim JWT, nên hạ quyền/khóa có hiệu lực ngay. Chưa đăng nhập → `401`, USER → `403 FORBIDDEN`. Menu frontend chỉ để điều hướng.

## 2. Tài khoản admin

Không có đăng ký ADMIN công khai (`/auth/register` bỏ qua field `role`). `AdminBootstrap` chạy khi backend khởi động:

- Đọc `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `ADMIN_FULL_NAME` (tùy chọn) từ biến môi trường; để trống → không làm gì.
- Chuẩn hóa email và kiểm tra mật khẩu bằng **cùng** quy tắc đăng ký (BR-A01, BR-A02, ≤ 72 byte UTF-8); sai → log cảnh báo (không in mật khẩu), bỏ qua.
- Email chưa tồn tại → tạo `role = ADMIN`. Đã là ADMIN → không làm gì (không đổi mật khẩu). Đã là USER → **không** tự nâng quyền, chỉ log cảnh báo.
- Mật khẩu không nằm trong Git. Local dev: `admin@viegym.vn` (đặt khi chạy backend, xem docs/32 §1).

## 3. Danh mục món ăn và bài tập

| | Món ăn | Bài tập |
|---|---|---|
| Danh sách | `GET /admin/foods?keyword&category&active&page&size` | `GET /admin/exercises?keyword&muscleGroup&active&page&size` |
| Chi tiết (form sửa) | `GET /admin/foods/{id}` | `GET /admin/exercises/{id}` |
| Tạo | `POST /admin/foods` → 201 | `POST /admin/exercises` → 201 |
| Sửa / ẩn / hiện | `PUT /admin/foods/{id}` + `revision` | `PUT /admin/exercises/{id}` + `revision` |
| Tùy chọn form | `GET /admin/food-options` (mọi danh mục, vùng, mức tin cậy, đơn vị) | `GET /exercise-filters` (có sẵn) |

- **Tìm kiếm:** tên bỏ dấu (`SearchText`, escape `%`/`_`) hoặc mã; trả cả bản ghi ẩn; `size` 1–100; sắp `name_search, id`.
- **Mã:** server sinh khi tạo (`ADM-` + 10 hex cho món, `admin-` + 10 hex cho bài), không đổi khi sửa tên.
- **Revision (khóa lạc quan):** `PUT` khóa dòng (`FOR UPDATE`), so `revision` gửi lên với hiện tại: khác → `409 VERSION_CONFLICT` + `currentRevision`; frontend báo "đã sửa ở nơi khác, tải lại". POST gửi `revision` hoặc PUT thiếu `revision` → 400. Lưu mà không trường nào đổi → 200, **không** tăng revision, không audit. `foods.revision` vốn là số phiên bản số liệu (docs/03), nay tăng ở mọi lần sửa của admin; `meal_entries.food_revision` vẫn cho biết món đã đổi kể từ lúc thêm.
- **PUT ghi đè toàn bộ trường sửa được** (giống `PUT` giáo án): trường không gửi → null.
- **Món ăn:** nhãn khẩu phần, kcal/đạm/bột đường/béo (≥ 0, 2 chữ số lẻ, cùng **một** khẩu phần), nguồn, mức tin cậy bắt buộc. Khối lượng và đơn vị (`g`/`ml`) cùng có hoặc cùng trống. URL nguồn/ảnh chỉ `http(s)://`. **Hiển thị (`active = true`) đòi kcal lệch ≤ 15% so với 4P + 4C + 9F** — cùng công thức seed (docs/20 §4); thêm ngoại lệ kcal = 0 và P = C = F = 0 (nước). Lệch hơn → chỉ lưu được ở trạng thái ẩn, kèm `reviewNote`.
- **Bài tập:** tên duy nhất không phân biệt hoa thường (`409 EXERCISE_NAME_TAKEN`, kể cả khi hai admin cùng tạo — UNIQUE `lower(name)` chặn bản sau). Hướng dẫn, lỗi thường gặp bắt buộc. Ảnh/media là URL `http(s)://` **hoặc** key tệp tĩnh có thật dạng `exercises/<tệp>` (không `..`, không thư mục lồng); bỏ trống → app dùng ảnh mặc định. `mediaType` và `mediaUrl` cùng có hoặc cùng trống. **Chưa có upload** (không có storage và kiểm soát tệp trong roadmap).
- **Ẩn thay vì xóa** (BR-G07): món/bài ẩn biến mất khỏi `/foods`, `/exercises`, không thêm mới vào thực đơn (`422 FOOD_INACTIVE`) hay giáo án/lịch (`422 EXERCISE_INACTIVE`). Thực đơn đã ghi giữ snapshot (NUT-BR05); giáo án/lịch đã có vẫn đọc được bài ẩn (`exerciseActive = false`); nhật ký tập giữ tên đã ghi. Không cập nhật hàng loạt snapshot khi sửa catalog.

## 4. Khóa tài khoản và audit

`PUT /admin/users/{id}/status` `{ "status": "LOCKED" | "ACTIVE", "reason": "..." }`:

1. Đích là chính admin đang thao tác → `422 CANNOT_CHANGE_OWN_STATUS`. Đích là ADMIN → `422 ADMIN_ACCOUNT_PROTECTED` (MVP chỉ quản lý USER).
2. Khóa dòng `users` (`FOR UPDATE`). Khóa phải có `reason` (≤ 300).
3. Đã đúng trạng thái → 200, no-op.
4. Một giao dịch: đổi `status`; nếu khóa thì thu hồi **mọi** phiên + refresh token; ghi audit. Request kế tiếp của user bị khóa: access token cũ → `401` (phiên đã thu hồi), refresh → `401`, đăng nhập → `403 ACCOUNT_LOCKED` (BR-G08).
5. Mở khóa không phục hồi phiên cũ; user đăng nhập lại.

`GET /admin/users?keyword&status&page&size`: tìm theo email/họ tên (chuỗi con, không phân biệt hoa thường), sắp `created_at DESC, id`. Trả `id, email, fullName, role, status, createdAt` — không `password_hash`, không token.

**Audit** (`admin_audit_logs`): `actor_id, action (CREATE | UPDATE | ACTIVATE | DEACTIVATE | LOCK | UNLOCK), entity_type (FOOD | EXERCISE | USER), entity_id, reason, changed_fields, created_at`. `changed_fields` chỉ là **tên** trường (vd. `kcalPerServing,active`), không có giá trị → không chứa mật khẩu, token hay dữ liệu cá nhân. Chỉ đổi `active` → ACTIVATE/DEACTIVATE; có trường khác đổi → UPDATE. Ghi bằng `Propagation.MANDATORY` trong giao dịch của thao tác: thay đổi thành công thì chắc chắn có dấu vết, lỗi thì cả hai rollback. Chưa có màn xem audit (đọc bằng SQL khi cần).

Lỗi không lộ SQL/stack trace: `GlobalExceptionHandler` trả `{code, message}`; lỗi không lường trước → `500 INTERNAL_ERROR`.

## 5. Frontend `admin/`

React 18 + TypeScript + Vite 5 + React Router 6 (phiên bản ghim cố định trong `package.json`, không dùng thư viện UI). Thư mục `admin/` trước ngày 14 rỗng.

```text
admin/src/
  api/client.ts      ApiClient: fetch + Bearer, refresh 1 lần khi 401, ApiError {status, code, fieldErrors}
  api/types.ts       Kiểu theo docs/05 §13
  auth/AuthContext   Phiên trong bộ nhớ, RequireAdmin (chỉ điều hướng)
  components/        Layout (menu Món ăn / Bài tập / Tài khoản), bảng phân trang, Field, Modal
  pages/             Login, Foods + FoodForm, Exercises + ExerciseForm, Users (+ hộp thoại khóa có lý do)
```

- **Token:** access + refresh chỉ giữ trong bộ nhớ JS — **không** localStorage/cookie. Tải lại trang → đăng nhập lại (plan chấp nhận). Không cookie nên không cần CSRF.
- **Đăng nhập:** gọi `/auth/login`; tài khoản không phải ADMIN → logout ngay (thu hồi refresh token) và báo "không có quyền quản trị".
- **401:** refresh một lần (nhiều request cùng lúc dùng chung một lần refresh, vì refresh token xoay vòng — BR-A04), gửi lại; refresh thất bại hoặc `ACCOUNT_LOCKED` → kết thúc phiên, về màn đăng nhập. `403 FORBIDDEN` chỉ báo lỗi.
- **Dev:** Vite (`127.0.0.1:5173`) proxy `/api`, `/media` sang backend (`VIEGYM_BACKEND_URL`, mặc định `http://127.0.0.1:8080`) → một origin, backend **không** mở CORS. Không có khóa provider AI hay bí mật nào trong biến build frontend.
- **XSS:** mọi dữ liệu render qua JSX (tự escape); không dùng `dangerouslySetInnerHTML`. Ảnh chỉ nhận URL `http(s)` hoặc key tĩnh (backend kiểm tra).
- **Form:** lỗi theo trường từ `fieldErrors`; xung đột revision hiện nút "Tải lại"; đối chiếu 4P+4C+9F ngay trên form món (chỉ để admin tự kiểm, backend mới chặn).

Chạy: `cd admin && npm install && npm run dev` (backend chạy trước). Kiểm tra: `npm run typecheck`, `npm test`, `npm run build`.
