# Kiểm tra ngày 6 — Thư viện bài tập

Thiết kế: `13-exercise-library-design.md`. Dữ liệu: `14-exercise-seed-catalog.md`.

## 1. Môi trường

Như ngày 4–5 (`10-day-4-verification.md` §1). Flyway local: **V4 `create exercise library`**, **V5 `seed exercises`** áp dụng thành công (DB lên v5). App cài bản debug qua `adb install`, gọi backend qua `adb reverse tcp:8080 tcp:8080`.

## 2. Dữ liệu

| Mục | Kết quả |
|---|---|
| Bài active | 32 |
| Có GIF + ảnh nhỏ | 29 (tải được qua `/media/exercises/…`, 200 `image/gif`) |
| Không có media | 3: Bodyweight Squat, Plank, Bird Dog |
| Nguồn/quyền media | © Gym visual, 180×180, phân phối lại theo NOTICE của exercises-dataset; không thuộc MIT |
| Bài inactive | Chỉ trong integration test (`test-inactive`), không có trong seed |

## 3. Test tự động

`backend> .\mvnw.cmd test`: **56/56 đạt** (ngày 6 thêm 14: `SearchTextTest` 4, `ExerciseLibraryIntegrationTests` 10, PostgreSQL 17 qua Testcontainers).

| Mã | Test | Kết quả |
|---|---|---|
| EX01, EX06 | `pagesCoverAllActiveExercisesWithoutDuplicates`: 4 trang × 10 = 32 id không trùng, không lẫn bài ẩn; trang 4 rỗng; `hasNext` đúng | Đạt |
| EX02 | `keywordIgnoresMarksCaseAndSpaces`: `Đẩy ngực`, `day nguc`, `  DAY   NGUC  `, `ĐẨY NGỰC` → cùng 3 bài | Đạt |
| EX03–EX05 | `filtersCombineWithAnd`: lọc đơn, kết hợp AND, kết hợp không có bài → 200 rỗng, tham số rỗng = bỏ lọc | Đạt |
| EX07 | `invalidQueryIsRejected`: page −1/"abc", size 0/101, enum lạ/sai hoa thường, keyword 101 ký tự → 400 theo trường | Đạt |
| EX08 | `detailHasInstructionsAndReachableMedia`: đủ bước/lỗi, URL media ghép theo host, file tải được không cần token; bài không media trả null | Đạt |
| EX09 | `inactiveUnknownAndMalformedIds`: bài ẩn và id lạ → 404, id sai định dạng → 400 | Đạt |
| EX10 | `requiresActiveSession`: không token 401, tài khoản khóa 403 `ACCOUNT_LOCKED`, sau logout 401 | Đạt |
| EX11 | `specialCharactersAreLiteral`: `%`, `_`, `\`, `'`, `' or '1'='1` → 0 bài, không lỗi | Đạt |
| EX16 | `seedIsConsistent`: 32 code duy nhất, `name_search` = `SearchText.normalize(name)` từng dòng, ID cố định | Đạt |

`mobile> flutter analyze`: không có lỗi. `flutter test`: **27/27 đạt** (ngày 6 thêm 8 trong `exercise_test.dart`):

| Mã | Test | Kết quả |
|---|---|---|
| — | Tách bước/lỗi theo dòng; query encode keyword có dấu, `&`, `%` qua `Uri` | Đạt |
| EX12 | Response truy vấn cũ về sau truy vấn mới bị bỏ qua | Đạt |
| EX14 | Lỗi tải trang sau giữ bài cũ; hai lần tải thêm liền chỉ gửi một request; không nhân đôi | Đạt |
| — | Đổi bộ lọc bỏ danh sách cũ, tải lại từ trang 0 | Đạt |
| — | Widget: debounce chỉ gửi keyword cuối; rỗng có nút xóa lọc; mở chi tiết và quay lại giữ danh sách; bài ẩn hiện thông báo 404 | Đạt |

Gọi thử backend local bằng tài khoản `phonea@viegym.vn`: `ĐẨY NGỰC` → 3 bài, tổng 32, media 200 `image/gif`, không token 401, `muscleGroup=FOO` → 400.

## 4. Android

Kiểm tra tay ngày 2026-10-28 trên OPPO CPH2565 (Android 15), bản debug, backend local qua `adb reverse`. Tài khoản `phonea@viegym.vn`, `phoneb@viegym.vn`.

| # | Thao tác | Kết quả |
|---|---|---|
| 1 | Đăng nhập tài khoản A | Đạt: vào tab Sức khỏe, thanh dưới có tab Bài tập |
| 2 | Mở tab Bài tập | Đạt: danh sách có ảnh nhỏ và nhãn nhóm cơ · thiết bị · độ khó |
| 3 | Cuộn tới cuối (EX06) | Đạt: tự tải trang 2, "Đã hiển thị hết 32 bài", không trùng |
| 4 | `day nguc` và `Đẩy ngực` (EX02) | Đạt: cùng 3 bài |
| 5 | Lọc Ngực + Tạ đơn + Cơ bản (EX04) | Đạt: 1 bài, icon lọc hiện 3, có chip lọc |
| 6 | Lọc Ngực + Máy (EX05) | Đạt: thông báo rỗng, nút xóa lọc đưa về danh sách đầy đủ |
| 7 | Chi tiết Push-up (EX08) | Đạt: GIF chạy, dòng © Gym visual, 4 bước, 3 lỗi |
| 8 | Quay lại danh sách | Đạt: giữ keyword, bộ lọc, vị trí cuộn |
| 9 | Chi tiết Plank (EX13) | Đạt: thông báo chưa có hình, hướng dẫn đầy đủ |
| 10 | Chuyển tab qua lại | Đạt: giữ trạng thái danh sách |
| 11 | Ẩn Push-up trong DB (EX09) | Đạt: mở từ danh sách cũ báo không còn khả dụng; làm mới còn 31 bài; `hit dat` chỉ còn Close-grip. Đã bật lại (32 active) |
| 12 | Đăng xuất, đăng nhập tài khoản B | Đạt: danh sách tải mới, không còn keyword/bộ lọc của A |

Số bài có media đã kiểm tra trên Android: GIF của Push-up mở được; ảnh nhỏ hiển thị trên danh sách. 29 file media đều được integration test và `curl` xác nhận phục vụ được, chưa mở tay từng bài.

## 5. Chưa làm / giới hạn

- Video (`VIDEO`) chưa hỗ trợ ở app; không có dữ liệu video được phép dùng. EX15 không áp dụng.
- Nội dung hướng dẫn chưa được người có chuyên môn rà.
- Xem thêm `13-exercise-library-design.md` §7.
