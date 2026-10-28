# Thư viện bài tập — thiết kế ngày 6

UC03. Bảng gốc: `03-database-design.md` §5, API: `05-api-contract.md` §5, quy tắc ẩn bài: BR-G07. Dữ liệu seed: `14-exercise-seed-catalog.md`. Kết quả kiểm tra: `15-day-6-verification.md`.

## 1. Khác với plan ngày 6

Plan ngày 6 có schema và API mẫu riêng. Ngày 2 đã chốt ERD và hợp đồng API, nên, giống ngày 5, dự án **giữ quyết định ngày 2** và chỉ thêm những gì ngày 2 còn thiếu:

| Điểm | Plan ngày 6 | Áp dụng |
|---|---|---|
| Nhóm cơ / thiết bị | Bảng `muscle_groups`, `equipment` + FK | Enum chuỗi trong `exercises` (docs/03), nhãn tiếng Việt khai báo trong enum Java |
| Danh mục nhóm cơ | BICEPS, TRICEPS tách riêng | `ARMS` gộp tay trước/sau; thêm `FULL_BODY`, `CARDIO` (docs/03) |
| Thiết bị | BODYWEIGHT, RESISTANCE_BAND, PULLUP_BAR | `NONE`, `BAND`, `OTHER` (xà đơn → `OTHER`) |
| Tên cột tìm kiếm | `search_name` | `name_search` (docs/03) |
| Phần tử danh sách | `muscleGroup: {code, name}` | Mã chuỗi (docs/05); nhãn lấy từ `GET /exercise-filters` |
| Phân trang | `totalElements`, size 1–50 | `totalItems`, size 1–100 (docs/05 §1.2); **thêm** `hasNext` |
| Mã 404 | `EXERCISE_NOT_FOUND` | `NOT_FOUND` (docs/05 §5) |
| Số bài | 20–30 | 32 (ứng viên của plan có trong dataset + 3 bài tự soạn) |

Thêm so với ngày 2 (cập nhật vào docs/03, docs/05): cột `code`, `common_mistakes`, `thumbnail_url`, `media_type`, `content_source`, `media_license`; endpoint `GET /exercise-filters`; media tĩnh `/media/**`.

## 2. Dữ liệu

- Mỗi bài **một nhóm cơ chính và một thiết bị chính**. Lọc "Tay" ra cả bài tay trước lẫn tay sau; bài dùng nhiều nhóm cơ chỉ xuất hiện ở nhóm chính. Muốn lọc theo nhóm phụ phải thêm bảng nối (chưa làm).
- `code` ổn định, không đổi khi sửa tên. ID seed = `uuid5(namespace cố định, code)`, ghi cứng trong V5, nên giáo án ngày 7 tham chiếu được.
- Seed là Flyway migration (`V5__seed_exercises.sql`), chạy đúng một lần. Sửa nội dung về sau: migration mới `UPDATE … WHERE code = …`; không xóa rồi tạo lại (mất liên kết giáo án/lịch sử).
- Ẩn bài = `is_active = false`, không xóa. Bài ẩn không hiện ở danh sách và chi tiết user (404), nhưng ID vẫn còn cho lịch sử sau này.

## 3. Tìm kiếm

`SearchText.normalize`: NFD → bỏ dấu tổ hợp → `đ`→`d` → chữ thường → gộp khoảng trắng (cả NBSP) → trim. Dùng cho `name_search` lúc seed (script sinh SQL dùng cùng quy tắc; test `seedIsConsistent` so lại từng dòng) và cho keyword.

- Keyword rỗng sau chuẩn hóa = không lọc theo tên.
- `LIKE '%' || keyword || '%' ESCAPE '\'`, tham số hóa qua Criteria API. `%`, `_`, `\` trong keyword được escape nên khớp như ký tự thường.
- Không tìm gần đúng (gõ sai chính tả không ra). Thứ tự: `name_search` rồi `id`, ổn định giữa các trang; chưa theo thứ tự từ điển tiếng Việt.

## 4. API

- `ExerciseSpecifications.activeMatching` luôn thêm `is_active = true` trước các điều kiện khác; client không có tham số nào bỏ được điều kiện này. Chi tiết dùng `findByIdAndActiveTrue`.
- Phân trang tại database (`findAll(spec, pageable)`). Không có quan hệ nên không có N+1.
- Enum/UUID/số sai kiểu → `MethodArgumentTypeMismatchException` → `400 VALIDATION_ERROR` theo tên tham số (handler mới trong `GlobalExceptionHandler`, áp dụng cho mọi controller).
- Không có endpoint ghi ở phía user. Admin CRUD để ngày 14 (khi đó nhớ tính lại `name_search` mỗi lần đổi tên).

## 5. Media

- Nguồn: ảnh nhỏ JPG + GIF 180×180 từ exercises-dataset, **bản quyền Gym visual**, không thuộc MIT. Mỗi bài có media mang `media_license` với dòng `© Gym visual — https://gymvisual.com/`; app hiện dòng này ngay dưới GIF và hiển thị ở 180×180 logic.
- File nằm trong `backend/src/main/resources/static/media/exercises/` (29 bài, ~2,9 MB), Spring Boot phục vụ tĩnh tại `/media/exercises/…`, `permitAll` vì `Image.network` không gửi Bearer. Không lưu file trong database.
- DB lưu **key tương đối** (`exercises/0662-I4hDWkc.gif`). `MediaUrlResolver` ghép thành URL khi trả API: dùng `viegym.media.base-url` nếu cấu hình, không thì lấy host của chính request. Điện thoại gọi `http://127.0.0.1:8080` qua `adb reverse` sẽ nhận URL cùng host đó, không cần reverse cổng khác. Triển khai thật (object storage/CDN): đặt `base-url` hoặc lưu URL tuyệt đối.
- 3 bài không có media (Bodyweight Squat, Plank, Bird Dog) → `null`, app hiện "Bài này chưa có hình minh họa". `VIDEO` chưa hỗ trợ ở app (chưa có dữ liệu video được phép dùng); chưa cài `video_player`.

## 6. App

- Tab "Bài tập" trong `HomeShell` (IndexedStack, chỉ dựng ở lần mở đầu): chuyển tab hay mở chi tiết rồi quay lại vẫn giữ keyword, bộ lọc, vị trí cuộn. Không bắt buộc có hồ sơ sức khỏe.
- Tìm kiếm debounce 400 ms (Enter thì tìm ngay). Đổi keyword/bộ lọc → bỏ danh sách cũ, tải lại từ trang 0.
- `ExerciseListController` tăng `generation` mỗi lần đổi truy vấn; response cũ về muộn bị bỏ. Tải thêm khi cuộn gần cuối, chặn request trùng; lỗi trang sau giữ bài đã có, nút "Tải lại trang sau" không nhân đôi (lọc theo id).
- Provider phụ thuộc trạng thái đăng nhập, `autoDispose`: logout/đổi tài khoản không còn dữ liệu hay request của phiên cũ.
- Chi tiết tải lại theo ID mỗi lần mở: bài bị ẩn sau khi danh sách đã tải → hiện thông báo 404 của backend.

## 7. Giới hạn còn lại

- Nội dung hướng dẫn và lỗi thường gặp chưa được người có chuyên môn rà (xem `14-exercise-seed-catalog.md`).
- Không lọc nhiều giá trị cùng nhóm (ví dụ Ngực **hoặc** Lưng), không lọc theo nhóm cơ phụ.
- `Image.network` không có timeout riêng; mạng treo thì vòng tải hiển thị tới khi hệ điều hành báo lỗi kết nối.
- Media phục vụ từ chính backend; đổi file phải build lại.
