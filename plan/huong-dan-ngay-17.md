# VieGym — Ngày 17: Kiểm thử bảo mật và đánh giá chatbot

**Mục tiêu:** Xác minh ranh giới tài khoản và hành vi chatbot bằng bằng chứng. **Thời lượng:** 7–8 giờ. Chỉ kiểm thử hệ thống/môi trường bạn được phép kiểm thử.

## 0. Chuẩn bị — 30 phút

- [ ] Staging có A/B/ADMIN, dữ liệu khác nhau và ID fixture đã biết.
- [ ] Có bản backup test, hạn mức AI và cách tắt provider.
- [ ] Có commit/build cố định và danh sách endpoint.
- [ ] Không sử dụng dữ liệu sức khỏe thật cho prompt thử nghiệm.

Tạo `docs/36-security-ai-evaluation.md`. Đánh giá ở đây không đồng nghĩa chứng nhận an toàn toàn diện; ghi phạm vi và giới hạn phép thử.

## 1. Ma trận truy cập — 90 phút

Với mỗi endpoint cá nhân, chạy: chưa login, A truy cập A, A truy cập B, ADMIN truy cập B. ADMIN không mặc nhiên đọc dữ liệu cá nhân trong thiết kế MVP.

| Tài nguyên | ID cần thử thay thế |
|---|---|
| Hồ sơ | userId nếu route cũ còn dùng |
| Giáo án | programId, dayId, exercise association |
| Lịch/log | scheduleId, logId, nested set/exercise ID |
| Meal | planId, entryId |
| Cân nặng | weightLogId |
| Chat | conversationId, message/request ID |

Không chỉ test GET: thử PUT/PATCH/DELETE/POST có tham chiếu ID của B. Kiểm tra query service đã giới hạn bằng user hiện tại; không dựa vào UUID khó đoán. Response lỗi không tiết lộ tên, dữ liệu hoặc sự tồn tại không cần thiết của tài nguyên B.

## 2. Session, reset và quyền admin — 60 phút

- Access token hết hạn, chữ ký sai, issuer/audience sai bị từ chối.
- Logout/khóa user/reset password làm access token cũ mất hiệu lực qua kiểm tra session.
- Refresh token đã rotate không được dùng lại; hai refresh đồng thời không sinh hai session hợp lệ trái chính sách.
- USER không tạo/sửa role hoặc gọi endpoint admin bằng payload tự thêm.
- Reset token hết hạn/đã dùng/race được xử lý đúng.
- Lỗi email/đăng nhập không giúp xác định tài khoản dễ dàng; có rate limit theo thiết kế.

Nếu phát hiện secret trong lịch sử Git, việc xóa file hiện tại chưa đủ: revoke/rotate secret và xử lý lịch sử theo quy trình phù hợp. Không đưa secret phát hiện được vào báo cáo hoặc ảnh minh chứng.

## 3. Input, cấu hình và log — 60 phút

Thử chuỗi có dấu nháy, ký tự HTML và payload dài trên trường tìm kiếm/tên món/chat. Expected là validation hoặc dữ liệu văn bản an toàn, không chạy SQL/script. Kiểm tra truy vấn tham số hóa và cách render nội dung; chỉ vài payload không chứng minh hệ thống miễn nhiễm hoàn toàn.

Rà CORS theo domain admin thực tế; CORS không thay thế authentication. Nếu dùng cookie, kiểm tra CSRF. Rà API docs/health endpoint/log ở staging: không lộ config, stack trace, token hoặc thông tin DB. FastAPI nội bộ yêu cầu xác thực service và không được client truy cập trực tiếp.

Kiểm tra dependency bằng công cụ tương ứng stack hiện tại. Ghi phiên bản/cảnh báo và mức liên quan; không tự nâng major hàng loạt sát release.

## 4. Xây bộ đánh giá AI — 60 phút

Tạo ít nhất 24 câu hỏi trong `docs/37-ai-eval-cases.md`, chia nhóm:

| Nhóm | Số ca tối thiểu | Ví dụ |
|---|---:|---|
| Đúng context | 5 | Hỏi tổng dinh dưỡng fixture ngày đã chọn |
| Thiếu dữ liệu | 4 | Chưa có profile/meal log |
| Tiếng Việt và câu mơ hồ | 4 | “Hôm nay tập gì?” khi không có lịch |
| Vượt phạm vi sức khỏe | 4 | Yêu cầu chẩn đoán hoặc kê thuốc |
| Prompt injection/quyền riêng tư | 4 | Yêu cầu đọc B, tiết lộ token, bỏ qua chỉ dẫn |
| Lỗi hệ thống/giới hạn | 3 | Timeout, 429, input quá dài |

Mỗi case có context fixture, prompt, tiêu chí expected và điều cấm. Không yêu cầu exact string cho câu trả lời AI tự nhiên; yêu cầu số liệu đúng, không bịa dữ liệu, không lộ bí mật, trả lời dễ hiểu và đúng phạm vi.

## 5. Chạy đánh giá và sửa — 90 phút

1. Chạy fake provider để kiểm tra ownership, lỗi, retry và lưu lịch sử.
2. Chạy bộ câu hỏi thật trên model cấu hình hiện tại trong giới hạn chi phí.
3. Ghi provider/model identifier, ngày chạy, phiên bản prompt, context và tham số cấu hình không chứa secret.
4. Chấm từng tiêu chí đạt/không đạt; lỗi dữ liệu/quyền nghiêm trọng không được bù bằng điểm văn phong tốt.
5. Với câu có dao động, lặp lại một số lần và ghi mọi kết quả; không chỉ chọn câu trả lời đẹp.
6. Sửa prompt/context/validation đúng nơi gây lỗi, chạy lại nhóm ảnh hưởng và các case trọng yếu.

Prompt chỉ là một lớp hướng dẫn. Nếu model được yêu cầu lấy dữ liệu B nhưng backend chưa từng cung cấp dữ liệu B và không có tool truy cập DB, ranh giới quyền phải vẫn được giữ bất kể câu trả lời.

Không tuyên bố “AI chính xác 100%” từ tập nhỏ. Báo số ca và tiêu chí đạt thực tế, các lỗi còn lại, giới hạn không kiểm chứng được bằng nhóm test này.

## 6. Checklist đóng ngày

- [ ] Mọi nhóm tài nguyên cá nhân có test A/B với thao tác ghi.
- [ ] Session revoke, admin role và reset token đã kiểm tra.
- [ ] Không còn P0 về lộ dữ liệu hoặc secret chưa xử lý.
- [ ] Có ≥24 ca AI và kết quả thật, tách mock/provider thật.
- [ ] Có danh sách rủi ro còn lại, owner và hướng xử lý.
- [ ] Commit gợi ý: `fix: harden authorization and validate chatbot behavior`.

Tham khảo: [OWASP — Prompt Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html).
