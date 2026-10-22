# Use case và quyền truy cập — VieGym

## Actor

| Actor | Mô tả | Quyền chính |
| ----- | ----- | ----------- |
| Guest (Khách) | Chưa đăng nhập | Đăng ký, đăng nhập, yêu cầu đặt lại mật khẩu. Không truy cập dữ liệu cá nhân |
| User | Tài khoản `role = USER`, trạng thái ACTIVE | Đọc danh mục bài tập/món ăn đang hoạt động; đọc/ghi dữ liệu **của chính mình** |
| Admin | Tài khoản `role = ADMIN` | Quản lý danh mục bài tập, món ăn, khóa/mở tài khoản. Không đọc nhật ký tập, thực đơn hay hội thoại AI của user qua API nghiệp vụ |
| Dịch vụ AI | Hệ thống ngoài, gọi qua `ai-service` (FastAPI) | Chỉ nhận context backend gửi; không truy cập database |

## Danh sách use case

| Mã   | Người thực hiện | Chức năng              | Điều kiện/kết quả chính                    |
| ---- | --------------- | ---------------------- | ------------------------------------------ |
| UC01 | Khách           | Đăng ký, đăng nhập     | Tạo tài khoản và bắt đầu phiên             |
| UC02 | User            | Quản lý hồ sơ sức khỏe | Lưu hồ sơ, tính chỉ số và mục tiêu         |
| UC03 | User            | Xem thư viện bài tập   | Tìm kiếm, lọc và xem hướng dẫn             |
| UC04 | User            | Tạo/chỉnh sửa giáo án  | Chọn bài, sets, reps, thời gian nghỉ       |
| UC05 | User            | Quản lý lịch tập       | Tạo, sửa, hủy, xem lịch                    |
| UC06 | User            | Ghi nhận buổi tập      | Lưu từng set và xem lịch sử                |
| UC07 | User            | Lập thực đơn           | Thêm/sửa/xóa món, tính tổng dinh dưỡng     |
| UC08 | User            | Theo dõi cân nặng      | Ghi nhận theo ngày, xem lịch sử            |
| UC09 | User            | Xem dashboard          | Tổng hợp sức khỏe, ăn uống, luyện tập      |
| UC10 | User            | Chat với AI            | Nhận phản hồi theo ngữ cảnh, lưu hội thoại |
| UC11 | User            | Đặt lại mật khẩu       | Đổi mật khẩu qua mã/liên kết hợp lệ        |
| UC12 | Admin           | Quản trị dữ liệu       | Quản lý món ăn, bài tập và tài khoản       |

## Đặc tả ba use case trọng tâm

## 1. UC06 — Ghi nhận buổi tập

| Thuộc tính                   | Nội dung                                                                                                                   |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| **Mã use case**              | UC06                                                                                                                       |
| **Tên use case**             | Ghi nhận buổi tập                                                                                                          |
| **Mục tiêu**                 | Lưu kết quả luyện tập thực tế theo từng bài, từng hiệp và cập nhật trạng thái buổi tập                                     |
| **Actor chính**              | Người dùng đã đăng nhập                                                                                                    |
| **Kích hoạt**                | Người dùng chọn một buổi trong lịch và nhấn “Bắt đầu tập”                                                                  |
| **Mức ưu tiên**              | Bắt buộc trong MVP                                                                                                         |
| **Tiền điều kiện**           | Người dùng có phiên đăng nhập hợp lệ; buổi tập thuộc người dùng và ở trạng thái SCHEDULED; buổi tập có ít nhất một bài tập |
| **Hậu điều kiện thành công** | Nhật ký và chi tiết các hiệp được lưu; lịch tập chuyển sang COMPLETED; lịch sử và dashboard phản ánh kết quả mới           |
| **Hậu điều kiện thất bại**   | Không tạo nhật ký hoàn chỉnh hoặc thay đổi trạng thái lịch nếu giao dịch lưu thất bại                                      |

### Dữ liệu đầu vào

| Dữ liệu                    | Bắt buộc | Quy tắc                                                 |
| -------------------------- | -------- | ------------------------------------------------------- |
| Mã lịch tập                | Có       | Thuộc người dùng hiện tại                               |
| Danh sách bài thực tế      | Có       | Có ít nhất một bài được ghi nhận                        |
| Thứ tự hiệp                | Có       | Số nguyên dương, không trùng trong cùng bài của nhật ký |
| Số lần lặp — reps          | Có       | Số nguyên dương                                         |
| Mức tạ — kg                | Có       | Không âm; cho phép 0 với bài không sử dụng tạ ngoài     |
| Thời điểm bắt đầu/kết thúc | Không    | Nếu có cả hai, kết thúc không trước bắt đầu             |
| Ghi chú                    | Không    | Tối đa 1.000 ký tự theo thiết kế MVP                    |

### Luồng thành công chính

| Bước | Thực hiện bởi | Hành động                                                                               |
| ---- | ------------- | --------------------------------------------------------------------------------------- |
| 1    | Người dùng    | Mở lịch tập và chọn buổi muốn thực hiện                                                 |
| 2    | Hệ thống      | Kiểm tra quyền truy cập, hiển thị bài tập cùng sets/reps dự kiến                        |
| 3    | Người dùng    | Nhấn “Bắt đầu tập”                                                                      |
| 4    | Hệ thống      | Hiển thị biểu mẫu ghi nhận kết quả                                                      |
| 5    | Người dùng    | Nhập reps và mức tạ thực tế cho từng hiệp; thêm ghi chú nếu cần                         |
| 6    | Người dùng    | Nhấn “Hoàn thành buổi tập”                                                              |
| 7    | Hệ thống      | Kiểm tra phiên đăng nhập, quyền sở hữu, trạng thái lịch và tính hợp lệ của dữ liệu      |
| 8    | Hệ thống      | Trong cùng một giao dịch, lưu nhật ký, bài tập, từng hiệp và chuyển lịch sang COMPLETED |
| 9    | Hệ thống      | Thông báo lưu thành công và hiển thị kết quả buổi tập                                   |
| 10   | Hệ thống      | Cập nhật lịch sử và số liệu luyện tập trên dashboard                                    |

### Luồng thay thế và ngoại lệ

| Mã  | Tình huống                                         | Xử lý                                                              |
| --- | -------------------------------------------------- | ------------------------------------------------------------------ |
| A1  | Người dùng thực hiện ít hiệp hơn dự kiến           | Cho phép lưu các hiệp thực tế; không bắt buộc đạt toàn bộ kế hoạch |
| A2  | Người dùng bỏ qua một bài                          | Cho phép hoàn thành nếu vẫn có ít nhất một bài với một hiệp hợp lệ |
| A3  | Thiếu reps hoặc nhập số âm                         | Đánh dấu trường sai và yêu cầu sửa; chưa gửi/lưu kết quả           |
| A4  | Không có hiệp hợp lệ nào                           | Từ chối hoàn thành và thông báo cần ghi ít nhất một hiệp           |
| A5  | Buổi tập không tồn tại hoặc không thuộc người dùng | Từ chối truy cập; không trả dữ liệu buổi tập                       |
| A6  | Buổi tập đã hủy                                    | Từ chối ghi nhận theo lịch này                                     |
| A7  | Lịch đã có nhật ký hoàn thành                      | Không tạo trùng; thông báo và cho mở nhật ký hiện có               |
| A8  | Mất mạng hoặc server lỗi                           | Giữ dữ liệu đang nhập trong màn hình, thông báo lỗi và cho thử lại |
| A9  | Phiên đăng nhập hết hạn                            | Thử làm mới phiên; nếu không thành công, yêu cầu đăng nhập lại     |
| A10 | Người dùng thoát khi có dữ liệu chưa lưu           | Hiển thị xác nhận tiếp tục nhập hoặc bỏ dữ liệu                    |

### Quy tắc nghiệp vụ

- **WO-BR01:** Backend xác định người dùng từ phiên đăng nhập và kiểm tra quyền sở hữu lịch tập.
- **WO-BR02:** Trong MVP, một lịch tập có tối đa một nhật ký hoàn thành.
- **WO-BR03:** Lưu nhật ký và cập nhật trạng thái lịch phải nằm trong cùng một giao dịch.
- **WO-BR04:** Dữ liệu thực tế được lưu độc lập; sửa giáo án sau này không làm thay đổi nhật ký cũ.
- **WO-BR05:** Gửi lặp yêu cầu hoàn thành không được tạo thêm nhật ký.
- **WO-BR06:** Phạm vi use case này là ghi nhận buổi tập từ lịch; tập tự do không gắn lịch là hướng mở rộng.

### Dữ liệu được lưu

`workout_logs`, `workout_log_exercises`, `workout_set_logs` và trạng thái trong `workout_schedules`.

### Tiêu chí nghiệm thu

- [ ] Ghi được nhiều bài, mỗi bài có nhiều hiệp với reps và mức tạ khác nhau.
- [ ] Cho phép kết quả thực tế khác kế hoạch.
- [ ] Dữ liệu không hợp lệ không được lưu.
- [ ] Sau khi thành công, lịch chuyển sang COMPLETED và mở lại được nhật ký.
- [ ] Nhấn lưu hoặc gửi yêu cầu nhiều lần không tạo trùng.
- [ ] User A không xem hoặc ghi nhật ký vào lịch của User B.
- [ ] Lỗi trong quá trình lưu không để lại dữ liệu hoàn thành một phần.

---

## 2. UC07 — Lập thực đơn trong ngày

| Thuộc tính                   | Nội dung                                                                                  |
| ---------------------------- | ----------------------------------------------------------------------------------------- |
| **Mã use case**              | UC07                                                                                      |
| **Tên use case**             | Lập thực đơn trong ngày                                                                   |
| **Mục tiêu**                 | Ghi nhận món ăn theo từng bữa, tính tổng calories/macro và so sánh với mục tiêu           |
| **Actor chính**              | Người dùng đã đăng nhập                                                                   |
| **Kích hoạt**                | Người dùng mở Meal Planner và chọn ngày                                                   |
| **Mức ưu tiên**              | Bắt buộc trong MVP                                                                        |
| **Tiền điều kiện**           | Người dùng có phiên đăng nhập hợp lệ và đã hoàn thiện hồ sơ sức khỏe, mục tiêu dinh dưỡng |
| **Hậu điều kiện thành công** | Thực đơn được cập nhật; tổng dinh dưỡng và dashboard phản ánh dữ liệu mới                 |
| **Hậu điều kiện thất bại**   | Thực đơn giữ nguyên nếu thao tác thêm/sửa/xóa thất bại                                    |

### Dữ liệu đầu vào

| Dữ liệu       | Bắt buộc       | Quy tắc                                               |
| ------------- | -------------- | ----------------------------------------------------- |
| Ngày thực đơn | Có             | Ngày hợp lệ, mặc định hôm nay theo múi giờ người dùng |
| Loại bữa      | Có             | BREAKFAST, LUNCH, DINNER hoặc SNACK                   |
| Mã món ăn     | Có khi thêm    | Món tồn tại và đang hoạt động                         |
| Số khẩu phần  | Có             | Lớn hơn 0; cho phép số thập phân                      |
| Mã mục món ăn | Có khi sửa/xóa | Thuộc thực đơn của người dùng hiện tại                |

### Luồng thành công chính — Thêm món

| Bước | Thực hiện bởi | Hành động                                                                               |
| ---- | ------------- | --------------------------------------------------------------------------------------- |
| 1    | Người dùng    | Mở Meal Planner và chọn ngày                                                            |
| 2    | Hệ thống      | Hiển thị các bữa, món đã có, tổng dinh dưỡng và mục tiêu                                |
| 3    | Người dùng    | Chọn bữa và nhấn “Thêm món”                                                             |
| 4    | Hệ thống      | Hiển thị chức năng tìm kiếm món ăn                                                      |
| 5    | Người dùng    | Nhập từ khóa và chọn một món                                                            |
| 6    | Hệ thống      | Hiển thị khẩu phần chuẩn và dinh dưỡng trên mỗi khẩu phần                               |
| 7    | Người dùng    | Nhập số khẩu phần và xác nhận                                                           |
| 8    | Hệ thống      | Kiểm tra dữ liệu, quyền truy cập và trạng thái món                                      |
| 9    | Hệ thống      | Tạo thực đơn của ngày nếu chưa có; lưu món cùng thông tin dinh dưỡng tại thời điểm thêm |
| 10   | Hệ thống      | Tính lại tổng calories, protein, carbohydrate và fat                                    |
| 11   | Hệ thống      | Hiển thị thực đơn mới và cập nhật dashboard của ngày tương ứng                          |

### Luồng thay thế và ngoại lệ

| Mã  | Tình huống                                | Xử lý                                                                         |
| --- | ----------------------------------------- | ----------------------------------------------------------------------------- |
| A1  | Chưa có thực đơn trong ngày               | Hiển thị các bữa rỗng và tổng đã ghi nhận bằng 0                              |
| A2  | Không tìm thấy món                        | Hiển thị trạng thái không có kết quả; cho đổi từ khóa                         |
| A3  | Khẩu phần bằng 0, âm hoặc sai định dạng   | Từ chối thao tác và yêu cầu nhập lại                                          |
| A4  | Món đã bị ẩn trước khi xác nhận           | Từ chối thêm mới, yêu cầu chọn món khác                                       |
| A5  | Người dùng sửa khẩu phần                  | Kiểm tra quyền, cập nhật số khẩu phần và tính lại tổng theo dinh dưỡng đã lưu |
| A6  | Người dùng xóa món                        | Xác nhận xóa; xóa mục món và tính lại tổng                                    |
| A7  | Tổng calories vượt mục tiêu               | Vẫn lưu; hiển thị lượng vượt so với mục tiêu                                  |
| A8  | Hồ sơ/mục tiêu dinh dưỡng chưa hoàn chỉnh | Hướng dẫn hoàn thiện hồ sơ trước khi sử dụng đầy đủ chức năng                 |
| A9  | Mục món không thuộc người dùng            | Từ chối đọc/sửa/xóa                                                           |
| A10 | Mất mạng hoặc lưu thất bại                | Thông báo lỗi; giữ lựa chọn để thử lại; không hiển thị là đã lưu              |
| A11 | Người dùng đổi ngày                       | Tải và hiển thị đúng thực đơn của ngày mới                                    |

### Quy tắc nghiệp vụ

- **NUT-BR01:** Mỗi người dùng có tối đa một thực đơn cho một ngày.
- **NUT-BR02:** Dinh dưỡng một mục món bằng dinh dưỡng một khẩu phần đã lưu nhân với số khẩu phần.
- **NUT-BR03:** Tổng dinh dưỡng ngày bằng tổng các mục món thuộc ngày đó.
- **NUT-BR04:** Backend tính số liệu; không tin giá trị calories/macro do app tự gửi.
- **NUT-BR05:** Lưu bản chụp tên món, khẩu phần chuẩn và dinh dưỡng khi thêm món. Admin sửa món không làm thay đổi lịch sử.
- **NUT-BR06:** Món bị ẩn vẫn được hiển thị trong lịch sử đã ghi nhận.
- **NUT-BR07:** Tổng được tính với độ chính xác lưu trữ; chỉ làm tròn khi hiển thị.
- **NUT-BR08:** Mỗi lần thêm tạo một mục riêng; cùng món có thể xuất hiện nhiều lần. Giao diện chặn gửi lặp khi đang xử lý.
- **NUT-BR09:** Trong MVP, chỉ so sánh với mục tiêu hiện tại và ghi rõ điều này; so sánh theo lịch sử thay đổi mục tiêu là hướng mở rộng.

### Dữ liệu được lưu

`meal_plans` và `meal_entries`. Dữ liệu nguồn lấy từ `foods`; mục tiêu lấy từ `nutrition_targets`.

### Tiêu chí nghiệm thu

- [ ] Thêm món được vào cả bốn loại bữa.
- [ ] Hỗ trợ khẩu phần lẻ, ví dụ 0,5 hoặc 1,5.
- [ ] Sửa/xóa món cập nhật đúng tổng dinh dưỡng.
- [ ] Các ngày và tài khoản không bị trộn dữ liệu.
- [ ] Sửa thông tin món trong danh mục không làm thay đổi thực đơn đã lưu.
- [ ] Vượt mục tiêu vẫn lưu được và có thông báo rõ ràng.
- [ ] Dashboard cập nhật đúng sau thao tác thành công.

---

## 3. UC10 — Chat với AI Coach

| Thuộc tính                   | Nội dung                                                                                                       |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------- |
| **Mã use case**              | UC10                                                                                                           |
| **Tên use case**             | Chat với AI Coach                                                                                              |
| **Mục tiêu**                 | Cung cấp phản hồi tiếng Việt về luyện tập và dinh dưỡng dựa trên ngữ cảnh được phép của người dùng             |
| **Actor chính**              | Người dùng đã đăng nhập                                                                                        |
| **Actor hỗ trợ**             | Dịch vụ AI bên ngoài                                                                                           |
| **Kích hoạt**                | Người dùng nhập câu hỏi và nhấn “Gửi”                                                                          |
| **Mức ưu tiên**              | Bắt buộc trong MVP của đề tài                                                                                  |
| **Tiền điều kiện**           | Phiên đăng nhập hợp lệ; hội thoại được chọn thuộc người dùng hoặc người dùng tạo hội thoại mới                 |
| **Hậu điều kiện thành công** | Câu hỏi và phản hồi được lưu, hiển thị trong đúng hội thoại                                                    |
| **Hậu điều kiện thất bại**   | Câu hỏi đã được backend tiếp nhận vẫn được giữ cùng trạng thái lỗi; không tạo phản hồi giả như kết quả AI thật |

### Dữ liệu đầu vào

| Dữ liệu          | Bắt buộc          | Quy tắc                                                                    |
| ---------------- | ----------------- | -------------------------------------------------------------------------- |
| Nội dung câu hỏi | Có                | Không rỗng sau khi loại khoảng trắng; tối đa 2.000 ký tự theo thiết kế MVP |
| Mã hội thoại     | Không khi tạo mới | Nếu cung cấp, phải thuộc người dùng                                        |
| Mã yêu cầu       | Có                | Dùng nhận diện yêu cầu gửi lặp và thử lại                                  |

### Ngữ cảnh backend được phép cung cấp

- Mục tiêu và hồ sơ sức khỏe cần thiết.
- Các chỉ số và mục tiêu dinh dưỡng đã tính.
- Lịch tập, kết quả tập gần đây có liên quan.
- Thực đơn và tổng dinh dưỡng ngày hiện tại.
- Một phần lịch sử hội thoại trong giới hạn cấu hình.

Không đưa mật khẩu, token, API key hoặc dữ liệu tài khoản khác vào ngữ cảnh.

### Luồng thành công chính

| Bước | Thực hiện bởi | Hành động                                                                 |
| ---- | ------------- | ------------------------------------------------------------------------- |
| 1    | Người dùng    | Mở AI Coach, chọn hội thoại hoặc tạo mới                                  |
| 2    | Hệ thống      | Hiển thị lịch sử hội thoại được phép truy cập                             |
| 3    | Người dùng    | Nhập câu hỏi và nhấn “Gửi”                                                |
| 4    | Hệ thống      | Kiểm tra xác thực, quyền hội thoại, nội dung và giới hạn tần suất         |
| 5    | Hệ thống      | Lưu câu hỏi, đánh dấu yêu cầu đang xử lý                                  |
| 6    | Backend       | Lấy ngữ cảnh của người dùng từ dữ liệu server và giới hạn nội dung gửi đi |
| 7    | Backend       | Gửi yêu cầu qua FastAPI tới nhà cung cấp AI                               |
| 8    | Dịch vụ AI    | Sinh phản hồi theo câu hỏi, ngữ cảnh và hướng dẫn của hệ thống            |
| 9    | Hệ thống      | Kiểm tra phản hồi, lưu tin nhắn AI và đánh dấu yêu cầu thành công         |
| 10   | Hệ thống      | Hiển thị phản hồi và cho phép người dùng tiếp tục hội thoại               |

### Luồng thay thế và ngoại lệ

| Mã  | Tình huống                                        | Xử lý                                                                                 |
| --- | ------------------------------------------------- | ------------------------------------------------------------------------------------- |
| A1  | Câu hỏi rỗng hoặc quá dài                         | Không gửi tới AI; yêu cầu sửa nội dung                                                |
| A2  | Chưa có hồ sơ sức khỏe                            | Cho phép hỏi kiến thức chung; thông báo thiếu dữ liệu để cá nhân hóa                  |
| A3  | Không có thực đơn/lịch tập                        | Không suy diễn dữ liệu; đề nghị người dùng bổ sung khi cần                            |
| A4  | Hội thoại không tồn tại hoặc thuộc tài khoản khác | Từ chối truy cập                                                                      |
| A5  | Vượt giới hạn tần suất                            | Thông báo chờ và thử lại; không gọi thêm dịch vụ AI                                   |
| A6  | AI timeout, mất kết nối hoặc dịch vụ lỗi          | Đánh dấu thất bại, giữ câu hỏi và cho thử lại                                         |
| A7  | Mất mạng trước khi backend tiếp nhận              | Giữ nội dung trên màn hình và thông báo chưa gửi                                      |
| A8  | AI trả nội dung rỗng hoặc phản hồi không hợp lệ   | Không hiển thị là thành công; cho thử lại                                             |
| A9  | Câu hỏi liên quan bệnh lý/chấn thương             | Phản hồi thận trọng, nêu giới hạn và hướng người dùng tới chuyên gia theo quy tắc SRS |
| A10 | Người dùng yêu cầu đổi lịch/thực đơn              | AI đưa gợi ý; không tự ghi thay đổi vào dữ liệu nghiệp vụ                             |
| A11 | Người dùng gửi lại cùng mã yêu cầu                | Trả trạng thái/kết quả hiện có; không tạo thêm bản sao câu hỏi                        |
| A12 | Hội thoại dài                                     | Chỉ gửi phần lịch sử phù hợp trong giới hạn; lịch sử lưu trên hệ thống không bị xóa   |

### Quy tắc nghiệp vụ

- **AI-BR01:** App chỉ gọi backend; backend kiểm soát context và giao tiếp với AI service.
- **AI-BR02:** API key chỉ được lưu và sử dụng ở server.
- **AI-BR03:** Người dùng chỉ xem được hội thoại của mình.
- **AI-BR04:** Phản hồi mặc định bằng tiếng Việt, phù hợp người mới tập.
- **AI-BR05:** AI không thay thế tư vấn y tế chuyên môn và không cam kết kết quả luyện tập.
- **AI-BR06:** Context phải lấy từ dữ liệu server của đúng tài khoản, không lấy theo `userId` do app tùy ý cung cấp.
- **AI-BR07:** Nội dung người dùng không được ghi đè quy tắc hệ thống hoặc cho phép truy cập dữ liệu ngoài quyền hạn.
- **AI-BR08:** Có giới hạn độ dài, lịch sử, token, thời gian chờ và tần suất gọi.
- **AI-BR09:** Trong MVP, AI chỉ tư vấn; các thay đổi nghiệp vụ phải do người dùng thực hiện qua chức năng tương ứng.
- **AI-BR10:** Phản hồi mẫu phục vụ demo, nếu sử dụng, phải được ghi rõ; không trình bày như phản hồi trực tiếp từ AI.
- **AI-BR11:** Trạng thái yêu cầu gồm PROCESSING, SUCCEEDED và FAILED; lưu mã lỗi nội bộ phục vụ kiểm tra nhưng hiển thị thông báo dễ hiểu.

### Dữ liệu được lưu

`ai_conversations`, `ai_messages` và thông tin xử lý yêu cầu: mã yêu cầu, trạng thái, thời điểm, mã lỗi nếu có. Vị trí lưu thông tin yêu cầu được chốt trong thiết kế database.

### Tiêu chí nghiệm thu

- [ ] Câu hỏi và phản hồi được lưu trong đúng hội thoại.
- [ ] Mở lại app vẫn đọc được lịch sử.
- [ ] Câu trả lời sử dụng đúng dữ liệu tài khoản hiện tại khi có liên quan.
- [ ] Thiếu dữ liệu thì AI không khẳng định người dùng có dữ liệu đó.
- [ ] Có phản hồi tiếng Việt và xử lý phù hợp câu hỏi về bệnh lý/chấn thương.
- [ ] Timeout/lỗi AI không làm mất câu hỏi đã tiếp nhận hoặc treo ứng dụng.
- [ ] Gửi lặp không tạo bản sao câu hỏi.
- [ ] User A không truy cập được hội thoại của User B.
- [ ] API key và dữ liệu nhạy cảm không xuất hiện trong app hoặc phản hồi.
- [ ] AI không tự sửa giáo án hay thực đơn.
