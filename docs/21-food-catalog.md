# Danh mục món ăn — báo cáo nhập dữ liệu

> Sinh tự động bởi `backend/tools/food-seed/generate-food-seed.mjs`. Quy tắc: `20-food-data-policy.md`.

Nguồn: [Viện Dinh dưỡng Quốc gia — Tra cứu giá trị dinh dưỡng món ăn](https://viendinhduong.vn/vi/cong-cu-va-tien-ich/gia-tri-dinh-duong-mon-an), tải 2026-11-04T13:59:43.9786095+00:00 bằng `data/crawl_viendinhduong.ps1` → `data/viendinhduong_mon_an.json`.

## 1. Tổng quan

| Chỉ số | Số lượng |
|---|---:|
| Bản ghi trong nguồn | 1024 |
| Nhập vào `foods` | 928 |
| — đang hiển thị (`is_active`) | 912 |
| — ẩn chờ rà (lệch năng lượng > 15%) | 16 |
| Không nhập (thiếu/sai số liệu) | 96 |
| Chất lượng SOURCED / ESTIMATED / DEMO | 928 / 0 / 0 |
| Có link ảnh nguồn | 928 |
| Tên xuất hiện nhiều lần (khác vùng/khác phần) | 109 tên, 311 món |

## 2. Theo vùng đo

| Mã | Vùng | Số món | Hiển thị |
|---|---|---:|---:|
| VPF | Toàn quốc | 349 | 339 |
| HAN | Hà Nội | 189 | 189 |
| HAP | Hải Phòng | 168 | 163 |
| SFF | Miền Bắc | 222 | 221 |

## 3. Theo danh mục (giữ nguyên danh mục nguồn)

| Mã (`category`) | Tên | Số món | Hiển thị |
|---|---|---:|---:|
| `COM_CAC_LOAI` | Cơm các loại | 8 | 8 |
| `CHE_CARAMEN_KEM` | Chè, caramen, kem | 18 | 18 |
| `BUN_COM_XOI_CHAO` | Bún, cơm, xôi, cháo | 49 | 49 |
| `MON_CANH` | Món canh | 1 | 1 |
| `MON_XAO` | Món xào | 14 | 14 |
| `CAC_MON_BANH_KEO` | Các món bánh, kẹo | 58 | 54 |
| `CAC_MON_XOI_CHE` | Các món xôi, chè | 23 | 22 |
| `CAC_MON_TRUNG_SUA_VA_CHE_PHAM` | Các món trứng, sữa và chế phẩm | 21 | 21 |
| `CAC_LOAI_TRAI_CAY` | Các loại trái cây | 15 | 15 |
| `CAC_MON_CHE_BIEN_SAN` | Các món chế biến sẵn | 3 | 3 |
| `BANH_CANH_BANH_DA_BUN_CHAO_SUP_HOANH_THANH_HU_TIEU_MIEN_MY_PHO_LAU` | Bánh canh, bánh đa, bún, cháo, súp, hoành thánh, hủ tiếu, miến, mỳ, phở, lẩu | 99 | 99 |
| `BANH_DA_BUN_PHO` | Bánh đa, bún, phở | 101 | 98 |
| `COM_CHAO_XOI` | Cơm, cháo, xôi | 80 | 79 |
| `BURGER_PIZZA` | Burger, pizza | 14 | 14 |
| `CHE_CAC_LOAI_GIAI_KHAT` | Chè, các loại giải khát | 50 | 50 |
| `GIAI_KHAT` | Giải khát | 6 | 6 |
| `NGAO_OC` | Ngao, ốc | 11 | 11 |
| `CAC_LOAI_BANH` | Các loại bánh | 123 | 123 |
| `CAC_MON_KHAC` | Các món khác | 234 | 227 |

## 4. Ẩn chờ rà (16)

Năng lượng nguồn lệch nhiều so với 4P + 4C + 9F. Có thể do nhập sai số liệu ở nguồn hoặc thành phần khác (chất xơ, rượu…); chưa đủ căn cứ để sửa nên **giữ nguyên số nguồn** và ẩn.

| Mã | Tên | kcal nguồn | 4P+4C+9F | Lệch |
|---|---|---:|---:|---:|
| VPF-000341 | Kẹo sô cô la | 27 | 522.3 | 1834% |
| HAP-211084 | Cháo sườn | 574.7 | 2640.2 | 359% |
| VPF-000133 | Nem rán / Chả giò chiên | 102 | 431.1 | 323% |
| VPF-000141 | Thịt lợn xá xíu | 846 | 2655.0 | 214% |
| VPF-000337 | Phồng tôm chiên | 104 | 284.4 | 173% |
| VPF-000166 | Mực xào dưa | 175 | 456.3 | 161% |
| VPF-000343 | Bim bim | 35 | 90.3 | 158% |
| HAP-211063 | Chim quay | 434.9 | 943.1 | 117% |
| VPF-000129 | Khoai tây chiên | 466 | 164.4 | 65% |
| VPF-000322 | Bánh kem xốp | 109 | 157.7 | 45% |
| SFF-113013 | Bún riêu cua, giò, bò | 661.3 | 425.4 | 36% |
| VPF-000143 | Tôm lăn bột chiên | 305 | 411.1 | 35% |
| HAP-211021 | Bún riêu cua sườn sụn | 582.9 | 775.5 | 33% |
| HAP-221021 | Khoai tây chiên | 372.1 | 262.2 | 30% |
| VPF-000360 | Xôi trắng miệng bát | 420 | 509.5 | 21% |
| HAP-213081 | Bún ốc | 548.5 | 434.2 | 21% |

## 5. Không nhập (96)

| Mã | Tên | Lý do |
|---|---|---|
| HAN-122017 | Củ từ luộc | thiếu fat |
| HAN-122023 | Nước ép ổi (size l) | thiếu fat |
| HAN-122024 | Nước ép cam (size l) | thiếu fat |
| HAN-123033 | Nước mía | thiếu protein; thiếu fat; thiếu carbs |
| HAP-211067 | Trà cúc táo đỏ | thiếu fat |
| HAP-213057 | Trà hoa cúc | thiếu fat |
| HAP-221012 | Nước ép dứa | thiếu fat |
| HAP-221014 | Nước mía | thiếu fat |
| HAP-223020 | Giò lợn | thiếu carbs |
| SFF-122009 | Quả cóc dầm | thiếu fat |
| SFF-122016 | Củ dong luộc | thiếu fat |
| SFF-122070 | Kẹo bông gòn | thiếu protein; thiếu fat |
| SFF-211066 | Nước trà hoa cúc | thiếu fat |
| VPF-000001 | Cơm tẻ lưng bát | thiếu fat |
| VPF-000002 | Cơm nắm | thiếu fat |
| VPF-000003 | Cơn hến | thiếu fat |
| VPF-000004 | Cơm rang thập cẩm | thiếu fat |
| VPF-000005 | Cơm suất văn phòng ( Thịt nạc vai, đậu phụ) | thiếu fat |
| VPF-000006 | Cơm tẻ miệng bát | thiếu fat |
| VPF-000014 | Sushi phô mai | thiếu carbs |
| VPF-000019 | Canh bí đao nấu sườn lợn | thiếu kcal; carbs đơn vị μg (cần g) |
| VPF-000022 | Canh cá mè nấu chuối | thiếu carbs |
| VPF-000044 | Cá quả (Cá lóc) kho | thiếu carbs |
| VPF-000046 | Cá Trạch kho | thiếu carbs |
| VPF-000047 | Cá Trắm kho | thiếu kcal |
| VPF-000053 | Thịt bò kho | thiếu carbs |
| VPF-000056 | Thịt lợn ba chỉ kho tàu | thiếu carbs |
| VPF-000059 | Thịt lợn thăn rim | thiếu carbs |
| VPF-000063 | Bí đỏ luộc | thiếu fat |
| VPF-000064 | Bí xanh luộc | thiếu fat |
| VPF-000066 | Củ cải luộc | thiếu fat |
| VPF-000067 | Dạ dày luộc | thiếu carbs |
| VPF-000069 | Dồi lợn luộc | thiếu carbs |
| VPF-000071 | Đậu cove luộc | thiếu fat |
| VPF-000072 | Đậu phụ luộc | thiếu carbs |
| VPF-000073 | Đuôi lợn luộc | thiếu carbs |
| VPF-000076 | Ghẹ hấp | thiếu carbs |
| VPF-000077 | Giá đỗ luộc | thiếu fat |
| VPF-000079 | Lưỡi lợn luộc | thiếu carbs |
| VPF-000081 | Ngọn su su luộc | thiếu fat |
| VPF-000083 | Ốc vặn luộc | thiếu carbs |
| VPF-000084 | Rau bắp cải luộc | thiếu fat |
| VPF-000086 | Rau muống luộc | thiếu carbs |
| VPF-000087 | Rau mùng tơi luộc | thiếu fat |
| VPF-000088 | Rau ngót luộc | thiếu fat |
| VPF-000092 | Thịt bò bắp luộc | thiếu carbs |
| VPF-000093 | Thịt chân giò luộc | thiếu carbs |
| VPF-000094 | Thịt gà luộc | thiếu carbs |
| VPF-000095 | Thịt lợn ba chỉ luộc | thiếu carbs |
| VPF-000096 | Thịt lợn nạc vai luộc | thiếu carbs |
| VPF-000097 | Thịt lợn thăn luộc | thiếu carbs |
| VPF-000098 | Thịt vịt luộc | thiếu carbs |
| VPF-000112 | Cá nục rán | thiếu carbs |
| VPF-000116 | Cá thu rán | thiếu carbs |
| VPF-000118 | Cá trắm rán | thiếu carbs |
| VPF-000121 | Chả cá rán | thiếu carbs |
| VPF-000138 | Thịt lợn băm viên rán | thiếu carbs |
| VPF-000140 | Thịt lợn rán | thiếu carbs |
| VPF-000142 | Tôm chiên | thiếu carbs |
| VPF-000148 | Cua đồng rang | thiếu carbs |
| VPF-000149 | Nhộng rang lá chanh | thiếu carbs |
| VPF-000165 | Lươn xào sả ớt | thiếu carbs |
| VPF-000169 | Mướp đắng xào trứng | thiếu carbs |
| VPF-000179 | Rau muống xào | thiếu carbs |
| VPF-000200 | Cà pháo muối | thiếu fat |
| VPF-000205 | Hành củ muối | thiếu fat |
| VPF-000206 | Kiệu muối | thiếu fat |
| VPF-000241 | Cháo đỗ đen | thiếu fat |
| VPF-000248 | Cháo thịt băm | thiếu kcal; thiếu carbs |
| VPF-000302 | Bánh xu xê | thiếu carbs |
| VPF-000308 | Bánh mỳ ngọt (Kinh Đô) | thiếu protein |
| VPF-000317 | Bánh đậu xanh | thiếu carbs |
| VPF-000320 | Bánh gạo | thiếu carbs |
| VPF-000363 | Xôi xéo | thiếu fat |
| VPF-000367 | Chè hạt sen long nhãn | thiếu fat |
| VPF-000369 | Chè sen | thiếu fat |
| VPF-000374 | Trứng chim cút luộc | thiếu carbs |
| VPF-000396 | Phô mai tam giác | thiếu carbs |
| VPF-000397 | Bưởi | thiếu fat |
| VPF-000398 | Cam | thiếu fat |
| VPF-000399 | Chôm chôm | thiếu fat; thiếu carbs |
| VPF-000403 | Dưa lê | thiếu fat |
| VPF-000404 | Dưa vàng | thiếu fat |
| VPF-000405 | Dứa ta | thiếu fat |
| VPF-000407 | Đu đủ | thiếu fat |
| VPF-000408 | Gioi (mận) | thiếu fat |
| VPF-000412 | Mít dai | thiếu fat |
| VPF-000414 | Na | thiếu fat |
| VPF-000415 | Nhãn | thiếu fat |
| VPF-000416 | Nho ngọt | thiếu fat |
| VPF-000417 | Ổi | thiếu fat |
| VPF-000420 | Quýt | thiếu fat |
| VPF-000423 | Táo tây | thiếu fat |
| VPF-000425 | Vải thiều | thiếu fat |
| VPF-000426 | Vú sữa | thiếu fat |
| VPF-000428 | Chuối khô | thiếu fat |
