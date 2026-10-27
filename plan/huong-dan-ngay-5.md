# VieGym — Ngày 5: Hồ sơ sức khỏe và mục tiêu dinh dưỡng

**Mục tiêu:** User đã đăng nhập nhập được hồ sơ, backend tính BMI/BMR/TDEE và mục tiêu calories/macro, lưu PostgreSQL và hiển thị lại trên Android. Có kiểm thử công thức và kiểm tra dữ liệu riêng tư giữa hai tài khoản.

**Thời gian:** khoảng 6–8 giờ nếu Auth ngày 4 đã hoạt động. Tài liệu là hướng dẫn triển khai, không xác nhận phần mềm đã được viết hoặc vượt kiểm thử. Các đoạn mã/SQL là mẫu cần tích hợp theo cấu trúc thực tế.

## 0. Rà đầu vào — 15 phút

- [ ] Đăng nhập Android và GET `/api/v1/users/me` hoạt động.
- [ ] Backend kiểm tra JWT, trạng thái user và session.
- [ ] Có database, Flyway và xử lý lỗi validation.
- [ ] Có hai tài khoản test A/B.
- [ ] Đã chốt phạm vi và các quyết định tính toán ngày 2.
- [ ] Lưu thay đổi hiện tại trước khi làm module mới.

Đường dẫn trong tài liệu tính từ thư mục gốc VieGym. Không tạo lại project hoặc bỏ lớp bảo mật để thử hồ sơ cho nhanh.

## 1. Chốt dữ liệu và chính sách tính — 45 phút

Tạo `docs/11-health-calculation-rules.md` để ghi rõ dữ liệu đầu vào, công thức, đơn vị và nguồn. Tách các yêu cầu SRS khỏi những lựa chọn triển khai mới.

### Dữ liệu đầu vào

| Trường | Kiểu/API | Ý nghĩa |
|---|---|---|
| `dateOfBirth` | YYYY-MM-DD | Ngày sinh, không nhập tuổi song song |
| `bmrEquationVariant` | MALE/FEMALE/UNSPECIFIED | Nhánh hệ số dùng cho công thức; không tự suy ra từ tên/giới tính hiển thị |
| `heightCm` | Số thập phân | Chiều cao cm |
| `weightKg` | Số thập phân | Cân nặng kg |
| `activityLevel` | SEDENTARY/LIGHT/MODERATE/HIGH/VERY_HIGH | Mức vận động |
| `goal` | LOSE_WEIGHT/GAIN_WEIGHT/BUILD_MUSCLE/MAINTAIN | Mục tiêu |
| `timezone` | IANA timezone | Mặc định Asia/Ho_Chi_Minh |

Tên hiển thị dùng từ tài khoản ngày 4, không tạo thêm trường cùng nghĩa nếu chưa cần. Nếu SRS có giới tính Nam/Nữ/Khác, giữ thông tin hồ sơ riêng khi cần và giải thích rõ lựa chọn hệ số công thức. Không tự gán hệ số MALE/FEMALE cho người chọn Khác hoặc không cung cấp thông tin.

MVP đề xuất giới hạn luồng tự tính cho người trưởng thành, ví dụ 18–65 tuổi, nhằm giới hạn phạm vi đồ án. Đây là quyết định phạm vi sản phẩm cần ghi nhận, không phải tuyên bố công thức chính xác cho mọi người trong khoảng đó. Bản gốc nghiên cứu Mifflin dự đoán năng lượng nghỉ ở đối tượng khỏe mạnh, không phải phép đo trực tiếp. Giữ nhãn BMR theo SRS nhưng mô tả kết quả là ước tính.

### Công thức theo SRS

```text
heightM = heightCm / 100
BMI = weightKg / (heightM × heightM)

BMR, nhánh MALE   = 10 × weightKg + 6.25 × heightCm − 5 × age + 5
BMR, nhánh FEMALE = 10 × weightKg + 6.25 × heightCm − 5 × age − 161

TDEE = BMR × activityFactor
```

| ActivityLevel | Hệ số theo SRS |
|---|---:|
| SEDENTARY | 1.2 |
| LIGHT | 1.375 |
| MODERATE | 1.55 |
| HIGH | 1.725 |
| VERY_HIGH | 1.9 |

Tuổi là số năm tròn từ ngày sinh đến ngày tính theo timezone của hồ sơ. Backend lấy ngày từ Clock để test được, không gọi ngày hệ thống rải rác trong công thức.

### Calories và macro: chốt chính sách ứng dụng

SRS đưa khoảng tăng/giảm calories nhưng chưa chốt một con số và tỷ lệ macro duy nhất. Để code và test nhất quán, có thể dùng **chính sách demo đề xuất**, cần đối chiếu lựa chọn ngày 2 trước khi áp dụng:

| Goal | Delta kcal so với TDEE |
|---|---:|
| LOSE_WEIGHT | -300 |
| GAIN_WEIGHT | +300 |
| BUILD_MUSCLE | +200 |
| MAINTAIN | 0 |

```text
targetCalories = roundHalfUp(TDEE + delta)
proteinGram = targetCalories × 0.25 / 4
fatGram     = targetCalories × 0.25 / 9
carbGram    = targetCalories × 0.50 / 4
```

Tỷ lệ 25%/25%/50% là cấu hình kỹ thuật minh họa để kiểm thử, chưa phải khuyến nghị dinh dưỡng cá nhân hay yêu cầu đã có trong SRS. Có thể thay bằng quy tắc đã được chốt với giảng viên; phải cập nhật đồng thời test, tài liệu và policy version. Phiên bản demo này chưa thực hiện quy tắc protein riêng cho mục tiêu tăng cơ nếu SRS yêu cầu mức protein cao hơn; ghi rõ giới hạn đó.

Không dùng AI để tính các số cốt lõi này. Dashboard, Meal Planner và AI đọc cùng kết quả chính thức từ backend.

### Làm tròn và trường hợp chưa tính được

- Giữ độ chính xác nội bộ cho BMI/BMR/TDEE, làm tròn HALF_UP tại ranh giới lưu/response đã thống nhất.
- BMI trả 2 chữ số; BMR/TDEE trả 2 chữ số; kcal mục tiêu số nguyên; macro gram trả 2 chữ số.
- Tính macro từ kcal mục tiêu đã chốt, không từ TDEE hiển thị đã làm tròn.
- Tổng năng lượng quy đổi từ macro đã làm tròn có thể lệch nhỏ; kiểm thử với tolerance được định nghĩa.
- Nếu chọn UNSPECIFIED: lưu hồ sơ, có thể tính BMI, nhưng BMR/TDEE/target là null và trả trạng thái CALCULATION_UNAVAILABLE. Không trả 0 hoặc giữ mục tiêu cũ như thể còn hợp lệ.
- Nếu dữ liệu thuộc nhánh không hỗ trợ tự tính của MVP: trả lỗi rõ hoặc trạng thái chưa hỗ trợ theo chính sách đã chốt; không âm thầm kẹp về giá trị khác.

- [ ] Công thức, hệ số và chính sách được ghi rõ.
- [ ] Tách giới tính hiển thị khỏi lựa chọn nhánh công thức khi cần.
- [ ] Xử lý dữ liệu thiếu/chưa hỗ trợ.
- [ ] Có `policyVersion`, ví dụ `demo-v1`, và quy tắc làm tròn.

## 2. Tạo migration hồ sơ, mục tiêu và lịch sử — 45 phút

Nếu schema ngày 4 đã có V2, tạo migration tiếp theo `V3__create_health_profiles.sql`. Nếu số hiện tại khác, chọn số chưa dùng. Nếu bảng đã tồn tại theo ERD ngày 2, viết ALTER phù hợp thay vì CREATE trùng.

```sql
CREATE TABLE health_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    date_of_birth DATE NOT NULL,
    bmr_equation_variant VARCHAR(20) NOT NULL,
    height_cm NUMERIC(6,2) NOT NULL CHECK (height_cm > 0),
    weight_kg NUMERIC(6,2) NOT NULL CHECK (weight_kg > 0),
    activity_level VARCHAR(20) NOT NULL,
    goal VARCHAR(20) NOT NULL,
    timezone VARCHAR(100) NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (bmr_equation_variant IN ('MALE', 'FEMALE', 'UNSPECIFIED')),
    CHECK (activity_level IN ('SEDENTARY','LIGHT','MODERATE','HIGH','VERY_HIGH')),
    CHECK (goal IN ('LOSE_WEIGHT','GAIN_WEIGHT','BUILD_MUSCLE','MAINTAIN'))
);

CREATE TABLE nutrition_targets (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    target_calories INTEGER NOT NULL CHECK (target_calories > 0),
    protein_grams NUMERIC(10,2) NOT NULL CHECK (protein_grams >= 0),
    carb_grams NUMERIC(10,2) NOT NULL CHECK (carb_grams >= 0),
    fat_grams NUMERIC(10,2) NOT NULL CHECK (fat_grams >= 0),
    bmr NUMERIC(10,2) NOT NULL,
    tdee NUMERIC(10,2) NOT NULL,
    policy_version VARCHAR(50) NOT NULL,
    calculated_on DATE NOT NULL,
    source_profile_version BIGINT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE health_profile_revisions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    profile_version BIGINT NOT NULL,
    snapshot JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, profile_version)
);
```

Revision lưu snapshot đầu vào và kết quả mỗi lần thay đổi có ý nghĩa, không lưu password/token. Đây là lịch sử phục vụ truy vết thay đổi hồ sơ; biểu đồ cân nặng và API weight log triển khai ngày 13. Nếu ERD đã dùng bảng lịch sử khác, tận dụng thay vì tạo hai cơ chế trùng nhau.

BMI có thể tính từ chiều cao/cân nặng khi trả response. BMR/TDEE/targets lưu snapshot có `calculated_on` và phiên bản để biết thời điểm tính; khi user đổi tuổi/mục tiêu hoặc policy đổi, chỉ thay mục tiêu sau thao tác tính lại/lưu đã quy định. GET không âm thầm ghi đè mục tiêu hiện tại.

- [ ] Migration chạy được; entity enum lưu STRING.
- [ ] Một hồ sơ và một mục tiêu hiện tại/user.
- [ ] Có lịch sử thay đổi theo SRS.
- [ ] Không sửa migration đã áp dụng.

## 3. Viết bộ tính toán độc lập và unit test — 60 phút

Cấu trúc backend đề xuất:

```text
health/
├── HealthProfileController.java
├── HealthProfileService.java
├── HealthCalculator.java
├── NutritionPolicy.java
├── dto/
├── entity/
└── repository/
```

`HealthCalculator` chỉ nhận đầu vào, ngày tính và trả kết quả; không gọi database, HTTP hoặc AI. `NutritionPolicy` chứa delta và tỷ lệ macro đã chốt. Dùng BigDecimal cho dữ liệu lưu/tính cần làm tròn kiểm soát được; tạo bằng chuỗi hoặc valueOf, tránh `new BigDecimal(double)`.

Thứ tự:

1. Tính tuổi bằng `Period.between(dateOfBirth, calculationDate).getYears()`.
2. Validate trước khi chia chiều cao.
3. Tính BMI.
4. Chọn hệ số MALE/FEMALE; nếu UNSPECIFIED trả kết quả chưa đủ điều kiện.
5. Tính BMR, TDEE, calories và macro theo policy.
6. Áp dụng quy tắc làm tròn một cách nhất quán.
7. Trả kết quả có status, policyVersion và calculatedOn.

### Dữ liệu kiểm thử cố định

Cố định ngày tính **2026-10-27**, không để test đổi kết quả theo ngày chạy.

| Case | Ngày sinh | Nhánh | Kg/cm | Vận động | Mục tiêu |
|---|---|---|---|---|---|
| A | 2004-10-27 | MALE | 70 / 175 | MODERATE | LOSE_WEIGHT |
| B | 2004-10-27 | FEMALE | 60 / 165 | SEDENTARY | MAINTAIN |

Kết quả theo đúng policy demo ở Bước 1:

| Chỉ số | A | B |
|---|---:|---:|
| Tuổi | 22 | 22 |
| BMI | 22.86 | 22.04 |
| BMR | 1688.75 | 1360.25 |
| TDEE trước làm tròn | 2617.5625 | 1632.3 |
| TDEE hiển thị | 2617.56 | 1632.30 |
| Calories mục tiêu | 2318 | 1632 |
| Protein g | 144.88 | 102.00 |
| Carb g | 289.75 | 204.00 |
| Fat g | 64.39 | 45.33 |

Đối chiếu mẫu A bằng tay:

```text
BMR = 10×70 + 6.25×175 − 5×22 + 5 = 1688.75
TDEE = 1688.75 × 1.55 = 2617.5625
Target = roundHalfUp(2617.5625 − 300) = 2318
Protein = 2318 × 0.25 / 4 = 144.875 → 144.88
Carb = 2318 × 0.50 / 4 = 289.75
Fat = 2318 × 0.25 / 9 = 64.388888… → 64.39
```

Test thêm: trước/sau sinh nhật, ngày sinh tương lai, chiều cao 0, số âm, enum sai, tất cả hệ số vận động, tất cả mục tiêu và UNSPECIFIED. Ngày sinh 29/2 cần có quy ước tính tuổi được test rõ ràng.

- [ ] Hai case có expected value cố định, không tính expected bằng chính method đang test.
- [ ] Dùng fixed Clock cho kiểm thử service phụ thuộc ngày hiện tại.
- [ ] Công thức không phụ thuộc UI/database.

## 4. DTO và validation — 30 phút

Quy tắc validation đề xuất cho phạm vi demo, cần điều chỉnh theo phạm vi đã chốt:

| Trường | Kiểm tra |
|---|---|
| Ngày sinh | Bắt buộc, không tương lai; tuổi thuộc phạm vi tự tính đã công bố |
| Chiều cao | Ví dụ 100–250 cm, tối đa 2 số lẻ |
| Cân nặng | Ví dụ 30–300 kg, tối đa 2 số lẻ |
| Nhánh BMR | Enum hợp lệ, có thể UNSPECIFIED |
| Vận động/mục tiêu | Enum hợp lệ |
| Timezone | `ZoneId.of` chấp nhận; mặc định đã thống nhất |
| userId, BMI, kcal client gửi | Không dùng làm nguồn tính hoặc quyền sở hữu |

Các khoảng chiều cao/cân nặng là ràng buộc kỹ thuật giới hạn MVP, không phải định nghĩa sức khỏe bình thường. UI hiển thị lỗi phạm vi hỗ trợ, không kết luận bệnh lý.

DTO sử dụng `@NotNull`, `@DecimalMin`, `@DecimalMax`, `@Digits`, kiểm tra ngày sinh và timezone tại lớp phù hợp. Controller dùng `@Valid @RequestBody`; dữ liệu lỗi trả 400 và fieldErrors theo ngày 4. Validation chéo theo ngày/tuổi cần service hoặc validator riêng; `@Past` một mình chưa đủ kiểm tra tuổi.

## 5. Triển khai GET/PUT hồ sơ — 60 phút

| Method | Endpoint | Hành vi |
|---|---|---|
| GET | `/api/v1/health-profile/me` | Lấy hồ sơ và mục tiêu hiện tại của user |
| PUT | `/api/v1/health-profile/me` | Tạo/thay thế đầy đủ hồ sơ, tính và lưu mục tiêu mới |

Chính sách MVP: GET khi chưa có hồ sơ trả **404 HEALTH_PROFILE_NOT_FOUND**; app chuyển tới form tạo mới. Phải phân biệt với lỗi mạng và 401.

Request mẫu:

```json
{
  "dateOfBirth": "2004-10-27",
  "bmrEquationVariant": "MALE",
  "heightCm": 175,
  "weightKg": 70,
  "activityLevel": "MODERATE",
  "goal": "LOSE_WEIGHT",
  "timezone": "Asia/Ho_Chi_Minh"
}
```

PUT trả 200 trong cả tạo/cập nhật theo contract MVP này. Response gồm:

```json
{
  "profile": {
    "dateOfBirth": "2004-10-27",
    "bmrEquationVariant": "MALE",
    "heightCm": 175,
    "weightKg": 70,
    "activityLevel": "MODERATE",
    "goal": "LOSE_WEIGHT",
    "timezone": "Asia/Ho_Chi_Minh"
  },
  "metrics": {
    "bmi": 22.86,
    "bmr": 1688.75,
    "tdee": 2617.56
  },
  "nutritionTarget": {
    "calories": 2318,
    "proteinGrams": 144.88,
    "carbGrams": 289.75,
    "fatGrams": 64.39
  },
  "calculationStatus": "READY",
  "calculatedOn": "2026-10-27",
  "policyVersion": "demo-v1"
}
```

Ngày trong response là fixture test; chạy ngày khác phải tính tuổi/ngày tương ứng, không hardcode. Với UNSPECIFIED, bmr/tdee/nutritionTarget là null và status CALCULATION_UNAVAILABLE, không dùng số 0 thay thế.

Service trong transaction:

1. Lấy UUID từ Authentication đã xác minh, không nhận userId từ body.
2. Tải/khóa bản ghi user làm điểm khóa ổn định cho upsert lần đầu; mọi luồng ghi hồ sơ tuân theo cùng quy tắc.
3. Validate và tính kết quả trước khi ghi.
4. Tạo/cập nhật profile, tăng version khi có thay đổi hoặc tính lại theo ngày/policy.
5. Upsert target nếu tính được; nếu chuyển sang trạng thái chưa tính được, xóa/vô hiệu target cũ trong cùng giao dịch.
6. Ghi revision tương ứng với snapshot đầu vào và kết quả.
7. Commit và trả response từ dữ liệu vừa lưu.

PUT giống hệt và không thay đổi ngày/policy/kết quả thì có thể không tăng version hoặc thêm revision. Đảm bảo request đồng thời không tạo hai profile/target hoặc revision trùng. Lỗi giữa chừng rollback toàn bộ.

PUT là thao tác lưu có chủ ý và tính lại mục tiêu; UI cần nói rõ trước khi lưu chỉnh sửa. Không ghi lại tổng dinh dưỡng của các bữa ăn đã lưu khi mục tiêu đổi. Khi triển khai lịch sử so sánh mục tiêu theo ngày sau này, dùng snapshot mục tiêu theo ngày thay vì áp mục tiêu mới lên lịch sử một cách ngầm định.

- [ ] GET/PUT chỉ tác động user hiện tại.
- [ ] Không có endpoint đọc hồ sơ tùy ý bằng userId trong phạm vi hôm nay.
- [ ] Tạo/cập nhật có transaction và ràng buộc unique.
- [ ] Mục tiêu cũ không tồn tại như mục tiêu đang hiệu lực khi không còn tính được.
- [ ] History được lưu cùng thay đổi profile.

## 6. Kiểm tra API trước giao diện — 30 phút

1. Đăng nhập A và B, lấy access token riêng.
2. GET A khi chưa có profile: 404 có code đúng.
3. PUT A bằng case A, đối chiếu kết quả.
4. GET A và khởi động lại backend, xác nhận dữ liệu còn đúng.
5. GET B: chưa có hồ sơ, không trả A.
6. PUT B bằng case B, sau đó GET A vẫn nguyên dữ liệu.
7. Gửi dữ liệu lỗi, xác nhận 400 và dữ liệu cũ không bị sửa.
8. Thiếu JWT, JWT hết hạn, session thu hồi: 401.

Không chụp token/đầy đủ dữ liệu cá nhân thật vào báo cáo. Dùng dữ liệu giả có chủ ý để kiểm thử.

## 7. Flutter: form hồ sơ và màn kết quả — 90 phút

```text
lib/features/health/
├── data/
│   ├── health_api.dart
│   ├── health_repository.dart
│   └── health_profile_model.dart
├── application/
│   └── health_profile_controller.dart
└── presentation/
    ├── health_profile_form_page.dart
    └── health_summary_page.dart
```

Thứ tự:

1. Dùng lớp API có Bearer/refresh của ngày 4.
2. Model parse được số nguyên/số lẻ và nullable metrics; không cast mọi số JSON trực tiếp thành double, dùng `(value as num).toDouble()` khi thích hợp.
3. Sau login/khôi phục phiên, GET profile. 404 đúng code → form mới; profile có sẵn → màn tổng quan tạm.
4. Dùng Form, GlobalKey<FormState> và validator cho trường bắt buộc.
5. Ngày sinh dùng date picker; dropdown ánh xạ nhãn tiếng Việt sang enum API.
6. Số đo hiển thị rõ cm/kg; có thể chuẩn hóa dấu phẩy thập phân thành dấu chấm cho đầu vào đơn giản, từ chối định dạng mơ hồ và parse bằng tryParse.
7. Lưu: validate → disable nút → PUT → dùng response backend hiển thị kết quả.
8. Khi chỉnh sửa, nạp giá trị hiện tại; nhắc việc lưu sẽ tính lại mục tiêu.
9. Nếu lỗi, giữ dữ liệu đang nhập, hiển thị fieldErrors và cho thử lại.
10. Thành công: invalidation provider health/target liên quan; không tính lại bằng công thức khác trên Flutter.
11. Khi đổi tài khoản/logout: xóa state và cache sức khỏe của user trước.

Màn kết quả gồm BMI, năng lượng nghỉ ước tính theo nhãn SRS, TDEE, kcal mục tiêu, macro và nút sửa. Với CALCULATION_UNAVAILABLE, vẫn cho xem hồ sơ/BMI và giải thích dữ liệu chưa đủ; không hiển thị thẻ 0 kcal hoặc mục tiêu cũ.

Hiển thị ngắn gọn kết quả là ước tính theo công thức và cấu hình demo. Chưa cần phân loại bệnh lý theo BMI hay xây dashboard hoàn chỉnh ngày 11.

- [ ] Form có loading, lỗi và chống gửi lặp.
- [ ] Lưu thành công rồi mở lại đọc dữ liệu thật.
- [ ] Đổi mục tiêu/cân nặng làm kết quả cập nhật theo backend.
- [ ] UNSPECIFIED và dữ liệu null không làm app crash.
- [ ] 401 đi qua cơ chế phiên; 404 hồ sơ dẫn tới tạo mới.
- [ ] Đăng nhập B không thấy dữ liệu A.

## 8. Bộ kiểm thử nghiệm thu — 45–60 phút

| Mã | Kiểm tra | Kết quả mong đợi |
|---|---|---|
| H01 | Công thức case A/B với ngày cố định | Khớp bảng expected |
| H02 | Các mức vận động | Ánh xạ đúng hệ số |
| H03 | Các goal | Delta đúng policy |
| H04 | Trước/sau sinh nhật | Tuổi tròn đúng |
| H05 | Ngày sinh tương lai, chiều cao 0/âm, cân nặng sai | 400, không ghi dữ liệu |
| H06 | Enum/timezone không hợp lệ | 400 có lỗi rõ |
| H07 | Profile chưa tồn tại | 404 đúng code |
| H08 | PUT rồi GET/restart | Dữ liệu và mục tiêu được giữ |
| H09 | Hai PUT đồng thời cùng user | Một profile/target, không lỗi unique chưa xử lý |
| H10 | Không có JWT/session đã thu hồi | 401 |
| H11 | A/B đọc và sửa hồ sơ | Tách biệt dữ liệu |
| H12 | Client gửi BMI/kcal/userId tự chọn | Không thể ghi đè kết quả server hoặc user khác |
| H13 | Lỗi khi lưu target/history | Rollback profile, không lưu nửa chừng |
| H14 | Chuyển sang UNSPECIFIED | Không giữ target cũ làm mục tiêu hiệu lực |
| H15 | Mất mạng khi lưu và mở lại form | Có lỗi/thử lại, xác nhận bằng GET, không báo thành công giả |
| H16 | Lưu chỉnh sửa | Có revision và kết quả theo ngày/policy |

Ghi kết quả vào `docs/12-day-5-verification.md`. Unit test công thức không cần database; integration test quyền và transaction dùng database test riêng, không dùng database demo để chạy test có xóa dữ liệu.

Lệnh kiểm tra, chạy tại đúng thư mục:

```powershell
# Trong backend, với cấu hình database test đã chuẩn bị
.\mvnw.cmd test

# Trong mobile
flutter analyze
flutter test
```

Chỉ chạy bộ test phù hợp dự án hiện tại; cập nhật test mẫu counter nếu không còn liên quan. Đánh dấu rõ kết quả nào là test tự động, kiểm tra API thủ công hoặc chưa kiểm tra.

## 9. Lỗi thường gặp

| Lỗi | Kiểm tra |
|---|---|
| BMI rất nhỏ/lớn | Nhầm cm/m hoặc dùng phép chia số nguyên |
| BMR lệch | Sai nhánh công thức, tuổi hoặc hệ số 6.25 |
| Mục tiêu lệch 1 kcal | Làm tròn TDEE quá sớm hoặc dùng HALF_EVEN thay HALF_UP |
| Macro không khớp | Dùng tỷ lệ khác, nhầm 4/9 kcal/g hoặc tính từ TDEE thay target |
| Test tuổi thay đổi mỗi ngày | Chưa truyền fixed Clock/ngày cố định |
| GET profile trả 401 | Kiểm tra Bearer/refresh/session, không mở public hồ sơ |
| Mất target khi lỗi | Ghi profile/target/history chưa cùng transaction |
| Dữ liệu A xuất hiện ở B | Repository hoặc provider chưa gắn user hiện tại |
| Ngày sinh lệch một ngày | Ngày sinh là LocalDate, không chuyển qua timestamp UTC |
| Kết quả cũ sau lưu | Chưa dùng response mới hoặc invalidation provider |
| Lỗi double trong Dart | JSON số nguyên/số lẻ parse chưa thống nhất |

## 10. Checklist đóng ngày 5 — 15 phút

- [ ] Có tài liệu công thức, policy và nguồn.
- [ ] Phân biệt yêu cầu SRS và lựa chọn demo.
- [ ] Migration/profile/target/history hoạt động.
- [ ] Backend tính và lưu kết quả chính thức.
- [ ] Unit test công thức có expected độc lập.
- [ ] GET/PUT kiểm tra được bằng hai tài khoản.
- [ ] Android nhập, sửa, lưu và mở lại được hồ sơ.
- [ ] Xử lý thiếu dữ liệu và nhánh công thức chưa hỗ trợ.
- [ ] Có kết quả kiểm thử và lỗi còn lại.
- [ ] Không log/commit dữ liệu sức khỏe thật, token hoặc secret.

Tại thư mục gốc, xem nội dung thay đổi trước khi commit:

```powershell
git status
git diff
git add .
git diff --cached --stat
git diff --cached
git commit -m "feat: add health profiles and nutrition target calculations"
```

### Nhật ký cuối ngày

```text
Đường dẫn dự án:
Policy version và quy tắc tính đã dùng:
Kết quả unit test công thức:
Kết quả GET/PUT hồ sơ:
Kết quả phân quyền A/B:
Kết quả Android lưu/mở lại:
Lịch sử hồ sơ:
Chưa hoàn thành và lỗi:
Commit:
Việc đầu tiên ngày mai:
```

**Điều kiện sang ngày 6:** Hồ sơ lưu thật, công thức được kiểm thử, dữ liệu A/B tách biệt và app đọc lại đúng. Ngày 6 làm thư viện bài tập; biểu đồ cân nặng đầy đủ giữ cho ngày 13.

## Nguồn đối chiếu

- [Mifflin và cộng sự, nghiên cứu gốc năm 1990](https://pubmed.ncbi.nlm.nih.gov/2305711/): nguồn phương trình dự đoán năng lượng nghỉ; không phải nguồn cho tỷ lệ macro demo hoặc mọi hệ số/chính sách ứng dụng.
- Các hệ số vận động và khoảng delta theo tài liệu SRS VieGym đã đọc ở đầu cuộc trò chuyện; tỷ lệ macro và con số delta cụ thể ở hướng dẫn này là đề xuất triển khai cần chốt.
- [Spring MVC Validation](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-controller/ann-validation.html): validation đầu vào controller.
- [Flutter Form Validation](https://docs.flutter.dev/cookbook/forms/validation): form, validator và phản hồi lỗi.
