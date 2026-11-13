# Kiểm tra ngày 14 — Trang quản trị tối thiểu

Thiết kế: `31-admin-design.md`. Ngày kiểm tra: 2026-11-13.

## 1. Môi trường

Như ngày 4–13. Migration **V14** đã chạy trên DB local. Backend chạy thêm biến môi trường để tạo admin: `ADMIN_EMAIL=admin@viegym.vn`, `ADMIN_PASSWORD` (mật khẩu local dev, không ghi vào Git). Trang admin: `cd admin && npm install && npm run dev` → `http://127.0.0.1:5173` (proxy `/api`, `/media` sang backend `127.0.0.1:8080`).

## 2. Kiểm thử tự động

| Phần | Lệnh | Kết quả |
|---|---|---|
| Backend | `.\mvnw.cmd test` (PostgreSQL thật qua Testcontainers) | **167/167** đạt (13 mới trong `AdminIntegrationTests`) |
| Admin | `npm run typecheck` | Không lỗi |
| Admin | `npm test` (Vitest + jsdom) | **7/7** đạt (`client.test.ts` 6, `render.test.tsx` 1) |
| Admin | `npm run build` | Build thành công (JS 197 kB, gzip 62 kB) |

Lỗi tìm được khi chạy test: lần đầu chạy cả bộ, 7 test danh mục cũ (`ExerciseLibraryIntegrationTests`, `FoodLibraryIntegrationTests`) hỏng vì đếm **chính xác** số món/bài seed, còn test admin để lại món/bài mới trong DB test dùng chung. Sửa: `AdminIntegrationTests` xóa bản ghi mã `ADM-`/`admin-` (và thực đơn/lịch tham chiếu) sau mỗi test, giống `MealPlanIntegrationTests`.

## 3. Bộ nghiệm thu plan ngày 14

| Mã | Tình huống | Bằng chứng | Kết quả |
|---|---|---|---|
| AD01 | USER gọi thẳng API admin | `onlyAdminsReachAdminApi`: GET/POST/PUT `/admin/**` của USER → 403 `FORBIDDEN`, không token → 401; `role` trong body đăng ký bị bỏ qua; không có `DELETE` (405). Trên backend local: `phonea` gọi `/admin/users` qua proxy → 403 | Đạt |
| AD02 | Admin tạo món đủ nguồn | `createdFoodIsVisibleToUsers`: 201, mã `ADM-…`, revision 1; USER tìm thấy qua `/foods` và xem chi tiết; audit `CREATE` | Đạt |
| AD03 | Hai cửa sổ sửa cùng revision | `staleRevisionConflicts`: bản sau → 409 `VERSION_CONFLICT`, `currentRevision = 2`, dữ liệu giữ bản trước; lưu không đổi gì không tăng revision. `concurrentEditsWithSameRevisionSucceedOnce`: hai PUT đồng thời → đúng một 200, một 409 | Đạt |
| AD04 | Ẩn món đã có trong thực đơn | `deactivatedFoodKeepsMealSnapshots`: sửa số liệu + ẩn → biến mất khỏi tìm kiếm, `/foods/{id}` 404, thêm mới 422 `FOOD_INACTIVE`; thực đơn cũ vẫn tên + kcal cũ (600 = 1,5 × 400); admin vẫn thấy món ẩn; audit `UPDATE` rồi `ACTIVATE` | Đạt |
| AD05 | Ẩn bài đã có lịch | `deactivatedExerciseKeepsSchedules`: lịch cũ vẫn trả bài với `exerciseActive = false`, xếp lịch mới 422 `EXERCISE_INACTIVE`; audit `DEACTIVATE:active` | Đạt |
| AD06 | Khóa A đang đăng nhập | `lockRevokesSessionsAndUnlockNeedsNewLogin`: khóa thiếu lý do → 400; sau khóa: `/users/me` 401, refresh 401, đăng nhập 403 `ACCOUNT_LOCKED`, không còn phiên hoạt động | Đạt |
| AD07 | Mở khóa A | Cùng test: access token và refresh token cũ vẫn 401; đăng nhập mới được; audit `LOCK:Spam`, `UNLOCK` đúng admin | Đạt |
| AD08 | Tên món chứa ký tự HTML | Backend `htmlInNamesIsStoredAsText` lưu và trả nguyên văn; admin `render.test.tsx`: `<img onerror>` hiển thị dạng chữ, không tạo phần tử `img`/`b`, script không chạy | Đạt |
| AD09 | Admin tự khóa / đọc health B | `adminCannotLockSelfOrOtherAdmins`: tự khóa → 422 `CANNOT_CHANGE_OWN_STATUS`, khóa admin khác → 422 `ADMIN_ACCOUNT_PROTECTED`; không có endpoint đọc user/hồ sơ người khác (404) | Đạt |

Thêm: `invalidFoodIsRejected` (thiếu nguồn, khối lượng không đơn vị, kcal lệch > 15% khi hiển thị nhưng lưu được khi ẩn, nước 0 kcal hợp lệ, URL `javascript:`, `revision` khi tạo, danh mục lạ, số âm), `invalidExerciseIsRejected` (tên trùng không phân biệt hoa thường → 409, media `../`, tệp không có, `javascript:`, loại media thiếu URL, URL ngoài hợp lệ, không ảnh → không preview, hướng dẫn trống, enum lạ), `userListIsPagedSearchableAndHidesSecrets` (phân trang không trùng, không có `passwordHash`/chuỗi `bcrypt`, `%` không là wildcard, `size` > 100 → 400), `bootstrapCreatesAdminOnlyForNewEmail` (tạo admin từ cấu hình, chạy lại không đổi mật khẩu, không nâng quyền USER, mật khẩu yếu bị bỏ qua).

Frontend (`client.test.ts`): USER đăng nhập bị từ chối và refresh token bị thu hồi ngay; hai request cùng 401 chỉ refresh một lần; refresh thất bại → kết thúc phiên; 403 không refresh, không đăng xuất; giữ `fieldErrors` và `currentRevision`; lỗi mạng → `NETWORK_ERROR`.

## 4. Kiểm tra trên backend local

Backend khởi động với `ADMIN_EMAIL`/`ADMIN_PASSWORD` → Flyway chạy V14, tạo `admin@viegym.vn` (role ADMIN). Qua Vite proxy (`127.0.0.1:5173`): admin đăng nhập, `GET /admin/foods`, `/admin/exercises` (ảnh preview `http://127.0.0.1:8080/media/…`), `/admin/users` (3 tài khoản) trả 200; `phonea` gọi `/admin/users` → 403.

## 5. Test tay (trình duyệt + Android)

**Chưa thực hiện.** Đã commit theo yêu cầu của user (2026-11-13) với kiểm thử tự động ở §2–§4. Đối chiếu DB lúc commit: `admin_audit_logs` rỗng, chưa có món `ADM-`/bài `admin-` nào — bảng 18 bước (đăng nhập USER bị chặn, tạo/sửa/ẩn món, snapshot thực đơn trên điện thoại, xung đột 2 tab, ẩn bài có lịch, HTML trong tên, khóa/mở phoneb, không tự khóa) **cần chạy trước demo**.
