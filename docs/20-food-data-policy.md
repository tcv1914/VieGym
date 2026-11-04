# Dữ liệu món ăn — chính sách và thiết kế ngày 9

Bảng gốc: `03-database-design.md` §6, quy tắc: `04-business-rules.md` §5 (BR-N01), API: `05-api-contract.md` §9. Migration: `V9__create_foods.sql` (bảng), `V10__seed_foods.sql` (dữ liệu, sinh tự động). Báo cáo nhập: `21-food-catalog.md`. Kết quả kiểm tra: `22-day-9-verification.md`.

## 1. Nguồn

| Mục | Nội dung |
|---|---|
| Nguồn | Viện Dinh dưỡng Quốc gia — công cụ [Tra cứu giá trị dinh dưỡng món ăn](https://viendinhduong.vn/vi/cong-cu-va-tien-ich/gia-tri-dinh-duong-mon-an) |
| Cách lấy | `data/crawl_viendinhduong.ps1` gọi API công khai của trang, lưu nguyên trường gốc vào `data/viendinhduong_mon_an.json` (1.024 bản ghi, tải 2026-11-04) |
| Cơ sở số liệu | **Một phần ăn** như ảnh minh họa của nguồn (vd. ảnh phở ghi "314 kcal" khớp số liệu). Nguồn **không ghi khối lượng phần** |
| Vùng đo | Mỗi bản ghi thuộc một bộ dữ liệu: `VPF` toàn quốc, `HAN` Hà Nội, `HAP` Hải Phòng, `SFF` miền Bắc |
| Ảnh | Link tuyệt đối tới ảnh trên viendinhduong.vn; app tải trực tiếp, không sao chép. Ảnh thuộc bản quyền của Viện (chân trang nguồn: "Bản quyền thuộc Viện Dinh Dưỡng Quốc Gia"). Người dùng đã chọn cách trỏ link (2026-11-04) |
| Chất lượng | Tất cả `SOURCED` (lấy nguyên số của nguồn). Chưa có món `ESTIMATED`/`DEMO` |

Dữ liệu dùng cho mục đích học tập của đồ án, có ghi nguồn và mã bản ghi ở từng món. Trước khi phát hành công khai cần xin phép Viện về số liệu và ảnh.

## 2. Khẩu phần

- Một bản ghi `foods` = một món của một nguồn đo, với **một** khẩu phần chuẩn; kcal/đạm/bột đường/béo đều cho đúng khẩu phần đó (BR-N01).
- Nguồn không ghi gram → `serving_size`, `serving_unit` = NULL, `serving_description` = "1 phần ăn theo nguồn". **Không suy đoán gram**, không quy đổi sang /100 g.
- Khác docs/03 ngày 2: `serving_size`, `serving_unit` được phép NULL (CHECK: cả hai NULL, hoặc size > 0 và unit `g`/`ml`). Món nhập sau này có khối lượng thì điền đủ.
- Cùng tên món (vd. "Xôi xéo" có 5 bản ghi, 420–724 kcal) là các phần ăn đo ở vùng/quán khác nhau → **giữ riêng từng bản ghi**, không gộp, không lấy trung bình. Bỏ ràng buộc UNIQUE theo tên của docs/03; phân biệt bằng vùng + mã nguồn, app hiển thị cả hai.
- Ngày 10 (thực đơn): người dùng chọn số phần (`servings`), dinh dưỡng = `servings × số liệu 1 phần` (BR-N03), chụp snapshot.

## 3. Danh mục

Giữ nguyên 19 danh mục của nguồn (`food_categories`), mã lọc = tên bỏ dấu viết hoa (vd. `BANH_DA_BUN_PHO`). Một số danh mục của nguồn chồng nhau (vd. "Bánh đa, bún, phở" và "Bánh canh, bánh đa, bún, cháo… phở, lẩu"); không tự gộp để khỏi gán sai. Plan gợi ý chia 5 nhóm (tinh bột, đạm, rau quả, món tổng hợp, đồ uống) — không áp dụng vì nguồn đã phân loại theo món.

## 4. Kiểm tra trước khi nhập

Script `backend/tools/food-seed/generate-food-seed.mjs` đọc JSON nguồn, kiểm tra từng bản ghi, sinh `V10__seed_foods.sql` và `21-food-catalog.md`.

| Kiểm tra | Xử lý |
|---|---|
| Thiếu kcal / đạm / bột đường / béo (giá trị rỗng) | **Không nhập** — không điền 0 (96 bản ghi) |
| Đơn vị khác `Kcal`/`g` | Không nhập |
| Số âm / không phải số | Không nhập |
| Danh mục/vùng không có trong nguồn | Không nhập |
| kcal lệch > 15% so với 4P + 4C + 9F | Nhập nhưng **ẩn** (`is_active = false`) + `review_note`; giữ nguyên số nguồn (16 bản ghi, vd. "Thịt lợn xá xíu" ghi 503 g đạm/846 kcal) |
| Số có > 2 chữ số lẻ | Làm tròn 2 chữ số (cột NUMERIC(…, 2)) |

Ngưỡng 15% chỉ để phát hiện số liệu khả nghi; chênh lệch nhỏ hơn có thể do chất xơ, rượu, cách làm tròn của nguồn nên vẫn hiển thị.

## 5. Nhập và nhập lại

- `id` = UUID v5 theo mã nguồn → chạy lại script cho cùng id.
- SQL `INSERT … ON CONFLICT (code) DO UPDATE … WHERE (số liệu) IS DISTINCT FROM (mới)`: chạy lại không nhân đôi; bản ghi có số liệu đổi được cập nhật và tăng `revision`. `is_active` không bị ghi đè (giữ quyết định ẩn/hiện của admin).
- Flyway chỉ chạy V10 một lần. Cập nhật dữ liệu nguồn về sau: tải lại JSON → chạy script → **sao chép SQL thành migration mới** (V10 đã chạy thì không sửa).
- Test `FoodLibraryIntegrationTests` đối chiếu **toàn bộ** 928 món trong DB với file nguồn, chạy lại seed hai lần để kiểm tra không nhân đôi.

## 6. API

- `GET /api/v1/foods?keyword=&category=&region=&page=&size=` — chỉ món active; tìm không dấu (cùng `SearchText` ngày 6, escape ký tự LIKE); `size` 1–100 (docs/05 §1.2, khác plan 1–50); `category` lạ / `region` lạ → 400; sắp `name_search`, `id`.
- `GET /api/v1/foods/{id}` — món ẩn hoặc không tồn tại → 404.
- `GET /api/v1/food-filters` — `categories` (chỉ danh mục còn món hiển thị, theo thứ tự nguồn) và `regions`. Đặt tên giống `/exercise-filters` ngày 6 (plan gọi `/food-categories`).
- Cần đăng nhập. Không gọi API ngoài khi tra cứu: dữ liệu nằm trong PostgreSQL.

## 7. App

```text
lib/features/nutrition/food/
├── data/         food_api.dart, food_models.dart
├── application/  food_list_controller.dart
└── presentation/ food_list_page.dart, food_detail_page.dart, food_widgets.dart
```

- Tab mới "Món ăn". Tìm có debounce 400 ms; đổi từ khóa/bộ lọc → về trang đầu; response của truy vấn cũ về muộn bị bỏ qua; cuộn gần cuối tự tải thêm; lỗi trang sau giữ món đã có.
- Thẻ: "314 kcal / 1 phần ăn theo nguồn", vùng · mã. Dòng chú thích đầu danh sách: số liệu cho 1 phần, không phải 100 g.
- Chi tiết: ảnh (lỗi → biểu tượng), khẩu phần, kcal, đạm/bột đường/béo, giải thích không có khối lượng, nhãn chất lượng, nguồn + mã, ghi chú bản quyền ảnh.
- Chưa có nút "thêm vào bữa" (ngày 10).

## 8. Giới hạn

- Không có khối lượng phần → chưa so sánh được các món theo 100 g, chưa quy đổi được khi người dùng ăn "nửa bát".
- Không có vi chất (vitamin, natri…) trong app dù nguồn có; chỉ dùng 4 chỉ số cần cho mục tiêu ngày 5.
- 16 món ẩn chờ người có chuyên môn rà; 96 món thiếu số liệu chưa dùng được.
- Ảnh phụ thuộc site nguồn (đổi đường dẫn hay chặn tải → app hiện biểu tượng thay ảnh).
