# Kiểm tra ngày 9 — dữ liệu món Việt và thư viện dinh dưỡng

Thiết kế/chính sách: `20-food-data-policy.md`. Báo cáo nhập: `21-food-catalog.md`. Ngày kiểm tra: 2026-11-04.

## 1. Môi trường

Như ngày 4–8. Flyway local: **V9 `create foods`**, **V10 `seed foods`** áp dụng thành công (DB lên v10). App cài bản debug qua `adb install`, gọi backend qua `adb reverse tcp:8080 tcp:8080`; ảnh món tải từ viendinhduong.vn qua mạng của điện thoại.

## 2. Số liệu

| Chỉ số | Số lượng |
|---|---:|
| Bản ghi nguồn | 1.024 |
| Món nhập (`foods`) | 928 |
| Đang hiển thị | 912 |
| Ẩn chờ rà (kcal lệch > 15% so với 4P+4C+9F) | 16 |
| Không nhập (thiếu chỉ số/đơn vị sai) | 96 |
| SOURCED / ESTIMATED / DEMO | 928 / 0 / 0 |
| Danh mục | 19 (giữ nguyên nguồn) |

Vượt chỉ tiêu tối thiểu 50 món của plan. Chi tiết theo vùng, danh mục và danh sách món ẩn/không nhập: `21-food-catalog.md`.

## 3. Kiểm thử tự động

| Phần | Lệnh | Kết quả |
|---|---|---|
| Backend | `.\mvnw.cmd test` (PostgreSQL thật qua Testcontainers) | 95/95 đạt (9 test mới trong `FoodLibraryIntegrationTests`) |
| Mobile | `flutter analyze` | No issues found |
| Mobile | `flutter test` | 63/63 đạt (8 test mới trong `test/food_test.dart`) |

Lỗi tìm ra và đã sửa:
- Gọi API với query string không phải UTF-8 hợp lệ (vd. `keyword=ph%FF`) trả **500**. Đã thêm xử lý `InvalidParameterException` → `400 VALIDATION_ERROR`; kiểm tra lại bằng curl trên backend local. (MockMvc không đi qua bộ giải mã của Tomcat nên không có test tự động cho trường hợp này.)
- Thứ tự sắp xếp: PostgreSQL sắp theo collation (bỏ qua dấu phẩy) khác `String.compareTo` của Java. Không phải lỗi; test so với `ORDER BY` của DB.

## 4. Bộ nghiệm thu plan ngày 9

| Mã | Tình huống | Bằng chứng | Kết quả |
|---|---|---|---|
| F01 | Đối chiếu với nguồn | `importedFoodsMatchSourceFile`: **cả 928 món** trong DB khớp tên/kcal/đạm/bột đường/béo với file nguồn. Đối chiếu thêm 10 mã ngẫu nhiên giữa file và API trực tiếp của Viện ngày 2026-11-04: 10/10 khớp. Ảnh phở `VPF-000272` ghi "314kcal" khớp số liệu (xác nhận cơ sở "1 phần") | Đạt |
| F02 | Keyword có dấu/không dấu | `keywordIgnoresAccentsAndCase`, `searchNamesMatchJavaNormalizer` (name_search do script Node sinh khớp `SearchText` Java ở mọi dòng); curl local: "phở bò tái" và "pho bo tai" cùng 8 kết quả | Đạt |
| F03 | Lọc + phân trang | `filterAndPaginationAreComplete`: ghép các trang size 7 đủ, không trùng, đúng thứ tự DB; lọc vùng đúng | Đạt |
| F04 | Chi tiết món ẩn | `inactiveFoodIsHidden`: 404, không có trong tìm kiếm | Đạt |
| F05 | Thiếu JWT | `requiresAuthentication` | Đạt (401) |
| F06 | Nhập lại | `reimportIsIdempotent`: chạy lại V10 hai lần, vẫn 928 món, revision giữ 1; món bị sửa tay được khôi phục và revision tăng | Đạt |
| F07 | Dữ liệu thiếu/âm | Script loại 96 bản ghi thiếu chỉ số (không điền 0); test xác nhận không bản ghi thiếu nào có trong DB; CHECK ≥ 0 ở DB | Đạt |
| F08 | Ảnh lỗi | Widget test (trong test mọi ảnh mạng đều lỗi): hiện biểu tượng, đủ dinh dưỡng, không crash; test tay §5 | Đạt (tự động và test tay bước 9) |

## 5. Test tay trên Android

Người dùng tự thao tác trên điện thoại thật, 2026-11-04. 10/10 bước đạt.

| # | Thao tác | Kết quả |
|---|---|---|
| 1 | Mở tab "Món ăn" | Đạt: có ảnh, thẻ ghi "… kcal / 1 phần ăn theo nguồn", vùng · mã, chú thích không phải 100 g |
| 2 | Tìm `pho bo tai` | Đạt: 8 món "Phở bò tái…" |
| 3 | Tìm `phở bò tái` | Đạt: cùng 8 món |
| 4 | Chi tiết VPF-000272 | Đạt: 314 kcal, 18,7 / 47,4 / 5,5 g, nguồn + mã, nhãn "Theo nguồn công bố" |
| 5 | Lọc vùng Hà Nội, bỏ chip | Đạt |
| 6 | Lọc danh mục, cuộn tải thêm tới hết | Đạt |
| 7 | Từ khóa không có kết quả | Đạt: thông báo rỗng + nút xóa |
| 8 | Món ẩn VPF-000341 | Đạt: không xuất hiện |
| 9 | Tắt mạng điện thoại, mở món | Đạt: ảnh thay bằng biểu tượng, dinh dưỡng đủ, không lỗi |
| 10 | Đăng nhập phoneb | Đạt |

## 6. Tồn đọng

- 16 món ẩn chờ người có chuyên môn rà; 96 món thiếu số liệu.
- Nguồn không có khối lượng phần → không quy đổi theo gram.
- Ảnh và số liệu thuộc bản quyền Viện Dinh dưỡng Quốc gia; cần xin phép trước khi phát hành công khai.
- Chưa thêm món vào bữa (ngày 10).
