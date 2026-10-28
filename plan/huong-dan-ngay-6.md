# VieGym — Ngày 6: Thư viện bài tập

**Mục tiêu:** User đăng nhập xem được danh sách bài tập lưu thật trong PostgreSQL, tìm theo tên, lọc theo nhóm cơ/thiết bị/độ khó và mở chi tiết có hướng dẫn tiếng Việt, lỗi thường gặp và media.

**Thời lượng:** khoảng 6–8 giờ. Đây là hướng dẫn triển khai với ví dụ SQL/API, không phải xác nhận mã nguồn đã chạy hoặc tính năng đã kiểm thử. Các ví dụ cần tích hợp theo schema và phiên bản framework thực tế.

## 0. Rà đầu vào — 15 phút

- [ ] Auth ngày 4 hoạt động: Bearer JWT, kiểm tra user/session, refresh và logout.
- [ ] Android gọi backend được bằng cấu hình ngày 3.
- [ ] Database và Flyway sẵn sàng.
- [ ] Có phạm vi và use case thư viện bài tập ngày 2.
- [ ] Đã lưu thay đổi hiện tại vào Git sau khi kiểm tra secret.

Hồ sơ ngày 5 chưa hoàn thiện không phải lý do để bỏ bảo mật hoặc dùng dữ liệu tài khoản giả. Thư viện là dữ liệu dùng chung, nhưng quyền xem theo thiết kế hiện tại vẫn yêu cầu user/admin đăng nhập và tài khoản hoạt động. Không bắt buộc có hồ sơ sức khỏe để tra cứu bài tập.

Hôm nay chưa làm Workout Builder, tạo lịch hay ghi sets thực tế; các phần đó ở ngày 7–8. Chưa xây giao diện admin CRUD; ngày 6 nhập dữ liệu bằng migration/script nội bộ.

Các đường dẫn dưới đây tính từ thư mục gốc VieGym.

## 1. Chốt cấu trúc dữ liệu và bộ lọc — 30 phút

Tạo `docs/13-exercise-library-design.md`.

| Trường bài tập | Ý nghĩa |
|---|---|
| id | UUID, dùng cho API và liên kết giáo án sau này |
| code | Mã ổn định để seed/import không tạo trùng |
| name | Tên hiển thị tiếng Việt, có thể kèm tên tiếng Anh |
| searchName | Tên chuẩn hóa phục vụ tìm kiếm không dấu |
| primaryMuscleGroup | Nhóm cơ chính, bắt buộc |
| equipment | Thiết bị chính, bắt buộc; BODYWEIGHT cho bài không dụng cụ |
| difficulty | BEGINNER / INTERMEDIATE / ADVANCED |
| instructions | Hướng dẫn bằng tiếng Việt |
| commonMistakes | Lỗi thường gặp |
| thumbnailUrl | Ảnh nhỏ, nullable |
| mediaType/mediaUrl | IMAGE / GIF / VIDEO và URL, nullable khi chưa có media |
| isActive | Có được hiển thị trong thư viện user không |
| contentSource/license | Nguồn nội dung và quyền sử dụng |

MVP dùng một nhóm cơ chính và một thiết bị chính/bài để hoàn thành trong ngày. Nếu ERD đã dùng quan hệ nhiều nhóm cơ/thiết bị, giữ thiết kế đó và bổ sung bảng nối; không âm thầm hạ cấp thiết kế. Ghi rõ giới hạn bộ lọc chỉ theo nhóm/thiết bị chính nếu chọn mô hình đơn giản.

Nhóm cơ mẫu: CHEST, BACK, SHOULDERS, BICEPS, TRICEPS, LEGS, GLUTES, CORE. Thiết bị mẫu: BODYWEIGHT, DUMBBELL, BARBELL, MACHINE, CABLE, RESISTANCE_BAND, PULLUP_BAR.

Quy tắc:

- Các bộ lọc khác loại kết hợp bằng AND.
- Keyword tìm trên tên chuẩn hóa; trim, không phân biệt hoa/thường và dấu tiếng Việt.
- Keyword trống tương đương không tìm kiếm.
- Active là điều kiện bắt buộc ở cả danh sách và chi tiết, không cho client ghi đè.
- Sort mặc định ổn định theo tên rồi id; chưa cam kết thứ tự từ điển tiếng Việt nếu chưa cấu hình collation.
- Lịch sử/giáo án sau này vẫn cần tham chiếu được ID bài đã ẩn theo quy tắc riêng; không xóa bản ghi chỉ vì ngừng hiển thị thư viện.

- [ ] Chốt danh mục và mã.
- [ ] Chốt tìm không dấu và quy tắc kết hợp lọc.
- [ ] Chốt một hay nhiều nhóm cơ/thiết bị.
- [ ] Xác định media thực sự sẽ dùng cho demo.

## 2. Tạo migration — 45 phút

Nếu V3 thuộc ngày 5, dùng `V4__create_exercise_library.sql`; nếu schema thực tế khác thì chọn migration tiếp theo. Không tạo lại bảng đã có.

```sql
CREATE TABLE muscle_groups (
    id UUID PRIMARY KEY,
    code VARCHAR(40) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE equipment (
    id UUID PRIMARY KEY,
    code VARCHAR(40) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE exercises (
    id UUID PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,
    search_name VARCHAR(300) NOT NULL,
    muscle_group_id UUID NOT NULL REFERENCES muscle_groups(id),
    equipment_id UUID NOT NULL REFERENCES equipment(id),
    difficulty VARCHAR(20) NOT NULL,
    instructions TEXT NOT NULL,
    common_mistakes TEXT NOT NULL,
    thumbnail_url TEXT,
    media_type VARCHAR(10),
    media_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    content_source TEXT,
    media_license TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (difficulty IN ('BEGINNER','INTERMEDIATE','ADVANCED')),
    CHECK (media_type IS NULL OR media_type IN ('IMAGE','GIF','VIDEO')),
    CHECK ((media_url IS NULL AND media_type IS NULL)
        OR (media_url IS NOT NULL AND media_type IS NOT NULL))
);

CREATE INDEX idx_exercise_filters
    ON exercises (is_active, muscle_group_id, equipment_id, difficulty);
```

Không lưu file ảnh/video vào database. URL cần là URL thực tế hoặc key object storage được server chuyển thành URL hợp lệ. Không dùng URL ổ đĩa máy tính, link trang YouTube như URL video trực tiếp, hay đường dẫn localhost mà điện thoại không truy cập được.

Chưa cần Redis, Elasticsearch hoặc chỉ mục nâng cao cho 20–30 bản ghi. LIKE có wildcard đầu không được tăng tốc chỉ nhờ index B-tree thông thường; chỉ tối ưu khi có đo đạc và dữ liệu đủ lớn.

- [ ] Flyway chạy thành công.
- [ ] Entity/FK/enum khớp schema.
- [ ] Bảng nghiệp vụ có tên tương ứng ERD hiện tại.

## 3. Chuẩn bị 20–30 bài tập và nhập dữ liệu — 60–90 phút

Tạo bảng nguồn trong `docs/14-exercise-seed-catalog.md`, mỗi dòng có tên, nhóm cơ, thiết bị, độ khó, hướng dẫn, lỗi thường gặp, nguồn và trạng thái media.

Danh sách ứng viên để phân loại và rà nội dung, không phải giáo án khuyến nghị:

| Nhóm | Bài tập ứng viên |
|---|---|
| Ngực | Push-up, Barbell Bench Press, Incline Dumbbell Press |
| Lưng | Lat Pulldown, Seated Cable Row, One-arm Dumbbell Row |
| Vai | Dumbbell Shoulder Press, Lateral Raise, Reverse Fly |
| Tay trước | Dumbbell Curl, Hammer Curl, Cable Curl |
| Tay sau | Cable Pushdown, Overhead Dumbbell Extension, Close-grip Push-up |
| Chân | Bodyweight Squat, Goblet Squat, Leg Press, Leg Curl, Calf Raise |
| Mông | Glute Bridge, Hip Thrust |
| Core | Plank, Dead Bug, Bird Dog |

Thứ tự chuẩn bị:

1. Chốt 20–30 bài phù hợp dữ liệu demo, không cần làm toàn bộ danh sách nếu vượt phạm vi.
2. Gắn mã code ổn định, ví dụ `push-up`, `goblet-squat`.
3. Viết hướng dẫn ngắn, dễ đọc và lỗi thường gặp dựa trên nguồn đáng tin cậy; không bịa mô tả kỹ thuật chưa kiểm chứng.
4. Ghi nguồn và quyền dùng media. Tự tạo media hoặc dùng tài nguyên được phép; không giả định video công khai có quyền sao chép.
5. Tạo migration seed riêng sau migration schema hoặc script import có quy tắc rõ.
6. Nhập danh mục trước, bài tập sau để FK hợp lệ.
7. Dùng UUID cố định cho seed, giữ mã/ID ổn định để liên kết ngày 7.
8. Kiểm tra ít nhất một bài inactive trong dữ liệu test để xác minh không bị lộ ra user.

Một migration seed chỉ chạy một lần qua Flyway. Nếu dùng script có thể chạy lại, dùng upsert theo code và xác định rõ trường nào được cập nhật; không dùng cách xóa rồi tạo toàn bộ gây mất liên kết giáo án.

Không dùng URL giả để đánh dấu media hoàn thành. Cho phép null trong giai đoạn nhập dữ liệu, nhưng ghi rõ thiếu media. Mục tiêu nghiệm thu ngày 6 là có media hoạt động cho tập bài demo đã chốt; nếu chỉ một phần dữ liệu có media, báo đúng phạm vi, không ghi toàn bộ thư viện đã hoàn thiện theo SRS.

- [ ] Có 20–30 bài active với nội dung tiếng Việt đã rà.
- [ ] Có nhóm cơ, thiết bị, độ khó hợp lệ.
- [ ] Có nguồn và trạng thái quyền sử dụng media.
- [ ] Seed giữ ID ổn định, không nhân bản khi chạy lại.
- [ ] Có ít nhất một fixture inactive riêng cho kiểm thử.

## 4. Tìm tên không dấu — 30 phút

Lưu `search_name` chuẩn hóa ở backend khi nhập/cập nhật. Dùng cùng hàm cho keyword:

```java
import java.text.Normalizer;
import java.util.Locale;

public static String normalizeSearch(String value) {
    if (value == null) return "";
    String normalized = Normalizer.normalize(value, Normalizer.Form.NFD);
    return normalized.replaceAll("\\p{M}+", "")
        .replace('đ', 'd').replace('Đ', 'D')
        .toLowerCase(Locale.ROOT)
        .trim().replaceAll("\\s+", " ");
}
```

Nếu seed trực tiếp SQL, tạo search_name tương ứng bằng cùng quy tắc và kiểm tra dữ liệu. Khi làm Admin ngày 14, cập nhật search_name mỗi lần đổi tên.

Truy vấn phải parameterized. Nếu dùng LIKE, escape các ký tự `%`, `_` và ký tự escape để chúng được hiểu là nội dung tìm kiếm thông thường; khai báo cùng ký tự escape trong query. Không nối keyword vào chuỗi SQL.

- [ ] `Đẩy ngực` và `day nguc` khớp cùng bài theo dữ liệu đã seed.
- [ ] Khoảng trắng đầu/cuối và hoa/thường không làm sai kết quả.
- [ ] `%`/`_` không vô tình trở thành bộ lọc wildcard ngoài ý muốn.

## 5. Xây API danh sách, chi tiết và danh mục — 60 phút

```text
workout/exercise/
├── ExerciseController.java
├── ExerciseService.java
├── ExerciseRepository.java
├── ExerciseSpecifications.java
├── dto/
└── entity/
```

### Danh sách

```http
GET /api/v1/exercises?keyword=day%20nguc&muscleGroup=CHEST&equipment=DUMBBELL&difficulty=BEGINNER&page=0&size=20
Authorization: Bearer <access-token>
```

Query đều tùy chọn:

| Tham số | Quy tắc |
|---|---|
| keyword | Trim/chuẩn hóa; tối đa đề xuất 100 ký tự |
| muscleGroup | Mã danh mục hợp lệ; không có thì bỏ lọc |
| equipment | Mã thiết bị hợp lệ |
| difficulty | Enum hợp lệ |
| page | Số nguyên >= 0 |
| size | 1–50, mặc định 20 |

Mã danh mục/enum sai trả 400; kết hợp hợp lệ không có kết quả trả 200 với items rỗng. Trang vượt cuối trả items rỗng. Giới hạn size ở server, không chỉ Flutter.

Response mẫu cấu trúc, nội dung minh họa:

```json
{
  "items": [
    {
      "id": "<exercise-uuid>",
      "name": "Đẩy ngực với tạ đơn",
      "muscleGroup": {"code": "CHEST", "name": "Ngực"},
      "equipment": {"code": "DUMBBELL", "name": "Tạ đơn"},
      "difficulty": "BEGINNER",
      "thumbnailUrl": null
    }
  ],
  "page": 0,
  "size": 20,
  "totalElements": 1,
  "totalPages": 1,
  "hasNext": false
}
```

Tên/độ khó ví dụ không thay thế phân loại nội dung đã rà. Trả DTO phân trang riêng thay vì serialize trực tiếp Page entity để hợp đồng API ổn định.

### Chi tiết

```http
GET /api/v1/exercises/{id}
```

Trả thêm instructions, commonMistakes, mediaType, mediaUrl và nguồn phù hợp. ID không tồn tại hoặc inactive trả 404 `EXERCISE_NOT_FOUND`. Không chỉ lọc active ở danh sách rồi để API chi tiết đọc được bài đã ẩn. UUID sai định dạng trả 400.

### Danh mục dùng cho dropdown

```http
GET /api/v1/exercise-filters
```

Trả danh sách muscleGroups, equipment và difficulties có code/name. Giữ mã API và nhãn UI thống nhất, tránh hardcode hai bộ danh mục khác nhau. Endpoint này chỉ đọc, chưa có admin CRUD hôm nay.

### Truy vấn backend

Dùng Spring Data JPA Specification hoặc query parameterized tương đương. Repository có thể triển khai:

```java
public interface ExerciseRepository extends
    JpaRepository<Exercise, UUID>,
    JpaSpecificationExecutor<Exercise> {
    Optional<Exercise> findByIdAndIsActiveTrue(UUID id);
}
```

Ví dụ tên field `isActive` cần khớp entity thực tế; nếu entity đặt tên `active`, sửa derived method tương ứng. Specification luôn bắt đầu với active=true rồi AND các điều kiện khác, gọi findAll(spec, pageable). Phân trang tại database, không tải hết rồi lọc Java.

DTO mapping cần tránh N+1 khi đọc nhóm cơ/thiết bị: dùng projection/entity graph hoặc fetch quan hệ to-one phù hợp; không fetch collection tùy tiện vào truy vấn phân trang.

- [ ] Danh sách, chi tiết và danh mục hoạt động bằng token thật.
- [ ] Bộ lọc kết hợp đúng và phân trang ổn định.
- [ ] Inactive không truy cập được qua hai endpoint user.
- [ ] Trả lỗi 400/401/404 rõ ràng.
- [ ] Không có endpoint ghi công khai hoặc cho phép đổi isActive từ user.

## 6. Flutter: danh sách, tìm kiếm và bộ lọc — 60 phút

```text
lib/features/workout/exercise/
├── data/
│   ├── exercise_api.dart
│   ├── exercise_repository.dart
│   └── exercise_model.dart
├── application/
│   └── exercise_controller.dart
└── presentation/
    ├── exercise_list_page.dart
    ├── exercise_detail_page.dart
    └── exercise_filter_sheet.dart
```

Thứ tự:

1. Model danh sách/chi tiết và response phân trang.
2. Repository dùng API client có Bearer/refresh ngày 4.
3. Màn danh sách có loading, lỗi, rỗng, thử lại.
4. Thẻ bài gồm ảnh nhỏ/tên/nhóm cơ/thiết bị/độ khó.
5. Ô tìm kiếm debounce đề xuất 300–500 ms.
6. Bottom sheet lọc nhóm cơ, thiết bị, độ khó; nút áp dụng và xóa lọc.
7. Đổi keyword/filter phải reset page=0 và danh sách cũ tương ứng.
8. Nút tải thêm hoặc cuộn tới cuối; chống hai request cùng trang.
9. Không cho response truy vấn cũ ghi đè truy vấn mới: dùng query key hoặc request generation/cancellation.
10. Tải trang sau lỗi thì giữ items hiện có, chỉ hiển thị lỗi tải thêm; retry không nhân đôi items.
11. Nhấn bài tập mở chi tiết bằng ID và giữ trạng thái tìm kiếm khi quay lại.

Dùng `Uri` và queryParameters để encode keyword; không nối query string thủ công. Tránh gọi API trực tiếp trong build. Logout/đổi tài khoản phải xử lý state phiên, không để request cũ cập nhật UI phiên mới.

- [ ] Danh sách lấy dữ liệu server thật.
- [ ] Tìm kiếm không gọi mỗi phím ngay lập tức.
- [ ] Các bộ lọc kết hợp và reset được.
- [ ] Kết quả rỗng có thông báo và nút xóa lọc.
- [ ] Tải thêm không trùng hoặc mất trang.
- [ ] Quay lại danh sách giữ keyword/filter.

## 7. Flutter: màn chi tiết và media — 45–60 phút

Hiển thị tên, nhóm cơ, thiết bị, độ khó, các bước thực hiện, lỗi thường gặp và nguồn nội dung khi cần.

Ảnh/GIF có thể dùng Image.network; thêm trạng thái tải và errorBuilder:

```dart
Image.network(
  imageUrl,
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) => const SizedBox(
    height: 160,
    child: Center(child: Text('Chưa tải được hình minh họa')),
  ),
)
```

Chỉ gọi khi URL không null/rỗng. Nếu mediaType VIDEO và đã có URL video trực tiếp được phép sử dụng, cài:

```powershell
# Trong mobile
flutter pub add video_player
```

Theo mẫu chính thức: tạo VideoPlayerController.networkUrl, initialize, hiển thị đúng aspect ratio, có play/pause và trạng thái lỗi. Dispose controller khi rời màn, dừng phát khi màn/app mất hoạt động. Không tạo player cho mọi thẻ trong danh sách.

Không nhét URL trang web vào player. Media lỗi không được làm mất hướng dẫn văn bản. Nếu chỉ hỗ trợ GIF/ảnh hôm nay, ghi rõ phạm vi; không đánh dấu video đã hoàn thành.

Media host phải truy cập được từ Android. `adb reverse` cổng backend không tự reverse cổng object storage khác; kiểm tra riêng URL và cổng thực tế. Tránh hardcode link localhost vào seed dùng cho mọi môi trường. Không chuyển tiếp Bearer token sang host media bên ngoài không tin cậy.

- [ ] Hướng dẫn và lỗi thường gặp dễ đọc.
- [ ] Media demo đúng bài, mở được trên Android.
- [ ] URL lỗi/null có fallback, không crash.
- [ ] Video nếu có không tiếp tục phát sau khi rời màn.
- [ ] Bài đã ẩn khi đang mở trả thông báo không còn khả dụng khi tải lại.

## 8. Kiểm thử API và Android — 45 phút

| Mã | Tình huống | Kết quả |
|---|---|---|
| EX01 | Danh sách không filter | Chỉ active, phân trang đúng |
| EX02 | Keyword có/không dấu, hoa/thường | Kết quả nhất quán theo quy tắc |
| EX03 | Lọc từng tiêu chí | Chỉ kết quả phù hợp |
| EX04 | Lọc kết hợp | Điều kiện AND |
| EX05 | Không có kết quả | 200 items rỗng; UI rõ ràng |
| EX06 | Trang đầu/trang cuối/trang vượt cuối | Không trùng; hasNext đúng |
| EX07 | page âm, size quá giới hạn, enum sai | 400 |
| EX08 | Chi tiết active | Đủ hướng dẫn/media theo dữ liệu |
| EX09 | ID inactive hoặc không tồn tại | 404 |
| EX10 | Thiếu JWT/session logout/tài khoản khóa | Bị từ chối như ngày 4 |
| EX11 | Keyword %, _, dấu nháy | Không phá query hoặc bypass lọc |
| EX12 | Gõ nhanh, đổi filter khi request trước chậm | Response cũ không ghi đè |
| EX13 | Media lỗi/null, mạng chậm | Có fallback, không loading vô hạn |
| EX14 | Lỗi tải trang sau và retry | Giữ items cũ, không nhân đôi |
| EX15 | Quay lại màn/đóng app khi phát video | Không rò player hoặc âm thanh |
| EX16 | Seed/import chạy lại theo cách đã chọn | Không tăng trùng bản ghi |

Integration test ưu tiên: active-only ở cả list/detail, filter kết hợp, validation phân trang và auth. Unit test nhỏ cho chuẩn hóa tên và escape keyword có expected cụ thể. Không cần kiểm tra tải lớn để chứng minh hiệu năng của thư viện 25 bài.

Lưu kết quả vào `docs/15-day-6-verification.md`. Ghi rõ dữ liệu có bao nhiêu bài active, bao nhiêu bài có media đã kiểm tra, kết quả test và lỗi còn lại. Không đánh dấu đạt chỉ vì API trả 200.

Chạy tại đúng thư mục dự án và cấu hình test riêng:

```powershell
# backend
.\mvnw.cmd test

# mobile
flutter analyze
flutter test
```

## 9. Lỗi thường gặp

| Lỗi | Kiểm tra |
|---|---|
| Inactive vẫn xuất hiện | Điều kiện active chưa áp cho mọi query hoặc detail |
| Tìm không dấu không ra | Keyword và dữ liệu seed chưa cùng normalize, thiếu chuyển đ thành d |
| Danh sách lặp sau tải thêm | Sort chưa ổn định, page chưa tăng đúng hoặc request trùng |
| Bộ lọc đổi nhưng hiển thị cũ | Chưa reset page/state hoặc response cũ ghi đè |
| Lỗi lazy loading | DTO được map ngoài transaction; cần kế hoạch fetch quan hệ rõ |
| Request nhiều bất thường | Gọi API trong build, thiếu debounce hoặc query key không ổn định |
| Ảnh/video chỉ mở trên máy tính | URL dùng localhost, cổng storage chưa reachable hoặc URL không phải file |
| Video vẫn phát khi quay lại | Thiếu dispose/pause theo vòng đời |
| Import trùng bài | Không có code duy nhất hoặc script không upsert đúng |
| Media mất sau một lúc | URL ký tạm hết hạn bị lưu như URL vĩnh viễn; lưu object key và sinh URL mới |

## 10. Checklist đóng ngày 6 — 15 phút

- [ ] Có schema bài tập/danh mục theo ERD.
- [ ] Có 20–30 bài với nội dung tiếng Việt đã rà.
- [ ] Có nguồn và quyền sử dụng media.
- [ ] API tìm kiếm/lọc/phân trang hoạt động thật.
- [ ] List/detail chặn bài inactive.
- [ ] Android xem danh sách và mở chi tiết được.
- [ ] Có loading, rỗng, lỗi, thử lại và fallback media.
- [ ] Tìm kiếm nhanh không bị response cũ ghi đè.
- [ ] Có kết quả kiểm thử và số lượng media thực tế.
- [ ] Không tạo admin CRUD hoặc Workout Builder ngoài kế hoạch hôm nay.

Kiểm tra thay đổi trước commit tại thư mục gốc:

```powershell
git status
git diff
git add .
git diff --cached --stat
git diff --cached
git commit -m "feat: add searchable exercise library and detail screens"
```

### Nhật ký cuối ngày

```text
Đường dẫn dự án:
Số bài active:
Số bài có media đã kiểm tra:
Nguồn/quyền media:
Kết quả tìm kiếm không dấu:
Kết quả lọc và phân trang:
Kết quả active-only và auth:
Kết quả Android:
Lỗi/chưa hoàn thành:
Commit:
Việc đầu tiên ngày mai:
```

**Điều kiện sang ngày 7:** Android tra cứu được bài thật từ database, lọc đúng, mở chi tiết đúng và biết ID bài dùng để tạo giáo án. Ngày 7 triển khai giáo án cơ bản và lịch tuần dựa trên thư viện này.

## Tài liệu chính thức

- [Spring Data JPA Specifications](https://docs.spring.io/spring-data/jpa/reference/jpa/specifications.html): ghép điều kiện lọc; dùng tài liệu tương ứng phiên bản dependency hiện có.
- [Flutter Network Images](https://docs.flutter.dev/cookbook/images/network-image): hiển thị ảnh/GIF qua URL.
- [Flutter Image errorBuilder](https://api.flutter.dev/flutter/widgets/Image/errorBuilder.html): xử lý ảnh tải lỗi.
- [Flutter Video Player](https://docs.flutter.dev/cookbook/plugins/play-video): khởi tạo, hiển thị và giải phóng controller video.
