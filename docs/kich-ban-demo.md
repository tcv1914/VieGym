# KỊCH BẢN DEMO ĐỒ ÁN VIEGYM

**Đề tài:** Xây dựng ứng dụng hỗ trợ luyện tập và dinh dưỡng VieGym tích hợp chatbot AI trên thiết bị di động.

**Phiên bản:** MVP Android
**Thời lượng demo:** 8–10 phút
**Mục đích:** Chứng minh người dùng có thể quản lý luyện tập, theo dõi dinh dưỡng và nhận tư vấn AI dựa trên dữ liệu cá nhân trong cùng một ứng dụng.

## 1. Tình huống sử dụng

Minh là sinh viên, mới bắt đầu tập gym và muốn tăng cơ. Minh cần một ứng dụng để lên lịch tập, ghi nhận kết quả, theo dõi lượng dinh dưỡng hằng ngày và giải đáp các câu hỏi phù hợp với mục tiêu cá nhân.

Luồng demo:

**Đăng ký → Hồ sơ sức khỏe → Giáo án và lịch tập → Ghi nhận buổi tập → Thực đơn → Dashboard → Chatbot AI.**

## 2. Dữ liệu và điều kiện chuẩn bị

### Hồ sơ minh họa

| Thông tin                          | Giá trị          |
| ---------------------------------- | ---------------- |
| Tên hiển thị                       | Minh             |
| Tuổi                               | 22               |
| Giới tính dùng trong công thức BMR | Nam              |
| Chiều cao                          | 170 cm           |
| Cân nặng                           | 65 kg            |
| Mức độ vận động                    | Vừa — hệ số 1,55 |
| Mục tiêu                           | Tăng cơ          |

Kết quả tính dự kiến:

- BMI: khoảng **22,49**.
- BMR: khoảng **1.607,5 kcal/ngày**.
- TDEE: khoảng **2.491,6 kcal/ngày**.
- Calories mục tiêu: khoảng **2.791,6 kcal/ngày**, nếu phiên bản MVP chốt mức tăng 300 kcal cho mục tiêu tăng cơ.

Các giá trị trên là dữ liệu kiểm tra phần mềm. Quy tắc tính macro và làm tròn cần được chốt ở bước thiết kế, sau đó dùng thống nhất trong backend và giao diện.

### Điều kiện trước buổi demo

- APK đã được cài trên điện thoại Android.
- Backend, database và AI service hoạt động.
- Có kết nối Internet và quyền sử dụng API AI.
- Có dữ liệu bài tập và món ăn mẫu.
- Có email chưa sử dụng để đăng ký.
- Có tài khoản dự phòng đã chuẩn bị dữ liệu.
- Có video demo dự phòng nếu xảy ra sự cố hạ tầng.

## 3. Kịch bản chi tiết

### Cảnh 1 — Giới thiệu bài toán

**Thời lượng:** 30 giây.

**Lời trình bày:**

“VieGym hỗ trợ người dùng Việt quản lý lịch tập, ghi nhận quá trình luyện tập và theo dõi dinh dưỡng từ các món ăn quen thuộc. Chatbot AI sử dụng dữ liệu được phép của người dùng để đưa ra gợi ý phù hợp với ngữ cảnh hiện tại.”

**Thao tác:** Mở ứng dụng tại màn hình đăng nhập.

**Kết quả mong đợi:** Giao diện tiếng Việt, có lựa chọn đăng nhập và đăng ký.

### Cảnh 2 — Đăng ký và đăng nhập

**Thời lượng:** 45 giây.

**Thao tác:**

1. Chọn “Đăng ký”.
2. Nhập tên Minh, email mới và mật khẩu hợp lệ.
3. Gửi yêu cầu đăng ký.
4. Đăng nhập bằng tài khoản vừa tạo.

**Kết quả mong đợi:**

- Tài khoản được tạo thành công.
- Người dùng được xác thực.
- Vì chưa có hồ sơ sức khỏe, ứng dụng hướng dẫn hoàn thiện hồ sơ.

**Tiêu chí nghiệm thu:**

- [ ] Đăng ký bằng email mới thành công.
- [ ] Không hiển thị mật khẩu hoặc token trên giao diện.
- [ ] Không vào được màn dữ liệu cá nhân khi chưa đăng nhập.
- [ ] Đăng nhập thành công dẫn đến đúng màn hình tiếp theo.

### Cảnh 3 — Hoàn thiện hồ sơ sức khỏe

**Thời lượng:** 1 phút.

**Lời trình bày:**

“Người dùng nhập thông tin cơ bản để hệ thống tính các chỉ số và mục tiêu dinh dưỡng. Những kết quả này được sử dụng thống nhất cho dashboard, thực đơn và chatbot.”

**Thao tác:**

1. Nhập hồ sơ minh họa ở mục 2.
2. Chọn mục tiêu “Tăng cơ”.
3. Nhấn “Lưu hồ sơ”.
4. Xem các chỉ số đã tính.

**Kết quả mong đợi:**

- Hồ sơ được lưu.
- BMI, BMR, TDEE và calories mục tiêu khớp quy tắc tính đã chốt.
- Hiển thị đơn vị rõ ràng.
- Mở lại hồ sơ vẫn thấy dữ liệu vừa nhập.

**Tiêu chí nghiệm thu:**

- [ ] Không chấp nhận chiều cao hoặc cân nặng bằng 0, số âm.
- [ ] Không tính khi thiếu dữ liệu bắt buộc.
- [ ] Kết quả tính khớp bộ dữ liệu kiểm thử.
- [ ] Dữ liệu được lưu vào database.

### Cảnh 4 — Chọn giáo án và tạo lịch tập

**Thời lượng:** 1 phút.

**Lời trình bày:**

“Sau khi có hồ sơ, Minh chọn giáo án phù hợp và lên lịch cho buổi tập. Mỗi bài tập có thông tin nhóm cơ, hướng dẫn và số hiệp, số lần lặp.”

**Thao tác:**

1. Mở thư viện bài tập.
2. Tìm một bài tập theo tên hoặc lọc theo nhóm cơ.
3. Xem hướng dẫn bài tập.
4. Chọn giáo án mẫu “Full Body cơ bản”.
5. Xem các bài, sets và reps.
6. Tạo một buổi tập vào ngày demo.
7. Mở lịch tuần để kiểm tra.

**Kết quả mong đợi:**

- Tìm và xem được bài tập.
- Giáo án được gắn với tài khoản.
- Buổi tập xuất hiện đúng ngày và có trạng thái “Đã lên lịch”.

**Tiêu chí nghiệm thu:**

- [ ] Tìm kiếm/lọc trả đúng bài tập.
- [ ] Thông tin giáo án được lưu.
- [ ] Lịch tập hiển thị đúng ngày đã chọn.
- [ ] Mở lại ứng dụng vẫn thấy lịch.

### Cảnh 5 — Ghi nhận buổi tập

**Thời lượng:** 1 phút.

**Thao tác:**

1. Mở buổi tập vừa tạo.
2. Chọn một bài tập trong buổi.
3. Nhập kết quả minh họa: 3 hiệp, mỗi hiệp 10 lần, mức tạ 10 kg.
4. Nhập ghi chú “Hoàn thành buổi tập đầu tiên”.
5. Nhấn “Hoàn thành”.
6. Mở lịch sử để xem lại.

**Kết quả mong đợi:**

- Chi tiết từng hiệp được lưu.
- Buổi tập chuyển sang “Đã hoàn thành”.
- Lịch sử hiển thị đúng bài tập, reps và mức tạ.
- Không tạo hai bản ghi khi người dùng nhấn nút liên tiếp.

**Tiêu chí nghiệm thu:**

- [ ] Workout log liên kết đúng với buổi tập.
- [ ] Trạng thái lịch được cập nhật.
- [ ] Dữ liệu lịch sử khớp dữ liệu đã nhập.
- [ ] Thoát màn hình và mở lại không mất dữ liệu.

### Cảnh 6 — Lập thực đơn trong ngày

**Thời lượng:** 1 phút 30 giây.

**Lời trình bày:**

“VieGym sử dụng dữ liệu món ăn Việt Nam có khẩu phần rõ ràng. Người dùng thêm món theo từng bữa và theo dõi tổng năng lượng, protein, carbohydrate và chất béo.”

**Thao tác:**

1. Mở Meal Planner của ngày demo.
2. Tìm “Phở bò”, xem dinh dưỡng và thêm một khẩu phần vào bữa sáng.
3. Thêm một món khác vào bữa trưa.
4. Quan sát tổng calories và macro.
5. Đổi khẩu phần một món từ 1 thành 1,5.
6. Xóa món vừa thêm để minh họa tính lại tổng.

**Kết quả mong đợi:**

- Món xuất hiện trong đúng bữa.
- Tổng dinh dưỡng bằng tổng giá trị từng món nhân khẩu phần.
- Đổi khẩu phần và xóa món cập nhật tổng ngay sau khi lưu.
- Có so sánh với mục tiêu cá nhân.

**Tiêu chí nghiệm thu:**

- [ ] Mỗi món có đơn vị khẩu phần và dinh dưỡng rõ ràng.
- [ ] Khẩu phần 1,5 được tính đúng.
- [ ] Không chấp nhận khẩu phần bằng 0 hoặc số âm.
- [ ] Dữ liệu thuộc đúng người dùng và ngày đã chọn.
- [ ] Tổng dinh dưỡng được tính từ dữ liệu thật trong hệ thống.

### Cảnh 7 — Dashboard tổng hợp

**Thời lượng:** 45 giây.

**Thao tác:** Quay về dashboard.

**Lời trình bày:**

“Dashboard tổng hợp dữ liệu từ các chức năng vừa sử dụng. Minh có thể xem lượng dinh dưỡng đã ghi nhận, mục tiêu trong ngày và tiến độ luyện tập.”

**Kết quả mong đợi:**

- Calories và macro khớp Meal Planner.
- Buổi tập vừa hoàn thành được phản ánh đúng.
- Cân nặng, BMI và mục tiêu khớp hồ sơ.

**Tiêu chí nghiệm thu:**

- [ ] Số liệu giữa các màn hình nhất quán.
- [ ] Không cần đăng xuất để cập nhật dữ liệu mới.
- [ ] Trạng thái chưa có dữ liệu được hiển thị rõ ràng.

### Cảnh 8 — Chatbot AI theo ngữ cảnh

**Thời lượng:** 1 phút 30 giây.

**Lời trình bày:**

“Chatbot nhận ngữ cảnh cần thiết do backend cung cấp, gồm mục tiêu, chỉ số sức khỏe và thực đơn hiện tại. Vì vậy, người dùng không cần nhập lại toàn bộ thông tin.”

**Câu hỏi chính:**

“Dựa trên mục tiêu tăng cơ và thực đơn hôm nay của tôi, hãy gợi ý cách bổ sung cho bữa tối và giải thích ngắn gọn.”

**Thao tác:**

1. Gửi câu hỏi.
2. Quan sát trạng thái đang xử lý.
3. Đọc phản hồi.
4. Rời màn hình rồi mở lại hội thoại.

**Kết quả mong đợi:**

- AI trả lời bằng tiếng Việt.
- Phản hồi phù hợp với mục tiêu và dữ liệu đã ghi nhận.
- Phân biệt dữ liệu đã biết và thông tin còn thiếu.
- Không tự sửa thực đơn khi chưa có thao tác xác nhận.
- Hội thoại được lưu.

**Câu hỏi kiểm tra bổ sung nếu còn thời gian:**

“Tôi bị đau đầu gối khi squat, có nên tiếp tục tập không?”

**Kết quả mong đợi:** AI xử lý trong giới hạn tư vấn, không chẩn đoán hoặc khuyến khích tiếp tục tập bất chấp đau; có hướng dẫn tìm hỗ trợ chuyên môn phù hợp.

**Tiêu chí nghiệm thu:**

- [ ] Có phản hồi thật từ dịch vụ AI.
- [ ] Context thuộc đúng tài khoản đang đăng nhập.
- [ ] Không yêu cầu phản hồi giống nguyên văn một đáp án cố định.
- [ ] Lưu được câu hỏi và câu trả lời.
- [ ] Khi dịch vụ lỗi, app thông báo rõ và giữ câu hỏi để thử lại.
- [ ] Không hiển thị hoặc nhúng API key trong ứng dụng.

### Cảnh 9 — Kết thúc

**Thời lượng:** 30 giây.

**Lời trình bày:**

“Luồng demo đã thể hiện việc tạo hồ sơ, lập và ghi nhận buổi tập, theo dõi dinh dưỡng, tổng hợp dữ liệu và trao đổi với AI theo ngữ cảnh. Phiên bản hiện tại tập trung vào Android và các chức năng MVP. Các chức năng nhận diện món ăn bằng ảnh, phân tích tư thế và đồng bộ thiết bị sức khỏe được đưa vào hướng phát triển.”

## 4. Phần demo bổ sung

Chỉ thực hiện khi chức năng đã hoàn thành và còn thời gian:

- Cập nhật cân nặng và xem biểu đồ.
- Admin thêm hoặc ẩn một món ăn, sau đó kiểm tra trên mobile.
- Đăng xuất, đăng nhập lại và kiểm tra dữ liệu vẫn được giữ.

## 5. Phương án khi có sự cố

| Sự cố                                    | Cách xử lý                                             |
| ---------------------------------------- | ------------------------------------------------------ |
| Email đăng ký đã tồn tại                 | Dùng email mới hoặc tài khoản dự phòng                 |
| AI timeout/lỗi dịch vụ                   | Hiển thị lỗi và thử lại; dùng video dự phòng nếu cần   |
| Mất Internet/backend không truy cập được | Chuyển sang video hoặc môi trường dự phòng đã kiểm tra |
| Thiếu thời gian                          | Giữ luồng chính, bỏ phần demo bổ sung                  |

Nếu hiển thị phản hồi AI mẫu, phải ghi rõ đó là dữ liệu minh họa dự phòng.

## 6. Checklist nghiệm thu toàn bộ kịch bản

- [ ] Đăng ký và đăng nhập thành công.
- [ ] Hồ sơ được lưu, các chỉ số tính đúng.
- [ ] Tìm được bài tập và tạo được lịch.
- [ ] Ghi nhận buổi tập và xem lại lịch sử.
- [ ] Thêm/sửa/xóa món, tính đúng theo khẩu phần.
- [ ] Dashboard phản ánh đúng dữ liệu mới.
- [ ] Chatbot trả lời tiếng Việt theo ngữ cảnh và lưu hội thoại.
- [ ] Các luồng chính sử dụng dữ liệu lưu thật.
- [ ] Demo hoàn chỉnh trong 8–10 phút.
- [ ] Có bằng chứng kiểm thử và phương án dự phòng.
