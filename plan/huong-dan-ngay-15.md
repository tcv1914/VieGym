# VieGym — Ngày 15: Tích hợp, hoàn thiện trải nghiệm và đóng phạm vi

**Mục tiêu:** Các module chạy thành một hành trình liên tục; dựng staging và chốt phạm vi để dành thời gian kiểm thử. **Thời lượng:** 7–8 giờ.

## 0. Rà đầu vào — 30 phút

- [ ] Có danh sách chức năng thực sự đã chạy của ngày 1–14.
- [ ] Có lỗi còn mở, không chỉ danh sách tính năng đã viết code.
- [ ] Có tài khoản USER A/B, ADMIN và dữ liệu demo không chứa thông tin cá nhân thật.
- [ ] Backend, mobile, AI và admin đang dùng đúng API contract.

Tạo `docs/32-feature-freeze.md`. Với mỗi chức năng ghi trạng thái: DONE, PARTIAL, NOT_STARTED, BLOCKED; dẫn chứng màn hình/API/test và lỗi liên quan. Chỉ đánh DONE khi chạy được luồng chính và các lỗi dữ liệu/quyền quan trọng đã được xử lý.

## 1. Chạy hành trình người dùng — 90 phút

Đi từ bản cài mới, không chỉ mở từng màn độc lập:

1. Đăng ký → đăng nhập → nhập hồ sơ → xem mục tiêu.
2. Chọn giáo án → tạo lịch tuần → mở buổi tập → ghi kết quả → xem lịch sử.
3. Tìm món → chọn khẩu phần → thêm vào bữa → xem tổng dinh dưỡng.
4. Mở dashboard → kiểm tra tổng cập nhật → mở chatbot hỏi về dữ liệu vừa ghi.
5. Thêm cân nặng → kiểm tra profile/dashboard/biểu đồ.
6. Admin sửa/vô hiệu catalog → kiểm tra thư viện và lịch sử của user.
7. Đăng xuất → đăng nhập B → xác nhận không còn dữ liệu A trên màn hình.

Ghi điểm đứt luồng: nút chưa nối, route sai, loading không tắt, dữ liệu không refresh, DTO khác tên/kiểu. Sửa lỗi làm đứt luồng trước chỉnh màu sắc.

## 2. Chuẩn hóa trạng thái UI — 60 phút

Mỗi màn cần đủ: loading lần đầu, dữ liệu, rỗng, lỗi có thử lại, đang lưu, lưu thất bại. Giữ input khi lỗi server. Thao tác đang xử lý phải chống bấm lặp; nghiệp vụ có nguy cơ ghi trùng vẫn cần idempotency phía server.

| Trạng thái | Cách xử lý |
|---|---|
| 400/422 theo contract | Gắn lỗi vào field phù hợp |
| 401 access hết hạn | Refresh theo cơ chế single-flight đã xây |
| Refresh tạm lỗi mạng | Hiển thị lỗi mạng, không xóa session vô cớ |
| Session bị revoke | Xóa dữ liệu phiên và yêu cầu login |
| 403/404 | Thông báo phù hợp, không lặp request vô hạn |
| 409 revision | Tải lại dữ liệu và cho người dùng xác nhận sửa |
| 429 | Thông báo giới hạn, tôn trọng thời gian thử lại |
| 5xx/timeout | Cho thử lại có kiểm soát, giữ input |

Các API tạo dữ liệu có thể đã commit trước khi timeout; phải tải lại trạng thái hoặc dùng key cũ khi retry. Không tự retry POST với key mới.

## 3. Rà dữ liệu và hiển thị — 60 phút

- Đơn vị nhất quán: kg, cm, kcal, g; ngày hiển thị theo timezone user.
- Không dùng 0 thay cho target chưa xác định, cân nặng thiếu hoặc giá trị dinh dưỡng chưa biết.
- Nhãn món DEMO/ESTIMATED vẫn hiện ở nơi người dùng ra quyết định.
- Bàn phím số, lỗi nhập dấu phẩy/thập phân, màn nhỏ và bàn phím che nút được xử lý.
- Chuỗi tiếng Việt không lỗi font; text dài không tràn; nút có nhãn dễ hiểu.
- Màu không phải tín hiệu duy nhất cho trạng thái. Thử phóng to chữ trên thiết bị.

## 4. Dựng staging — 90 phút

Tạo môi trường test tích hợp với database và secrets riêng, không dùng dữ liệu phát triển lẫn dữ liệu demo cuối. Ghi ma trận cấu hình DEV/STAGING/RELEASE: API URL, DB, AI provider, email, allowed origins, log level.

Thứ tự: PostgreSQL sẵn sàng → migration → Spring → FastAPI kết nối provider → admin → mobile trỏ staging. Áp dụng healthcheck; service đã khởi động chưa chắc dependency đã sẵn sàng.

Nếu chưa có host công khai, staging nội bộ vẫn dùng để kiểm thử nhưng ghi rõ chưa xác nhận HTTPS/Internet. Android emulator, điện thoại thật và container có cách truy cập host khác nhau; không dùng localhost của điện thoại để trỏ server trên máy tính.

Không mở PostgreSQL ra Internet. Không đưa secret vào file cấu hình được commit. Chỉ log thông tin đủ truy vết lỗi, che token và dữ liệu sức khỏe.

## 5. Đóng phạm vi và phân loại lỗi — 45 phút

| Mức | Ví dụ | Quyết định |
|---|---|---|
| P0 | Lộ dữ liệu, mất dữ liệu, secret công khai | Dừng phát hành, xử lý ngay |
| P1 | Không login, không lưu meal/log, crash luồng chính | Phải sửa trước release |
| P2 | Luồng phụ có workaround rõ | Lập lịch sửa hoặc công khai giới hạn |
| P3 | Căn chỉnh, câu chữ nhỏ | Sửa nếu còn buffer |

Mẫu bug: ID; môi trường/build; tài khoản test; bước tái hiện; expected/actual; ảnh/log đã che bí mật; mức độ; người xử lý; commit sửa; kết quả retest.

Feature freeze nghĩa là từ hôm nay ưu tiên sửa lỗi và hoàn thiện yêu cầu đã cam kết. Nếu một tính năng chưa xong, đánh PARTIAL và đánh giá lại phạm vi; không ghi vào báo cáo là đã hoàn thành.

## 6. Checklist nghiệm thu — 45 phút

- [ ] Hành trình 7 bước chạy xuyên module trên staging.
- [ ] Có bảng trạng thái tính năng và backlog đã ưu tiên.
- [ ] Loading/rỗng/lỗi/retry nhất quán.
- [ ] Đổi user không lộ cache; timeout ghi dữ liệu không gây trùng.
- [ ] Có cấu hình staging tách biệt, không secret trong source.
- [ ] Ghi `docs/33-day-15-integration.md` kèm build/commit, lỗi và ảnh.
- [ ] Commit gợi ý: `fix: complete integrated user flows and freeze feature scope`.

Nếu còn P0/P1, lấy thời gian từ chỉnh giao diện và tính năng phụ; không bỏ qua kiểm thử bảo mật hoặc backup để giữ lịch hình thức.

Tham khảo: [Docker Compose — Startup order](https://docs.docker.com/compose/how-tos/startup-order/).
