# VieGym — Ngày 9: Dữ liệu món Việt và thư viện dinh dưỡng

**Mục tiêu:** Có tối thiểu 50 món/thực phẩm với khẩu phần, kcal, protein, carb, fat và nguồn; Android tìm và xem chi tiết dữ liệu thật từ PostgreSQL.

**Thời gian:** 6–8 giờ. Đây là hướng dẫn để thực hiện; checklist chưa xác nhận phần mềm hoặc dữ liệu đã hoàn thành. Dùng số migration tiếp theo thực tế, không ghi đè migration cũ.

## 0. Đầu vào — 15 phút

- [ ] Auth và API client ngày 4 hoạt động.
- [ ] Hồ sơ và mục tiêu ngày 5 có kết quả đã kiểm tra.
- [ ] Có cách tìm kiếm không dấu/phân trang đã dùng ngày 6.
- [ ] Đã lưu code hiện tại và có database test riêng.

Hôm nay làm dữ liệu và tra cứu; thêm món vào bữa ở ngày 10. Nếu dữ liệu nguồn chưa đủ, ghi rõ số đã xác minh, không bịa giá trị để đạt chỉ tiêu 50.

## 1. Chốt khẩu phần và nguồn — 45 phút

Tạo `docs/20-food-data-policy.md`. Một bản ghi Food đại diện một món/cách chế biến với một khẩu phần chuẩn xác định.

| Trường | Quy tắc |
|---|---|
| servingLabel | Ví dụ 100 g, 1 phần 250 g; cần mô tả đo được |
| servingGrams | Khối lượng ăn được, có thể null nếu nguồn không xác định |
| kcal/protein/carbs/fat | Tất cả cùng cơ sở một khẩu phần |
| preparation | Sống/chín, cách chế biến hoặc công thức |
| source | Tên tài liệu/URL, mã thực phẩm, trang hoặc bản ghi |
| quality | SOURCED / ESTIMATED / DEMO |
| referenceDate | Ngày truy cập/phiên bản nguồn |

Không trộn dữ liệu nguyên liệu sống và món chín; không coi mọi tô phở hoặc đĩa cơm tấm là cùng một khối lượng. Nếu tính món từ công thức, ghi khối lượng từng nguyên liệu, số phần thành phẩm và giả định hao hụt. Dữ liệu ước tính cần nhãn rõ.

Quy đổi khi nguồn cho 100 g và phần thực tế nặng w g: `nutrientPerServing = nutrientPer100g × w / 100`. Không dùng phép này cho chất lỏng theo ml nếu chưa có quan hệ khối lượng/thể tích. Không biến số liệu thiếu thành 0.

Nguồn ưu tiên là bảng thành phần thực phẩm/tài liệu có thể truy xuất. USDA có thể hỗ trợ đối chiếu nguyên liệu; không mặc nhiên đại diện đúng công thức món Việt. Các giá trị seed trong SRS là demo, không tự chuyển nhãn thành dữ liệu đã xác minh.

- [ ] Mỗi món có cùng cơ sở khẩu phần cho mọi chỉ số.
- [ ] Phân biệt sourced/estimated/demo và thiếu dữ liệu.
- [ ] Có ghi nguồn và cách chế biến.

## 2. Tạo danh mục 50 món — 60–90 phút

Tạo `docs/21-food-catalog.md` hoặc file dữ liệu nguồn riêng có cột ổn định. Phân bổ gợi ý: 10 tinh bột, 10 thịt/cá/trứng/đậu, 10 rau/trái cây, 15 món Việt tổng hợp, 5 đồ uống/bữa phụ. Đây là kế hoạch thu thập, không phải thực đơn.

Thực hiện:

1. Liệt kê tên/mã món duy nhất và trạng thái chế biến.
2. Thu thập khẩu phần và số liệu từ nguồn có thể kiểm tra.
3. Chuẩn hóa đơn vị kcal và gram.
4. Rà món trùng tên nhưng khác cách nấu trước khi gộp.
5. Kiểm tra số không âm, trường thiếu, giá trị bất thường.
6. Đối chiếu năng lượng quy đổi 4P+4C+9F để phát hiện sai đơn vị; chênh lệch không tự chứng minh nguồn sai vì còn cách tính chất xơ và thành phần khác. Không âm thầm sửa kcal nguồn cho khớp.
7. Ghi nguồn ảnh và quyền dùng; ảnh có thể null.

Ví dụ fixture kiểm thử kỹ thuật, không phải dữ liệu món thật: một khẩu phần có 200 kcal, P=10 g, C=30 g, F=4 g. Tách fixture test khỏi danh mục dùng demo người dùng.

## 3. Schema và nhập dữ liệu — 60 phút

```sql
CREATE TABLE food_categories (
    id UUID PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL
);
CREATE TABLE foods (
    id UUID PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,
    search_name VARCHAR(300) NOT NULL,
    category_id UUID NOT NULL REFERENCES food_categories(id),
    preparation TEXT NOT NULL,
    serving_label VARCHAR(150) NOT NULL,
    serving_grams NUMERIC(10,2) CHECK (serving_grams > 0),
    calories NUMERIC(10,2) NOT NULL CHECK (calories >= 0),
    protein_grams NUMERIC(10,2) NOT NULL CHECK (protein_grams >= 0),
    carb_grams NUMERIC(10,2) NOT NULL CHECK (carb_grams >= 0),
    fat_grams NUMERIC(10,2) NOT NULL CHECK (fat_grams >= 0),
    source_reference TEXT NOT NULL,
    data_quality VARCHAR(20) NOT NULL,
    image_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    revision INTEGER NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (data_quality IN ('SOURCED','ESTIMATED','DEMO'))
);
```

Các món thiếu một chỉ số bắt buộc giữ ở file thu thập chưa nhập active, hoặc thiết kế trạng thái thiếu dữ liệu riêng; không điền 0 giả để vượt constraint. Kiểu BigDecimal khớp NUMERIC. Seed UUID/code ổn định, danh mục trước, món sau.

Nhập bằng migration seed một lần hoặc importer có kiểm tra trước ghi. Importer chạy lại theo code: báo inserted/updated/skipped/errors, không xóa rồi tạo toàn bộ. Cập nhật món phải tăng revision; ngày 10 snapshot sẽ giữ lịch sử meal entry.

- [ ] Migration không trùng bảng đã có.
- [ ] Import báo số lượng thực tế, không bỏ qua lỗi im lặng.
- [ ] Chạy lại theo cơ chế chọn không sinh bản ghi trùng.
- [ ] Có fixture inactive để test.

## 4. API tra cứu — 60 phút

| Endpoint | Nội dung |
|---|---|
| GET `/api/v1/foods?keyword=pho&category=NOODLES&page=0&size=20` | Danh sách active |
| GET `/api/v1/foods/{id}` | Chi tiết active |
| GET `/api/v1/food-categories` | Danh mục code/name |

Yêu cầu Bearer hợp lệ; quyền xem theo thiết kế User/Admin. Size 1–50; keyword tối đa 100 ký tự; mã lọc sai trả 400; không có kết quả trả 200 items rỗng; inactive/ID không tồn tại trả 404.

Dùng cùng normalizer tiếng Việt ngày 6, escape ký tự LIKE và query parameterized. Phân trang ở database, sort name/id ổn định. Response riêng, không trả entity trực tiếp:

```json
{
  "id": "<food-uuid>",
  "name": "Tên món đã chuẩn hóa",
  "servingLabel": "1 khẩu phần đã xác định",
  "servingGrams": null,
  "nutritionPerServing": {
    "calories": 200, "proteinGrams": 10,
    "carbGrams": 30, "fatGrams": 4
  },
  "dataQuality": "DEMO",
  "sourceReference": "Fixture kỹ thuật, không phải dữ liệu món thật",
  "revision": 1,
  "imageUrl": null
}
```

Không tích hợp API bên ngoài vào mỗi lần tìm món; dữ liệu lõi tra trong PostgreSQL nội bộ theo SRS.

## 5. Flutter — 60–90 phút

Tạo `features/nutrition/food/{data,application,presentation}`. Làm food_search_page và food_detail_page.

1. Parse nutrition số nguyên/số lẻ bằng num, xử lý ảnh null.
2. Tìm không dấu với debounce, lọc danh mục, reset trang khi query đổi.
3. Query mới không bị response cũ ghi đè.
4. Thẻ hiển thị rõ kcal theo khẩu phần nào.
5. Chi tiết có khẩu phần, P/C/F, cách chế biến, nguồn và nhãn dữ liệu.
6. Ảnh lỗi có fallback, không che mất dinh dưỡng.
7. Chuẩn bị trả foodId về màn chọn món ngày 10; chưa hiển thị nút lưu bữa như đã hoạt động.

- [ ] Có loading/rỗng/lỗi/tải thêm/thử lại.
- [ ] Không hiển thị kcal/100 g nếu dữ liệu đang theo phần khác.
- [ ] Nội dung ước tính/demo được ghi rõ.

## 6. Kiểm thử — 45 phút

| Mã | Test | Expected |
|---|---|---|
| F01 | Đối chiếu 10 món với nguồn | Đúng khẩu phần/đơn vị/số liệu |
| F02 | Keyword có dấu/không dấu | Kết quả thống nhất |
| F03 | Filter + pagination | Không thiếu/trùng do client |
| F04 | Detail inactive | 404 |
| F05 | Missing JWT | 401 |
| F06 | Import lại | Không nhân đôi |
| F07 | Dữ liệu thiếu/âm | Bị phát hiện trước active |
| F08 | Ảnh lỗi | UI còn thông tin và không crash |

Ghi vào `docs/22-day-9-verification.md`: tổng món active, số sourced/estimated/demo, số thiếu và bằng chứng rà nguồn. Chạy backend tests và flutter analyze trong dự án thật, ghi kết quả thực tế.

## 7. Đóng ngày

- [ ] Có tối thiểu 50 bản ghi đủ cơ sở khẩu phần; nếu thiếu ghi đúng số còn lại.
- [ ] API nội bộ tìm/lọc/chi tiết hoạt động.
- [ ] Android tra cứu được.
- [ ] Import và nguồn dữ liệu được lưu để tái tạo.
- [ ] Commit sau khi xem diff: `feat: add Vietnamese food catalog`.

Nhật ký: số món theo chất lượng, nguồn còn thiếu, kết quả API/Android, lỗi, commit, việc đầu ngày 10.

**Mốc chuyển tiếp:** Có foodId và dinh dưỡng khẩu phần đáng tin cậy để thêm vào bữa. Ngày 10 xây Meal Planner.

Nguồn tham khảo: [USDA dữ liệu và tài liệu từng loại](https://fdc.nal.usda.gov/download-datasets/) để kiểm tra dữ liệu nguồn; không thay nguồn món Việt cụ thể.
