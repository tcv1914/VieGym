# VieGym — Ngày 1: Chốt phạm vi và chuẩn bị môi trường

Ngày 1 bạn cần chốt phạm vi, chuẩn bị công cụ và chạy được các kết nối thử. Chưa cần làm giao diện đẹp hay code chức năng nghiệp vụ.

**Thời lượng:** 6–8 giờ. Thực hiện lần lượt; công cụ đã cài thì kiểm tra và bỏ qua bước cài lại.

## Bước 1 — Tạo thư mục dự án và nơi theo dõi công việc

**Thời gian:** 30 phút.

Tạo thư mục `VieGym` ở vị trí dễ quản lý:

```text
VieGym/
├── mobile/
├── backend/
├── ai-service/
├── admin/
├── infra/
└── docs/
```

| Thư mục | Nội dung |
|---|---|
| `mobile` | Ứng dụng Flutter |
| `backend` | Spring Boot, nghiệp vụ và phân quyền |
| `ai-service` | FastAPI, kết nối chatbot AI |
| `admin` | Website quản trị |
| `infra` | Docker và cấu hình triển khai |
| `docs` | Phạm vi, thiết kế, kiểm thử và nhật ký |

Dùng GitHub Projects, Trello hoặc bảng tính, tạo bốn cột: **Chưa làm → Đang làm → Cần kiểm tra → Hoàn thành**.

Tạo các thẻ công việc:

- [ ] Chốt phạm vi MVP.
- [ ] Viết kịch bản demo.
- [ ] Kiểm tra công cụ.
- [ ] Tạo repository.
- [ ] Chạy Flutter trên Android.
- [ ] Chạy thử PostgreSQL.
- [ ] Gọi thử dịch vụ AI.
- [ ] Tổng kết ngày 1.

**Hoàn thành khi:** Có thư mục dự án và bảng theo dõi.

## Bước 2 — Viết bản chốt phạm vi MVP

**Thời gian:** 45 phút.

Tạo `docs/pham-vi-mvp.md`, ghi nội dung sau và điều chỉnh nếu giảng viên có yêu cầu riêng:

```markdown
# Phạm vi MVP VieGym

## Mục tiêu
Xây dựng ứng dụng Android hỗ trợ luyện tập và dinh dưỡng
cho người Việt, tích hợp chatbot AI theo ngữ cảnh người dùng.

## Chức năng bắt buộc
1. Đăng ký, đăng nhập, đăng xuất.
2. Hồ sơ sức khỏe.
3. Tính BMI, BMR, TDEE, calories và macro mục tiêu.
4. Thư viện bài tập.
5. Giáo án cơ bản và lịch tập theo tuần.
6. Ghi nhận buổi tập và xem lịch sử.
7. Tìm món ăn Việt Nam và lập thực đơn theo ngày.
8. Dashboard tổng hợp.
9. Chatbot AI tiếng Việt, sử dụng ngữ cảnh và lưu hội thoại.

## Chức năng hỗ trợ dự kiến
- Theo dõi cân nặng và biểu đồ đơn giản.
- Đặt lại mật khẩu.
- Admin quản lý bài tập, món ăn và người dùng.

## Chỉ làm nếu còn thời gian
- Google Login.
- Thông báo nhắc lịch.
- Lịch tháng.
- PR và biểu đồ luyện tập nâng cao.

## Ngoài phạm vi
- Nhận diện món ăn bằng ảnh.
- Phân tích tư thế bằng camera.
- Đồng bộ thiết bị sức khỏe.
- Thanh toán và marketplace.
- Tự động huấn luyện mô hình AI riêng.

## Nền tảng demo
Android.

## Tiêu chí hoàn thành
Luồng core chạy bằng dữ liệu lưu thật;
chatbot gọi dịch vụ AI thật;
có kiểm thử, APK, báo cáo và hướng dẫn chạy.
```

Đối chiếu bản này với yêu cầu giảng viên. Chức năng được yêu cầu bắt buộc phải đưa vào backlog ngay để tránh thiếu ở tuần cuối.

**Hoàn thành khi:** Chỉ ra được chức năng phải có và chức năng có thể hoãn.

## Bước 3 — Viết kịch bản demo trước khi code

**Thời gian:** 30 phút.

Tạo `docs/kich-ban-demo.md` với tình huống xuyên suốt:

| Thứ tự | Thao tác | Kết quả cần nhìn thấy |
|---|---|---|
| 1 | Đăng ký và đăng nhập | Vào được ứng dụng |
| 2 | Nhập hồ sơ sức khỏe và mục tiêu | Hiển thị chỉ số và mục tiêu dinh dưỡng |
| 3 | Chọn bài tập, tạo giáo án và lịch | Xuất hiện buổi tập trong tuần |
| 4 | Ghi sets, reps và mức tạ | Buổi tập hoàn thành, có lịch sử |
| 5 | Tìm món Việt, thêm vào bữa ăn | Tổng calories và macro thay đổi |
| 6 | Mở dashboard | Số liệu ăn uống và luyện tập được cập nhật |
| 7 | Hỏi AI về thực đơn hoặc lịch tập | AI trả lời tiếng Việt dựa trên dữ liệu đã nhập |

Ví dụ câu hỏi demo AI:

> Dựa trên mục tiêu và thực đơn hôm nay của tôi, tôi nên điều chỉnh bữa tối như thế nào?

**Hoàn thành khi:** Mô tả được sản phẩm cuối trong khoảng hai phút.

## Bước 4 — Kiểm tra môi trường phát triển

**Thời gian:** 60–120 phút.

Trên Windows, mở PowerShell hoặc terminal trong VS Code, chạy từng lệnh:

```powershell
git --version
flutter --version
flutter doctor -v
java -version
python --version
node --version
npm --version
docker --version
docker compose version
```

Nếu Python không được nhận diện:

```powershell
py --version
```

| Công cụ | Mục đích | Cách xác nhận |
|---|---|---|
| Git | Quản lý mã nguồn | Hiển thị phiên bản |
| Flutter SDK | Làm app mobile | `flutter doctor -v` kiểm tra được môi trường |
| Android Studio + Android SDK | Build và chạy Android | Có thiết bị/emulator được nhận diện |
| JDK | Chạy Spring Boot | `java -version` hoạt động |
| Python | Chạy FastAPI | Hiển thị phiên bản |
| Node.js và npm | Làm React admin | Hiển thị phiên bản |
| Docker Desktop | Chạy PostgreSQL và dịch vụ | `docker info` kết nối được Docker Engine |
| VS Code hoặc IntelliJ IDEA | Viết code | Mở được thư mục dự án |

Chưa cần cài PostgreSQL riêng nếu chạy bằng Docker. Maven có thể sử dụng Maven Wrapper khi khởi tạo Spring Boot ở ngày 3.

Với `flutter doctor`, ưu tiên xử lý lỗi thuộc Flutter, Android toolchain và Android Studio. Các mục phục vụ nền tảng khác có thể chưa cần cho bản Android.

- [ ] Git hoạt động.
- [ ] Flutter được nhận diện.
- [ ] Android SDK sẵn sàng.
- [ ] Java, Python và Node.js hoạt động.
- [ ] Docker Desktop khởi động được.
- [ ] Ghi các lỗi chưa xử lý vào nhật ký.

## Bước 5 — Tạo Git repository

**Thời gian:** 30 phút.

Mở terminal tại thư mục `VieGym`:

```powershell
git init
```

Tạo `.gitignore` ở thư mục gốc:

```gitignore
# Secrets
.env
.env.*
!.env.example
*.jks
*.keystore
key.properties

# Editors
.idea/
.vscode/
*.iml

# Flutter
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
build/

# Java
target/
.gradle/

# Python
.venv/
__pycache__/
*.py[cod]

# Node
node_modules/
dist/

# Logs and OS
*.log
.DS_Store
Thumbs.db
```

Tạo `README.md`:

```markdown
# VieGym

Ứng dụng Android hỗ trợ luyện tập và dinh dưỡng,
tích hợp chatbot AI theo ngữ cảnh người dùng.

## Công nghệ
- Flutter và Riverpod
- Spring Boot và Spring Security
- PostgreSQL
- Python FastAPI
- React và TypeScript

## Trạng thái
Ngày 1: chốt phạm vi và chuẩn bị môi trường.
```

Lưu phiên bản đầu:

```powershell
git add .
git status
git commit -m "docs: initialize VieGym scope and project structure"
```

Trước khi commit, đọc `git status` để chắc chắn không có file chứa API key hoặc mật khẩu. Git chưa theo dõi các thư mục rỗng; điều này bình thường.

Có thể tạo repository private trên GitHub rồi kết nối theo hướng dẫn hiển thị tại đó.

**Hoàn thành khi:** Có commit đầu tiên và không chứa secret.

## Bước 6 — Chạy thử Flutter trên Android

**Thời gian:** 45–60 phút.

Tại thư mục gốc `VieGym`:

```powershell
flutter create --platforms=android --org com.viegym mobile
flutter devices
```

Nếu dùng điện thoại thật:

1. Bật Developer options.
2. Bật USB debugging.
3. Kết nối cáp USB và chấp nhận yêu cầu cho phép gỡ lỗi.
4. Chạy lại `flutter devices`.

Nếu dùng emulator, mở Android Studio và khởi động thiết bị ảo.

```powershell
cd mobile
flutter run
```

- [ ] Thiết bị xuất hiện trong danh sách.
- [ ] Build thành công.
- [ ] Ứng dụng mẫu mở được.
- [ ] Thử sửa một dòng chữ và hot reload.
- [ ] Chụp ảnh để lưu bằng chứng tiến độ.

**Hoàn thành khi:** Nhìn thấy ứng dụng Flutter chạy trên Android.

## Bước 7 — Kiểm tra PostgreSQL bằng Docker

**Thời gian:** 30 phút.

Quay về thư mục gốc `VieGym`. Tạo `infra/compose.yaml`:

```yaml
services:
  postgres:
    image: postgres:17
    environment:
      POSTGRES_DB: viegym
      POSTGRES_USER: viegym
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD}
    ports:
      - "127.0.0.1:5432:5432"
    volumes:
      - viegym_pgdata:/var/lib/postgresql/data

volumes:
  viegym_pgdata:
```

Tạo `infra/.env` chứa mật khẩu riêng cho môi trường phát triển:

```dotenv
POSTGRES_PASSWORD=thay_bang_mat_khau_local_cua_ban
```

Tạo `infra/.env.example` để lưu vào Git:

```dotenv
POSTGRES_PASSWORD=
```

Chạy:

```powershell
docker compose --env-file infra/.env -f infra/compose.yaml up -d
docker compose --env-file infra/.env -f infra/compose.yaml exec postgres pg_isready -U viegym -d viegym
```

**Hoàn thành khi:** Kết quả có dòng `accepting connections`.

Nếu cổng `5432` đã được sử dụng, đổi phần bên trái thành `5433`, tức `"127.0.0.1:5433:5432"`, và ghi lại để backend dùng đúng cổng sau này.

## Bước 8 — Kiểm chứng kết nối AI

**Thời gian:** 30–60 phút.

Ngày 1 chỉ cần xác nhận server có thể gửi câu hỏi và nhận phản hồi thật; chatbot hoàn chỉnh làm ở ngày 12.

1. Chọn một nhà cung cấp AI có thể sử dụng.
2. Tạo API key trong tài khoản nhà cung cấp.
3. Lưu key trong biến môi trường hoặc `.env` đã được Git bỏ qua.
4. Dùng ví dụ gọi API tối thiểu từ tài liệu chính thức của nhà cung cấp.
5. Gửi: “Hãy giới thiệu ngắn gọn vai trò trợ lý luyện tập VieGym bằng tiếng Việt.”
6. Xác nhận nhận phản hồi thành công.

- [ ] Đã chọn nhà cung cấp.
- [ ] Tài khoản có quyền sử dụng API.
- [ ] Gọi thử thành công.
- [ ] Không đặt key trong Flutter hoặc React.
- [ ] Không đưa key vào Git, ảnh chụp hoặc nhật ký.
- [ ] Ghi tên model, thời gian phản hồi và lỗi nếu có.

Tên model, SDK và cách gọi tùy nhà cung cấp; cần cụ thể hóa theo lựa chọn thực tế.

## Bước 9 — Đóng ngày làm việc

**Thời gian:** 15 phút.

Tại thư mục gốc, kiểm tra và lưu thay đổi:

```powershell
git status
git add .
git diff --cached --stat
git commit -m "chore: verify Android and local database setup"
```

### Checklist nghiệm thu ngày 1

- [ ] Có phạm vi MVP rõ ràng.
- [ ] Có kịch bản demo.
- [ ] Có bảng theo dõi công việc.
- [ ] Có repository và commit đầu tiên.
- [ ] Flutter chạy trên Android.
- [ ] PostgreSQL nhận kết nối.
- [ ] Gọi API AI thành công.
- [ ] Có nhật ký và danh sách vướng mắc.

Nếu thiếu thời gian, ưu tiên môi trường và kết nối; dành phần còn thiếu cho đầu ngày 2.

### Mẫu nhật ký

```text
Ngày:
Đã hoàn thành:
Chưa hoàn thành:
Lỗi/vướng mắc:
Bằng chứng kiểm tra:
Việc đầu tiên ngày mai:
```

Để nhận hướng dẫn tiếp theo, chuẩn bị kết quả `flutter doctor -v`, công cụ chưa cài và nhà cung cấp AI đã chọn. Không gửi API key hoặc mật khẩu.
