# VieGym — Ngày 10: Meal Planner và tổng dinh dưỡng trong ngày

**Mục tiêu:** User thêm/sửa/xóa món theo bữa và ngày, xem tổng kcal/macro so với mục tiêu. Dữ liệu lịch sử không đổi khi admin sửa món gốc.

**Thời gian:** 6–8 giờ. SQL/API dưới đây là mẫu tích hợp; checklist chỉ đánh dấu sau khi kiểm tra trên dự án.

## 0. Chuẩn bị — 15 phút

- [ ] Auth, mục tiêu ngày 5 và thư viện món ngày 9 hoạt động.
- [ ] Có hai user A/B và fixture món để kiểm thử số học.
- [ ] Chốt ngày theo timezone user, không theo timezone máy server.
- [ ] Xem migration hiện tại và giữ bản code trước sửa.

## 1. Chốt nghiệp vụ — 30 phút

- Một meal plan/user/ngày; 4 bữa BREAKFAST/LUNCH/DINNER/SNACK.
- Một entry là một món + số khẩu phần thập phân, ví dụ 1.5.
- Không tự gộp các entry cùng món: hai lần thêm có thể là hai lần ăn có chủ ý.
- Khi thêm, lấy dinh dưỡng và khẩu phần từ server, lưu snapshot cùng revision và quality/source.
- Sửa servings của entry cũ tính từ snapshot cũ; không đọc lại dinh dưỡng mới của food.
- Food inactive chặn thêm mới nhưng entry lịch sử vẫn xem/sửa khẩu phần/xóa được.
- Vượt mục tiêu chỉ cảnh báo, không chặn ghi thực tế.
- Mục tiêu ngày được chụp khi tạo plan; đổi hồ sơ không thay ngầm mục tiêu các ngày cũ.
- Nếu lúc tạo plan chưa có mục tiêu, vẫn ghi ăn được; target=null, giao diện báo chưa có cơ sở so sánh. Chọn chính sách này và cập nhật tiền điều kiện use case cũ.

Khi muốn cập nhật mục tiêu của hôm nay sau sửa hồ sơ, cung cấp thao tác rõ ràng riêng; nếu chưa làm, giữ snapshot và hiển thị ngày tính. Không lấy mục tiêu hiện tại so với lịch sử mà không giải thích.

## 2. Schema — 45 phút

```sql
CREATE TABLE meal_plans (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    meal_date DATE NOT NULL,
    timezone VARCHAR(100) NOT NULL,
    target_snapshot JSONB,
    revision INTEGER NOT NULL DEFAULT 1,
    UNIQUE (user_id, meal_date)
);
CREATE TABLE meal_entries (
    id UUID PRIMARY KEY,
    meal_plan_id UUID NOT NULL REFERENCES meal_plans(id),
    food_id UUID NOT NULL REFERENCES foods(id),
    food_revision INTEGER NOT NULL,
    meal_type VARCHAR(20) NOT NULL,
    servings NUMERIC(8,2) NOT NULL CHECK (servings > 0 AND servings <= 100),
    food_name_snapshot VARCHAR(200) NOT NULL,
    serving_label_snapshot VARCHAR(150) NOT NULL,
    kcal_snapshot NUMERIC(10,2) NOT NULL CHECK (kcal_snapshot >= 0),
    protein_snapshot NUMERIC(10,2) NOT NULL CHECK (protein_snapshot >= 0),
    carb_snapshot NUMERIC(10,2) NOT NULL CHECK (carb_snapshot >= 0),
    fat_snapshot NUMERIC(10,2) NOT NULL CHECK (fat_snapshot >= 0),
    quality_source_snapshot JSONB NOT NULL,
    client_entry_id UUID NOT NULL,
    revision INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (meal_plan_id, client_entry_id),
    CHECK (meal_type IN ('BREAKFAST','LUNCH','DINNER','SNACK'))
);
```

Snapshot kcal/P/C/F là mỗi khẩu phần chuẩn, không phải tổng sau nhân servings. Validate cấu trúc JSON snapshot ở service. Dùng BigDecimal, không tích lũy double rồi làm tròn từng món trước khi cộng.

`client_entry_id` sinh một lần cho một lần bấm thêm, giữ nguyên khi retry. Cùng key trong plan với nội dung ban đầu khác trả 409. Nếu entry đã sửa sau tạo, đối chiếu request tạo bằng payload hash/original request lưu riêng; đừng so với entry hiện tại rồi coi retry cũ là thêm mới. Có thể tái sử dụng bảng idempotency tổng quát ngày 7 nếu đã có.

- [ ] Unique plan/user/date và idempotency ở database.
- [ ] Thêm migration đúng số kế tiếp, không đè dữ liệu cũ.

## 3. API — 45 phút

| Method | Endpoint | Hành vi |
|---|---|---|
| GET | `/api/v1/meal-plans?date=YYYY-MM-DD` | Đọc thực đơn ngày |
| POST | `/api/v1/meal-plans/entries` | Thêm, tạo plan nếu cần |
| PUT | `/api/v1/meal-plans/entries/{id}` | Đổi bữa/khẩu phần với revision |
| DELETE | `/api/v1/meal-plans/entries/{id}` | Xóa sau kiểm tra ownership |

GET chưa có plan trả 200 với entries rỗng, tổng 0 và target hiện tại dạng preview, `targetSource=PREVIEW`; không tạo database trong GET. Khi plan đã có, trả snapshot và `targetSource=SNAPSHOT`.

```json
{
  "date": "2026-11-02",
  "mealType": "LUNCH",
  "foodId": "<uuid>",
  "servings": 1.5,
  "clientEntryId": "<uuid-cho-lan-them-nay>"
}
```

POST trả 201 lần đầu, 200 retry hợp lệ. PUT nhận mealType/servings/revision, không nhận kcal hoặc userId. Response sau ghi có entry và summary mới hoặc app GET lại; chốt một cách dùng nhất quán. DELETE trả 204; nếu không tìm thấy/không thuộc user trả 404, client có thể GET xác minh sau mất response.

400 dữ liệu sai, 401 phiên lỗi, 404 tài nguyên không khả dụng, 409 revision/key conflict. Size ghi chú và số lượng entry/ngày có giới hạn đề xuất để không nhận payload vô hạn.

## 4. Service và tính tổng — 60 phút

Thêm trong transaction:

1. Lấy user từ Authentication, validate ngày/bữa/servings.
2. Khóa user để tránh hai request cùng tạo plan đầu ngày; giữ thứ tự khóa nhất quán với các luồng khác.
3. Tìm/tạo plan và chụp target hiện tại.
4. Kiểm tra idempotency trước khi tạo entry thứ hai.
5. Lấy food active và snapshot nhất quán của revision hiện tại.
6. Lưu entry, tăng revision plan và trả tổng.

Mọi thao tác sửa/xóa khóa plan theo cùng thứ tự, kiểm tra user và entry revision. Update kiểu compare-and-set hoặc optimistic lock; conflict trả 409. Lỗi giữa chừng rollback cả plan/entry mới.

```text
totalKcal    = Σ(kcalSnapshot × servings)
totalProtein = Σ(proteinSnapshot × servings)
totalCarb    = Σ(carbSnapshot × servings)
totalFat     = Σ(fatSnapshot × servings)
remainingKcal = targetKcal − totalKcal
```

Giữ số âm ở remaining khi vượt mục tiêu; UI có thể hiện “vượt X kcal”. Không kẹp về 0 rồi làm mất thông tin. Tính tổng từng bữa và tổng ngày từ cùng nguồn, làm tròn HALF_UP ở response 2 chữ số. Không suy kcal từ macro thay kcal snapshot.

Fixture độc lập: món A mỗi phần 200 kcal/P10/C30/F4, món B 100/P5/C15/F2. A×1.5+B×2 → 500 kcal/P25/C75/F10. Đổi A thành 1 phần → 400/P20/C60/F8. Xóa B → 200/P10/C30/F4.

## 5. Flutter — 90 phút

Tạo `features/nutrition/meal/{data,application,presentation}`:

1. Màn ngày với date picker và bốn bữa.
2. Thêm món mở food search ngày 9, nhận foodId, xem khẩu phần.
3. Input servings bằng số thập phân; hiển thị bản xem trước nhưng dùng kết quả server sau lưu.
4. Sinh clientEntryId một lần, disable nút khi gửi.
5. Sửa/xóa từ entry; revision conflict tải bản mới, không ghi đè im lặng.
6. Hiển thị tổng kcal/P/C/F và nguồn mục tiêu ngày.
7. Đổi ngày giữ response theo đúng query key; response cũ không ghi đè ngày mới.
8. Lỗi mạng giữ input; retry giữ key, không đổi key để “thử cho được”.
9. Logout/đổi user xóa state meal cá nhân.

- [ ] Loading/rỗng/lỗi/thử lại đầy đủ.
- [ ] Món inactive trong lịch sử vẫn đọc được snapshot.
- [ ] Target null không hiển thị 0 kcal như mục tiêu thật.

## 6. Test — 60 phút

| Mã | Nội dung | Expected |
|---|---|---|
| M01 | Fixture thêm/sửa/xóa | Khớp số cố định phía trên |
| M02 | Servings 0/âm/quá lớn | 400, không ghi |
| M03 | Cùng POST/key retry | Một entry |
| M04 | Hai lần thêm khác key | Hai entry có chủ ý |
| M05 | Hai request tạo plan cùng ngày | Một plan |
| M06 | Admin sửa food | Entry cũ không đổi |
| M07 | Food inactive | Không thêm mới, lịch sử còn |
| M08 | A tác động entry B | 404 |
| M09 | Đổi target | Ngày cũ giữ snapshot |
| M10 | Ngày gần nửa đêm/timezone | Không lưu nhầm ngày |

Ghi `docs/23-day-10-verification.md`, chạy unit test phép cộng và integration test transaction/ownership trên database test.

## 7. Đóng ngày

- [ ] CRUD meal entry chạy trên Android.
- [ ] Số liệu và snapshot đúng.
- [ ] Retry/concurrency/ownership đã test.
- [ ] Có minh chứng và lỗi còn lại.
- [ ] Commit: `feat: add daily meal planner`.

Nhật ký: số test đạt, phép tính fixture, kết quả A/B, Android, giới hạn target history, commit. Ngày 11 tổng hợp vào dashboard.
