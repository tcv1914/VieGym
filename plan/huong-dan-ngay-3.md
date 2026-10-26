# VieGym — Ngày 3: Wireframe và bộ khung hệ thống

**Mục tiêu:** Có thiết kế màn hình cơ bản, Flutter gọi được Spring Boot, Spring Boot đọc/ghi PostgreSQL qua migration và FastAPI chạy được độc lập.

**Thời lượng:** khoảng 6–8 giờ. Nếu phải xử lý nhiều lỗi môi trường, ưu tiên kết nối trước và ghi rõ phần chưa xong.

Đây là hướng dẫn để bạn thực hiện, không phải xác nhận mã nguồn đã được tạo hoặc kiểm thử trên máy. Không đánh dấu hoàn thành chỉ vì đã chép code.

## 0. Chuẩn bị và rà đầu vào ngày 2 — 30 phút

Mở đúng thư mục VieGym đã làm ngày 1. Các đường dẫn bên dưới đều tính từ thư mục gốc này. Nếu code ở nơi khác với thư mục chat đang mở, dùng đường dẫn thực tế của bạn.

- [ ] Có phạm vi MVP và kịch bản demo.
- [ ] Có use case, ERD, quy tắc nghiệp vụ và hợp đồng API.
- [ ] Chốt đơn vị, quyền sở hữu và quy tắc tính toán quan trọng.
- [ ] Flutter chạy được trên Android.
- [ ] Docker Desktop đang chạy và PostgreSQL nhận kết nối.
- [ ] Lưu lại thay đổi hiện có bằng Git sau khi kiểm tra secret.

Nếu thiếu ERD/API, dành phần đầu ngày để chốt ít nhất Auth, Health, Workout, Meal và AI. Bộ khung dưới đây chỉ tạo một bảng kỹ thuật kiểm tra kết nối, chưa thay thế thiết kế database nghiệp vụ.

## 1. Vẽ wireframe — 60 phút

Dùng Figma hoặc vẽ tay. Chỉ cần bố cục, trường dữ liệu, nút và điều hướng. Chưa dành thời gian cho màu sắc, animation hoặc logo.

| Màn hình | Thành phần cần có |
|---|---|
| Đăng nhập/đăng ký | Email, mật khẩu, lỗi nhập liệu, loading, nút gửi |
| Hồ sơ sức khỏe | Ngày sinh, dữ liệu cần cho công thức, chiều cao, cân nặng, vận động, mục tiêu |
| Dashboard | Kcal, macro, lịch hôm nay, cân nặng, điều hướng |
| Thư viện bài tập | Tìm kiếm, bộ lọc, danh sách, chi tiết |
| Giáo án và lịch | Danh sách buổi, bài trong buổi, sets/reps, chọn ngày |
| Ghi buổi tập | Các set, reps, tạ, nút hoàn thành |
| Meal Planner | Ngày, bữa, món, khẩu phần, tổng dinh dưỡng |
| AI Coach | Tin nhắn, ô nhập, đang trả lời, lỗi và thử lại |
| Profile | Thông tin cá nhân, cân nặng, đăng xuất |

Điều hướng đề xuất: **Trang chủ / Luyện tập / Dinh dưỡng / AI / Cá nhân**.

Với mỗi màn, ghi 4 trạng thái: đang tải, có dữ liệu, chưa có dữ liệu, có lỗi. Ghi nút nào dẫn tới màn nào và API liên quan theo tài liệu ngày 2.

- [ ] Có wireframe các màn core.
- [ ] Có luồng đăng nhập → hồ sơ → dashboard.
- [ ] Có luồng ghi buổi tập và thêm món.
- [ ] Có trạng thái lỗi, rỗng và loading.
- [ ] Xuất ảnh hoặc lưu đường dẫn thiết kế vào `docs/07-ui-wireframes.md`.

## 2. Khởi tạo Spring Boot — 45 phút

Mở [Spring Initializr](https://start.spring.io/). Chọn:

| Thuộc tính | Giá trị |
|---|---|
| Project | Maven |
| Language | Java |
| Spring Boot | Bản phát hành ổn định, không SNAPSHOT/Milestone; giữ nguyên phiên bản đã dùng nếu dự án đã khởi tạo |
| Group | `com.viegym` |
| Artifact | `backend` |
| Package name | `com.viegym.backend` |
| Packaging | Jar |
| Java | 21, nếu JDK 21 đã sẵn sàng |

Nếu JDK đang dùng khác, kiểm tra yêu cầu phiên bản Spring Boot trước khi chọn. Không thay JDK hoặc phiên bản framework giữa chừng mà chưa kiểm tra tương thích.

Thêm dependencies qua Initializr để lấy cấu hình tương thích:

- Spring Web.
- Validation.
- Spring Data JPA.
- PostgreSQL Driver.
- Flyway Migration.

Giải nén để `backend/pom.xml` nằm đúng vị trí, tránh `backend/backend/pom.xml`.

Spring Security/JWT triển khai ngày 4. Hôm nay chỉ có endpoint kiểm tra kỹ thuật, chưa tạo endpoint chứa dữ liệu cá nhân và chưa đưa backend ra Internet.

Cấu trúc dự kiến, tạo dần khi có code:

```text
backend/src/main/java/com/viegym/backend/
├── BackendApplication.java
├── common/
│   ├── config/
│   └── exception/
├── system/
├── auth/
├── health/
├── workout/
├── nutrition/
└── ai/
```

Để class ứng dụng ở package gốc để Spring quét được các module con. Giữ nguyên tên class ứng dụng mà Initializr đã tạo.

- [ ] `pom.xml` và Maven Wrapper có trong backend.
- [ ] Dependencies do Initializr quản lý phiên bản.
- [ ] IDE nhận diện JDK đúng.

## 3. Cấu hình PostgreSQL và migration — 60 phút

Từ thư mục gốc, dùng cấu hình Docker của ngày 1:

```powershell
docker compose --env-file infra/.env -f infra/compose.yaml up -d
docker compose --env-file infra/.env -f infra/compose.yaml exec postgres pg_isready -U viegym -d viegym
```

Trong `backend/src/main/resources/application.yaml`:

```yaml
spring:
  application:
    name: viegym-backend
  datasource:
    url: ${DB_URL:jdbc:postgresql://localhost:5432/viegym}
    username: ${DB_USER:viegym}
    password: ${DB_PASSWORD}
  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false
  flyway:
    enabled: true

server:
  port: 8080
  address: 127.0.0.1
```

Nếu có `application.properties` chứa cấu hình trùng, hợp nhất vào một nơi để tránh khó xác định giá trị đang dùng. Với cấu hình trên, Hibernate không tự tạo/sửa bảng; Flyway quản lý schema.

Tạo `backend/src/main/resources/db/migration/V1__create_system_probe.sql`:

```sql
CREATE TABLE system_probe (
    id INTEGER PRIMARY KEY,
    message VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO system_probe (id, message)
VALUES (1, 'VieGym database connected');
```

Đây là bảng kỹ thuật chỉ để chứng minh migration ghi dữ liệu và backend đọc lại được. Chưa tạo bảng nghiệp vụ nếu ERD chưa chốt. Sau khi migration đã chạy, không sửa nội dung V1; thay đổi tiếp theo dùng V2, V3...

Trong terminal dùng chạy backend, đặt biến môi trường:

```powershell
$env:DB_URL = 'jdbc:postgresql://localhost:5432/viegym'
$env:DB_USER = 'viegym'
$dbCredential = Get-Credential -UserName 'viegym' -Message 'Nhập mật khẩu PostgreSQL local đã đặt ngày 1'
$env:DB_PASSWORD = $dbCredential.GetNetworkCredential().Password
```

Nếu PostgreSQL được map cổng 5433, thay cổng trong DB_URL. Spring Boot không tự đọc `infra/.env`; mật khẩu ở đây phải khớp mật khẩu database. Không lưu mật khẩu vào YAML hoặc commit vào Git.

Nếu báo thiếu hỗ trợ Flyway/PostgreSQL, kiểm tra dependencies Initializr đã sinh và tài liệu cho đúng phiên bản Boot, bao gồm module `flyway-database-postgresql` khi được yêu cầu. Không thêm version ngẫu nhiên để thử.

- [ ] Database nhận kết nối.
- [ ] Cấu hình dùng biến môi trường.
- [ ] Có migration V1.
- [ ] Không dùng `ddl-auto: update/create` song song với Flyway.

## 4. Tạo endpoint kiểm tra backend và database — 45 phút

Tạo `backend/src/main/java/com/viegym/backend/system/SystemHealthController.java`:

```java
package com.viegym.backend.system;

import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/system")
public class SystemHealthController {
    private final JdbcTemplate jdbcTemplate;

    public SystemHealthController(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        String message = jdbcTemplate.queryForObject(
            "SELECT message FROM system_probe WHERE id = 1",
            String.class
        );
        return Map.of(
            "status", "UP",
            "service", "viegym-backend",
            "database", "UP",
            "message", message
        );
    }
}
```

JdbcTemplate chỉ được dùng ở đây cho truy vấn kiểm tra tối thiểu. Từ ngày 4, nghiệp vụ dùng controller → service → repository và DTO; không đưa logic nghiệp vụ trực tiếp vào controller.

Trong cùng terminal đã đặt biến môi trường:

```powershell
cd backend
.\mvnw.cmd spring-boot:run
```

Mở terminal khác:

```powershell
Invoke-RestMethod http://localhost:8080/api/v1/system/health
```

Kết quả mong đợi:

```json
{
  "status": "UP",
  "service": "viegym-backend",
  "database": "UP",
  "message": "VieGym database connected"
}
```

Thứ tự thuộc tính JSON không quan trọng. Nếu truy vấn database lỗi, yêu cầu phải thất bại; không trả `database: UP` giả.

Xác nhận migration trong terminal tại thư mục gốc:

```powershell
docker compose --env-file infra/.env -f infra/compose.yaml exec postgres psql -U viegym -d viegym -c "SELECT version, description, success FROM flyway_schema_history;"
docker compose --env-file infra/.env -f infra/compose.yaml exec postgres psql -U viegym -d viegym -c "SELECT * FROM system_probe;"
```

- [ ] Backend khởi động thành công.
- [ ] V1 được ghi nhận thành công trong lịch sử Flyway.
- [ ] Endpoint đọc đúng bản ghi PostgreSQL.
- [ ] Khởi động lại backend không tạo trùng bản ghi.

## 5. Dựng FastAPI độc lập — 30 phút

Mở terminal mới, từ thư mục gốc vào `ai-service`. Tạo thư mục nếu chưa có:

```powershell
cd ai-service
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install "fastapi[standard]"
```

Dùng trực tiếp Python của virtual environment để không phụ thuộc quyền chạy script Activate.ps1.

Tạo `ai-service/main.py`:

```python
from fastapi import FastAPI

app = FastAPI(title="VieGym AI Service")

@app.get("/health")
def health():
    return {"status": "UP", "service": "viegym-ai"}
```

Chạy trong thư mục `ai-service`:

```powershell
.\.venv\Scripts\python.exe -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

Kiểm tra `http://localhost:8000/health` và `http://localhost:8000/docs` bằng trình duyệt. Sau khi cài thành công, tại terminal khác trong `ai-service`, lưu dependencies:

```powershell
.\.venv\Scripts\python.exe -m pip freeze | Out-File -Encoding utf8 requirements.txt
```

- [ ] Health trả `UP`.
- [ ] Trang tài liệu API mở được.
- [ ] `requirements.txt` có dependencies thực tế.
- [ ] `.venv/` đã bị Git bỏ qua.

Chưa cần chatbot, context hoặc gọi provider hôm nay. FastAPI chỉ lắng nghe trên máy local; mobile sẽ gọi Spring Boot, không gọi trực tiếp dịch vụ AI.

## 6. Tạo Flutter skeleton và màn kiểm tra kết nối — 90 phút

Nếu `mobile/pubspec.yaml` đã có từ ngày 1 thì giữ nguyên project, không tạo lại. Sao lưu/commit code hiện có trước khi thay main.dart; nếu đã có giao diện thì tích hợp màn kiểm tra vào ứng dụng hiện tại.

Từ thư mục gốc:

```powershell
cd mobile
flutter pub add http flutter_riverpod
```

Cấu trúc mục tiêu, tạo dần khi có file:

```text
lib/
├── main.dart
├── app/
├── core/
│   ├── config/
│   ├── network/
│   └── widgets/
└── features/
    ├── system/
    ├── auth/
    ├── health/
    ├── dashboard/
    ├── workout/
    ├── nutrition/
    └── ai/
```

Đầu tiên dùng màn kiểm tra tối thiểu trong `lib/main.dart`:

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

final connectionProvider = FutureProvider<String>((ref) async {
  final client = http.Client();
  ref.onDispose(client.close);
  final response = await client
      .get(Uri.parse('$apiBaseUrl/api/v1/system/health'))
      .timeout(const Duration(seconds: 10));
  if (response.statusCode != 200) {
    throw Exception('Backend trả mã ${response.statusCode}');
  }
  final body = jsonDecode(utf8.decode(response.bodyBytes))
      as Map<String, dynamic>;
  if (body['status'] != 'UP' || body['database'] != 'UP') {
    throw Exception('Backend hoặc database chưa sẵn sàng');
  }
  return body['message'] as String;
});

void main() => runApp(const ProviderScope(child: VieGymApp()));

class VieGymApp extends StatelessWidget {
  const VieGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VieGym',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const ConnectionPage(),
    );
  }
}

class ConnectionPage extends ConsumerWidget {
  const ConnectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(connectionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('VieGym — Kiểm tra kết nối')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: result.when(
            loading: () => const CircularProgressIndicator(),
            data: (message) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const Text('Kết nối backend và database thành công'),
                Text(message),
                TextButton(
                  onPressed: () => ref.invalidate(connectionProvider),
                  child: const Text('Kiểm tra lại'),
                ),
              ],
            ),
            error: (error, stack) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Chưa kết nối được. Kiểm tra server và địa chỉ API.'),
                TextButton(
                  onPressed: () => ref.invalidate(connectionProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

Sau khi kết nối thành công, tách cấu hình URL vào `core/config`, lớp gọi API vào `core/network` và màn/provider vào `features/system`. Main chỉ khởi động ProviderScope và app. Không xây toàn bộ kiến trúc tầng phức tạp cho các module còn trống.

### Cấu hình Android và cách kết nối

Trong `android/app/src/main/AndroidManifest.xml`, thêm quyền trực tiếp bên trong thẻ manifest, bên ngoài application:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Để gọi HTTP local khi debug, thêm/ghép vào `android/app/src/debug/AndroidManifest.xml`, không ghi đè các nội dung cần thiết đã có:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:usesCleartextTraffic="true" />
</manifest>
```

Chỉ áp dụng debug; khi release dùng HTTPS. Không đặt cấu hình cho phép HTTP rộng vào main manifest.

Cách thử thuận tiện là Android qua USB hoặc emulator với `adb reverse`. Chạy terminal nơi lệnh adb được nhận diện:

```powershell
adb devices
adb reverse tcp:8080 tcp:8080
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

Nếu nhiều thiết bị, dùng `adb -s <serial> reverse tcp:8080 tcp:8080` và chọn cùng thiết bị với `flutter run -d <device-id> ...`. Serial/device-id phải lấy từ danh sách thực tế. Nếu adb chưa được nhận diện, dùng executable trong Android SDK platform-tools theo đường dẫn SDK của Android Studio. Chạy lại reverse khi thiết bị kết nối lại.

Nếu chọn mạng LAN thay cho USB: dùng IPv4 thực tế của máy tính, điện thoại cùng mạng, đổi backend bind address phù hợp và chỉ cho phép kết nối trong mạng phát triển tin cậy. `localhost` trên điện thoại không tự trỏ về máy tính. Hôm nay ưu tiên USB để giữ backend trên loopback và tránh cấu hình firewall chưa cần thiết.

- [ ] App có loading, thành công và lỗi.
- [ ] Có nút thử lại.
- [ ] URL được truyền bằng dart-define.
- [ ] Android có quyền Internet.
- [ ] Cấu hình HTTP local chỉ ở debug.
- [ ] App hiển thị thông điệp đọc từ database.
- [ ] Tách màn kiểm tra và cấu hình khỏi main sau khi xác minh.

## 7. Kiểm tra tích hợp và bằng chứng — 30 phút

Thực hiện từng tình huống:

| Tình huống | Kết quả mong đợi |
|---|---|
| PostgreSQL + backend chạy | App báo thành công, hiện message của database |
| Dừng backend bằng Ctrl+C | App báo lỗi trong thời gian timeout, không loading vô hạn |
| Chạy lại backend và bấm thử lại | App kết nối thành công |
| Dừng PostgreSQL trên môi trường local | Request không báo database UP giả |
| Chạy lại PostgreSQL/backend nếu cần | Kết nối khôi phục |
| Khởi động lại backend | Flyway không tạo lại V1 hoặc thêm bản ghi trùng |
| Gọi FastAPI health | Dịch vụ AI trả UP độc lập |

Chỉ dừng container local bạn đang dùng để kiểm tra, không xóa volume. Ghi kết quả thực tế vào `docs/08-day-3-verification.md`, kèm ảnh màn hình và lỗi còn tồn tại. Không cần tạo endpoint ghi dữ liệu công khai chỉ để thử; migration đã là bước ghi kiểm tra.

Chạy kiểm tra Flutter sau khi tách file:

```powershell
flutter analyze
```

Nếu giữ widget test mặc định của app counter, cập nhật hoặc bỏ test mẫu không còn phù hợp sau khi đổi main; không coi lỗi của test mẫu là lỗi nghiệp vụ. Chưa cần viết bộ test diện rộng cho màn kiểm tra kỹ thuật.

## 8. Lỗi thường gặp

| Lỗi | Kiểm tra |
|---|---|
| Connection refused | Backend có chạy, URL/cổng đúng, adb reverse còn hiệu lực |
| HTTP cleartext blocked | Manifest debug đã ghép đúng; rebuild app sau khi đổi manifest |
| Password authentication failed | DB_PASSWORD phải khớp mật khẩu thực tế của database |
| Đổi .env nhưng mật khẩu DB không đổi | Volume đã khởi tạo giữ mật khẩu cũ; không xóa volume có dữ liệu để sửa nhanh |
| Flyway checksum mismatch | Đã sửa migration từng chạy; khôi phục bản cũ và thêm migration mới |
| Port 8080/8000 in use | Có tiến trình cũ; dừng đúng tiến trình hoặc đổi cổng và cập nhật client |
| 401 ngoài dự kiến | Có thể đã thêm Security; chỉ mở endpoint health cần thiết, không permitAll toàn bộ nghiệp vụ |
| Không tìm thấy mvnw.cmd | Terminal chưa ở backend hoặc giải nén lồng thư mục |
| Lỗi import Java | Package phải khớp thư mục và class nằm dưới package gốc |
| pip cài nhầm Python | Dùng đường dẫn .venv/Scripts/python.exe như hướng dẫn |

Flutter Android native không cần mở CORS để gọi REST API. Nếu sau này React admin chạy trên trình duyệt, cấu hình CORS riêng cho origin của admin; không mở mọi origin để chữa lỗi kết nối mobile.

## 9. Checklist đóng ngày 3 — 15 phút

- [ ] Wireframe các màn core đã lưu.
- [ ] Bộ khung Spring Boot khởi động được.
- [ ] Cấu hình database dùng biến môi trường.
- [ ] Flyway V1 ghi dữ liệu kiểm tra thành công.
- [ ] Backend đọc được dữ liệu qua endpoint health.
- [ ] FastAPI health/docs hoạt động.
- [ ] Flutter gọi backend trên Android thật hoặc emulator.
- [ ] Có loading/lỗi/thử lại và timeout.
- [ ] Kiểm tra dừng/chạy lại backend thành công.
- [ ] Kết quả, ảnh chụp và giới hạn được ghi vào tài liệu.
- [ ] Không có mật khẩu, API key hoặc .venv trong commit.

Tại thư mục gốc, kiểm tra danh sách và nội dung thay đổi trước khi commit:

```powershell
git status
git diff
git add .
git diff --cached --stat
git diff --cached
git commit -m "chore: bootstrap mobile backend database and AI service"
```

Nếu có file chứa secret trong staged changes, bỏ file đó khỏi staging và cập nhật .gitignore trước khi commit.

### Nhật ký cuối ngày

```text
Ngày:
Đường dẫn dự án:
Java/Spring Boot/Flutter/Python đang dùng:
Thiết bị Android:
Đã hoàn thành:
Chưa hoàn thành:
Kết quả health backend/database:
Kết quả health FastAPI:
Kết quả Flutter:
Lỗi và bằng chứng:
Việc đầu tiên ngày mai:
```

**Điều kiện chuyển sang ngày 4:** Android gọi được backend, backend đọc được PostgreSQL, migration chạy được và dự án có thể khởi động lại theo hướng dẫn. Ngày 4 mới triển khai đăng ký, đăng nhập, JWT, refresh token và logout.

## Tài liệu chính thức đối chiếu

- [Spring Initializr và khởi tạo Spring Boot](https://spring.io/guides/gs/spring-boot): tạo project và dependency theo cấu hình đã chọn.
- [Spring Boot Database Initialization](https://docs.spring.io/spring-boot/how-to/data-initialization.html): chọn một cơ chế quản lý schema và cấu hình migration tương thích phiên bản.
- [Flutter: Fetch data from the internet](https://docs.flutter.dev/cookbook/networking/fetch-data): package HTTP và quyền Internet Android.
- [Android Network Security Configuration](https://developer.android.com/privacy-and-security/security-config): cấu hình kết nối và cleartext.
- [FastAPI First Steps](https://fastapi.tiangolo.com/tutorial/first-steps/): khởi tạo ứng dụng, endpoint và tài liệu tự động.
