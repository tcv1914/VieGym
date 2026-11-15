# Feature freeze — ngày 15 (2026-11-15)

Plan ngày 15 gọi file này là `docs/32-feature-freeze.md`. Số 32 đã dùng cho verification ngày 14 nên đổi thành 33. Báo cáo tích hợp là `34-day-15-integration.md`.

Từ hôm nay **không thêm tính năng**. Chỉ sửa lỗi và hoàn thiện các yêu cầu đã cam kết trong `pham-vi-mvp.md`.

Quy tắc trạng thái: chỉ đánh **DONE** khi luồng chính chạy được với dữ liệu thật **và** đã kiểm tra tay trên Android (hoặc trình duyệt với admin). Có test tự động/API nhưng chưa test tay thì đánh **PARTIAL**.

## 1. Trạng thái tính năng

Build: commit `602313d` cộng các thay đổi của ngày 15. Test tự động ngày 15: backend 167/167, mobile 115/115, admin 7/7, ai-service 15/15. Smoke hành trình trên staging 39/39 (docs/34 §2).

### Bắt buộc

| # | Chức năng | Trạng thái | Bằng chứng | Lỗi liên quan |
|---|---|---|---|---|
| 1 | Đăng ký, đăng nhập, đăng xuất, refresh | DONE | docs/10 (Android 8 bước); staging 1.1–1.2, 7.1–7.2 | BUG-01, BUG-06 |
| 2 | Hồ sơ sức khỏe | DONE | docs/12 (Android); staging 1.3 | — |
| 3 | BMI/BMR/TDEE, kcal và macro mục tiêu | DONE | docs/11, docs/12; staging 1.4 | — |
| 4 | Thư viện bài tập | DONE | docs/15 (Android 12/12) | — |
| 5 | Giáo án cơ bản + lịch tuần | DONE | docs/17 (Android 12/12); staging 2.1–2.4 | — |
| 6 | Ghi buổi tập + lịch sử | DONE | docs/19 (Android 13/13); staging 2.5–2.7 (gửi lặp → 409, không trùng) | — |
| 7 | Tìm món Việt + thực đơn ngày | DONE | docs/22 (10/10), docs/24 (14/14); staging 3.1–3.3 | — |
| 8 | Dashboard tổng hợp | PARTIAL | docs/26: test tự động + API; staging 4.1–4.2, 5.2. **Chưa test tay Android** | — |
| 9 | Chatbot AI tiếng Việt, theo ngữ cảnh, lưu hội thoại | DONE | docs/28 (Android 12/12, Gemini thật); staging 4.3–4.5, 7.7 | BUG-03, BUG-04 |

### Hỗ trợ

| # | Chức năng | Trạng thái | Bằng chứng | Lỗi liên quan |
|---|---|---|---|---|
| 10 | Theo dõi cân nặng + biểu đồ | DONE | docs/30 (Android 16/16); staging 5.1–5.3 | — |
| 11 | Đặt lại mật khẩu | DONE | docs/30 (luồng chính đạt trên Android) | BUG-02 |
| 12 | Admin: bài tập, món ăn, người dùng | PARTIAL | docs/32: test tự động + API; staging 6.1–6.9. **Chưa test tay trên trình duyệt (bảng 18 bước)** | — |

### Chỉ làm nếu còn thời gian (không làm, đóng phạm vi)

| Chức năng | Trạng thái |
|---|---|
| Google Login | NOT_STARTED, bỏ khỏi bản này |
| Thông báo nhắc lịch | NOT_STARTED, bỏ khỏi bản này |
| Lịch tháng | NOT_STARTED, bỏ khỏi bản này |
| PR và biểu đồ luyện tập nâng cao | NOT_STARTED, bỏ khỏi bản này |

Không có mục nào BLOCKED.

## 2. Backlog lỗi đã ưu tiên

Mức theo plan ngày 15 §5. Hiện **không có P0**. P1 duy nhất chỉ chặn khi **phát hành công khai**, không chặn demo nội bộ.

| ID | Mức | Môi trường | Mô tả | Expected / actual | Hướng xử lý | Trạng thái |
|---|---|---|---|---|---|---|
| BUG-01 | P2 | mọi môi trường | Chưa giới hạn tần suất `/auth/login` (docs/09 §5, docs/10 §7). | Expected: đăng nhập sai liên tục bị chặn tạm thời. Actual (trước ngày 17): không giới hạn. | Ngày 17: BR-A09, `LoginAttemptLimiter`; retest `repeatedWrongPasswordsAreRateLimitedPerEmail`, `LoginAttemptLimiterTest`, `qa/session_checks.py` S24–S25 (docs/37 §3). | **Đã sửa** |
| BUG-02 | P2 | DEV, Android | Nút "Gửi lại mã" ở màn quên mật khẩu: trong lần test ngày 13, server không thấy request thứ hai (docs/30 §5, bước 16). | Expected: mã mới, mã cũ hết hiệu lực. Actual: chưa xác nhận được. Backend đã có test `newCodeInvalidatesPreviousOne`. | Test lại trên staging hôm nay (bảng docs/34 §4, bước 12). | Mở, chờ test lại |
| BUG-03 | P3 | STAGING | Chatbot viết số thập phân bằng dấu chấm ("1.5 phần", "2258.3 kcal"); app hiển thị số theo vi-VN bằng dấu phẩy (BR-G06). | Expected: "1,5". Actual: "1.5". Nghĩa vẫn đúng. | Thêm một câu hướng dẫn định dạng số vào system prompt, hoặc chấp nhận. | Mở |
| BUG-04 | P3 | DEV | Chatbot nói "tuần này chưa có buổi nào" khi tuần có 1 buổi xong + 1 buổi hủy (docs/28 §6). | Context không có tóm tắt tuần. Không bịa số. | Thêm `training.week` vào context nếu còn thời gian. | Mở |
| BUG-05 | P1 (chỉ khi phát hành công khai) | — | Ảnh và số liệu món lấy từ Viện Dinh dưỡng Quốc gia (docs/22 §6). | Cần xin phép trước khi phát hành công khai. Demo nội bộ có ghi nguồn. | Ghi rõ trong báo cáo; chưa phát hành công khai. | Mở |
| BUG-06 | P3 | — | Chưa kiểm tra tay trường hợp access token hết hạn thật (15 phút) trên thiết bị (docs/10 §7). Đã có test tự động single-flight. | — | Bảng docs/34 §4: để app chờ hơn 15 phút rồi thao tác. | Mở |
| LIM-01 | P3 | STAGING | Backend chạy trong container thấy mọi client qua cùng một IP của gateway Docker, nên giới hạn 10/IP/15 phút của reset dùng chung cho mọi máy. | Chỉ ảnh hưởng staging (một người test). | Ghi trong docs/34 §3. Release thật cần cấu hình proxy tin cậy. | Chấp nhận |
| LIM-02 | P3 | mọi môi trường | Chưa có job dọn phiên/token/mã reset hết hạn (docs/10 §7). | Bảng tăng dần. | Sau MVP. | Chấp nhận |
| SEC-01 | P2 | mọi môi trường | Dependency có lỗ hổng đã biết: Tomcat 11.0.24, Jackson 3.1.5, react-router-dom 6.28.0, certifi/dnspython/pyasn1/opentelemetry (docs/37 §4). | — | Ngày 17: nâng bản vá cùng major, quét lại sạch (trừ công cụ dev của admin). | **Đã sửa** |
| SEC-02 | P3 | mọi môi trường | ai-service mở `/docs`, `/openapi.json` (chỉ trong mạng nội bộ). | — | Ngày 17: tắt; pytest `test_docs_and_openapi_are_disabled`. | **Đã sửa** |
| SEC-03 | P3 | mọi môi trường | Gọi thẳng `GET /error` trả 500 `{"status":999}`. | Không lộ dữ liệu. | Chấp nhận (docs/37 §6). | Chấp nhận |
| SEC-04 | P3 | DEV | Công cụ dev của admin (vitest 2 / tinypool, esbuild của vite 5) có cảnh báo; chỉ chạy trên máy dev, không có trong bản build. | — | Nâng major sau release. | Chấp nhận |
| SEC-05 | P3 | mọi môi trường | `POST /auth/register` trả `409 EMAIL_ALREADY_EXISTS`, nên dò được email đã đăng ký; endpoint này chưa có rate limit. | Theo hợp đồng ngày 2. | Sau MVP: rate limit đăng ký theo IP. | Chấp nhận |
| AI-01 | **P1 (demo)** | STAGING/DEV | Khóa Gemini gói miễn phí: 20 request/ngày/project. Hết lượt thì mọi câu hỏi → 502, thông báo "đang gặp sự cố, thử lại" (docs/37 §5). | Expected: chatbot dùng được suốt buổi demo, hoặc báo rõ đã hết lượt. | Chủ dự án quyết định: khóa trả phí hoặc giới hạn kịch bản demo; sửa thông báo lỗi. | Mở |
| AI-02 | P3 | STAGING | ai-service không nhận kết nối → 504 `AI_TIMEOUT` thay vì 502. | Cả hai retryable. | Phân loại connect timeout riêng. | Mở |

Mẫu ghi lỗi mới: ID; môi trường/build (commit, APK); tài khoản test; bước tái hiện; expected/actual; ảnh/log đã che bí mật; mức; người xử lý; commit sửa; kết quả retest.

## 3. Giới hạn công khai (không phải lỗi)

Các giới hạn này đã chốt ở các ngày trước, giữ nguyên:

- Thực đơn ngày cũ so với mục tiêu **hiện tại** (NUT-BR09). Món tính theo "phần ăn" của nguồn, không quy đổi gram.
- Không sửa/xóa log buổi tập, không tập tự do. Không có trạng thái MISSED.
- 16 món bị ẩn vì lệch Atwater, 96 món thiếu số liệu không nhập. Nội dung bài tập chưa được người có chuyên môn rà.
- Video bài tập chưa hỗ trợ. Chatbot không thay thế tư vấn y tế.
