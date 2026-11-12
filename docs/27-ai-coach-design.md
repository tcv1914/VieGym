# AI Coach — thiết kế ngày 12

UC10. Quy tắc: `04-business-rules.md` §7 (BR-AI01..10). API: `05-api-contract.md` §12. Bảng: `03-database-design.md` §7, migration `V12__create_ai_chat.sql`. Kết quả kiểm tra: `28-day-12-verification.md`.

## 1. Khác với plan ngày 12

Như các ngày 5–11, dự án **giữ quyết định ngày 2** (docs/03–05 đã chốt bảng, endpoint, luồng lưu) và chỉ bổ sung phần còn thiếu.

| Điểm | Plan ngày 12 | Áp dụng |
|---|---|---|
| Số docs | `26-chatbot-design.md`, `27-day-12-verification.md` | docs/26 đã dùng cho ngày 11 → **docs/27** (thiết kế), **docs/28** (kiểm tra) |
| Bảng | `chat_conversations`, `chat_requests` (`payload_hash`), `chat_messages` (`request_id`) | `ai_conversations`, `ai_messages`, `ai_chat_requests` theo docs/03 §7; request trỏ `user_message_id`/`assistant_message_id` |
| Khóa gửi lặp | UNIQUE (`conversation_id`, `client_request_id`) | UNIQUE (`user_id`, `client_request_id`) — dùng được cả khi câu hỏi tạo hội thoại mới |
| API | `POST /api/chat/conversations` + `POST …/{id}/messages` | `POST /ai/coach/chat` (`conversationId` null → tạo hội thoại), `GET /ai/conversations`, `GET /ai/conversations/{id}/messages` |
| Cùng key khác nội dung | 409 | `409 CLIENT_REQUEST_ID_REUSED` (so nội dung câu hỏi đã lưu, không cần hash) |
| Thử lại FAILED | Key **mới** | **Cùng** key, cùng tin nhắn câu hỏi, `attempt_count + 1` (BR-AI06) — không sinh câu hỏi trùng |
| Request treo | Job đánh dấu quá hạn | Kiểm tra lười: PROCESSING quá 2 phút bị chuyển `FAILED / AI_TIMEOUT` ngay khi có request hoặc lần đọc chạm tới (BR-AI07), không cần job nền |
| Context dinh dưỡng | Nhãn DEMO/ESTIMATED | Mỗi món kèm `dataQuality` (SOURCED/ESTIMATED/DEMO, docs/20); prompt dặn không dùng DEMO để tư vấn |
| Thêm so với docs/05 | — | `503 AI_DISABLED`; `details.retryAfterSeconds` + header `Retry-After` cho 429; `errorCode` trong lịch sử tin nhắn; context có `today`, `timezone`, `weekday` |

## 2. Luồng

```text
Flutter ──Bearer──▶ Spring  POST /api/v1/ai/coach/chat
                     1. tx ngắn: khóa users FOR UPDATE → tìm clientRequestId
                        → giới hạn tần suất → hội thoại rảnh? → lưu USER + request PROCESSING → commit
                     2. ngoài tx: AiContextBuilder.build(user)  (REPEATABLE READ, chỉ đọc)
                        HttpAiClient ──X-Internal-Key──▶ FastAPI /internal/chat ──▶ Gemini
                     3. tx ngắn: khóa users → request còn đúng lần thử? → lưu ASSISTANT + SUCCEEDED
                        hoặc FAILED + error_code
```

- Bước 1 khóa hàng `users` nên hai request cùng user chạy tuần tự: không vượt hạn mức, không có hai câu chờ trong một hội thoại.
- Mỗi hội thoại chỉ có **một** câu đang chờ AI (`409 AI_REQUEST_IN_PROGRESS`): câu sau cần lịch sử đầy đủ của câu trước.
- Bước 3 so `attempt_count`: nếu trong lúc chờ AI request đã quá hạn và được thử lại ở nơi khác, kết quả cũ bị bỏ, không ghi đè.
- Lỗi bất ngờ khi dựng context/gọi AI vẫn đóng request thành `FAILED / AI_UPSTREAM_ERROR` để hội thoại không bị khóa.
- Không đảm bảo provider chỉ bị gọi một lần: nếu Spring hết giờ chờ trong khi Gemini vẫn trả lời, câu trả lời đó mất và lần thử lại gọi provider lần nữa (tốn thêm một lượt).

## 3. Context (BR-AI03)

`AiContextBuilder` lấy qua service nghiệp vụ đã có, không đọc theo id app gửi:

| Khối | Nguồn | Khi thiếu |
|---|---|---|
| `today`, `timezone`, `weekday` | `users.timezone` | — |
| `profile` (giới tính, tuổi, cao, nặng, mức vận động, mục tiêu, BMI) | `health_profiles`, `nutrition_targets` | `status: "MISSING"`, các trường null |
| `targets` | `MealPlanService.get` (mục tiêu hiện tại, NUT-BR09) | `null` — không điền 0 |
| `todayMealPlan` (`entryCount`, từng món + `dataQuality`, `totals`, `remaining`) | `MealPlanService.get(user, today)` | `entryCount: 0` = "chưa ghi nhận", không phải "chưa ăn" |
| `recentWorkouts` (≤ 5) | `WorkoutLogService.list` | `[]` |
| `upcomingSchedules` (7 ngày, chỉ SCHEDULED) | `WorkoutScheduleService.list` | `[]` |
| `history` (≤ 10 tin gần nhất trước câu hỏi) | `ai_messages` | `[]` |

Không có: email, họ tên, token, id nội bộ, ghi chú tự do, dữ liệu người khác. Không lưu context hay system prompt vào DB — chỉ lưu câu hỏi và câu trả lời user thấy.

## 4. Ranh giới an toàn

- **System prompt cố định** ở `backend/src/main/resources/ai/coach-system-prompt.txt`; app không gửi được prompt hay context.
- **Context là dữ liệu**: FastAPI gói JSON trong `<user_data>…</user_data>` ở lượt cuối; chuỗi `</user_data>` trong dữ liệu bị vô hiệu (`<\/user_data>`) để tên món/buổi tập không "thoát" khỏi khối. Prompt dặn bỏ qua câu lệnh nằm trong dữ liệu.
- **Quyền do Spring thực thi** trước khi gọi AI (hội thoại người khác → 404, không gọi provider). Prompt không thay cho kiểm tra quyền; model không có tool, SQL, file hay URL.
- **Y tế** (BR-AI09): không chẩn đoán/kê đơn/cam kết kết quả; đau, chấn thương, bệnh lý → khuyên dừng bài gây đau và gặp chuyên gia.
- **Không lộ bí mật**: lỗi provider chỉ trả mã đã làm sạch (`AI_UPSTREAM_ERROR`…), không stack trace hay thông điệp gốc. Log (Spring + FastAPI) chỉ có requestId, kết quả, thời lượng — không ghi câu hỏi, context, câu trả lời.
- Không có kho tài liệu truy xuất → đây là **chatbot dùng context**, không gọi là RAG, không yêu cầu trích dẫn.

## 5. Cấu hình và giới hạn

| Khóa | Mặc định | Ghi chú |
|---|---|---|
| `viegym.ai.enabled` (`AI_ENABLED`) | `true` | `false` → `503 AI_DISABLED`, không lưu câu hỏi |
| `viegym.ai.service-url` (`AI_SERVICE_URL`) | `http://127.0.0.1:8000` | Chỉ mạng nội bộ |
| `viegym.ai.internal-key` (`AI_INTERNAL_KEY`) | trống | Khác khóa JWT; trống → mọi câu `FAILED / AI_UPSTREAM_ERROR`, không gọi ai-service. FastAPI so sánh bằng `hmac.compare_digest`; thiếu cấu hình → 503 cho mọi request |
| `connect-timeout` / `timeout` | 3 s / 30 s | BR-AI04. FastAPI tự cắt ở 25 s (`AI_DEADLINE_SECONDS`) để trả 504 có mã; app chờ 35 s |
| `per-minute` / `per-day` | 5 / 50 | Phút: tính mọi lần gọi AI kể cả thử lại. Ngày: chỉ câu hỏi mới, theo múi giờ user. Vượt → `429 RATE_LIMITED` + `Retry-After`, không lưu câu hỏi (BR-AI10) |
| `history-size` | 10 | FastAPI nhận tối đa 20 |
| Độ dài | câu hỏi 1–2.000 ký tự (đếm code point, sau trim) | DB CHECK: USER ≤ 2.000, ASSISTANT ≤ 20.000; FastAPI `AI_MAX_OUTPUT_TOKENS=2048` |

**Provider:** Gemini qua SDK `google-genai` (`ai-service/providers.py`, `temperature=0.4`). Đổi provider chỉ sửa adapter; backend không biết provider. `GEMINI_MODEL` nên là bản có phiên bản (`gemini-2.5-flash`): ngày 10/11 alias `gemini-flash-latest` liên tục trả 503 "high demand" (docs/28 §4). Phản hồi bị bộ lọc an toàn chặn (không có văn bản) → `AI_EMPTY_RESPONSE`.

| Lỗi | Spring trả | `error_code` |
|---|---|---|
| Quá 25 s / Spring quá 30 s | `504 AI_TIMEOUT` | `AI_TIMEOUT` |
| 429, 5xx, sai khóa, không kết nối được | `502 AI_UPSTREAM_ERROR` | `AI_UPSTREAM_ERROR` |
| Rỗng / bị chặn | `502 AI_EMPTY_RESPONSE` | `AI_EMPTY_RESPONSE` |

Body lỗi kèm `requestId`, `conversationId`, `userMessageId`, `retryable: true`.

`HttpAiClient` ép **HTTP/1.1**: mặc định JDK HttpClient gửi `Upgrade: h2c`, uvicorn trả "Unsupported upgrade request" — chỉ lộ ra khi gọi thật (test giả không bắt được), nay có assert trong `HttpAiClientTest`.

## 6. App

```text
lib/features/ai/
├── data/         ai_api.dart (timeout 35 s), ai_models.dart
├── application/  chat_controller.dart
└── presentation/ conversation_list_page.dart, chat_page.dart, coach_text.dart
```

- Lối vào: nút **AI Coach** trên thanh tiêu đề tab Tổng quan → danh sách hội thoại → khung chat. Không có gợi ý AI tự sinh trên Tổng quan.
- Mỗi lần bấm Gửi sinh một `clientRequestId` (UUID v4) giữ nguyên cho mọi lần thử lại câu đó. Nút gửi khóa khi chờ, hiện "AI đang trả lời…".
- Lỗi AI: câu hỏi (đã lưu) chuyển đỏ + "Thử lại" (cùng key). Mất mạng/timeout phía app: giữ câu chờ, "Thử lại" cùng key — server trả kết quả cũ nếu đã xong. 429: giữ câu + thời gian chờ, "Sửa" trả nội dung về ô nhập.
- Ô nhập giới hạn 2.000 ký tự.
- **Hiển thị**: câu hỏi user hiển thị nguyên văn. Câu trả lời AI qua `CoachText`: chỉ nhận `**đậm**`, dòng gạch đầu (`* `, `- `, `• `, lùi lề → `◦`) và tiêu đề `#`; HTML, link và mọi cú pháp khác hiện nguyên văn, không thực thi, không tự mở. Cần vì Gemini vẫn trả Markdown dù prompt yêu cầu văn bản thuần.
- Trạng thái theo user: đổi tài khoản không còn tin nhắn người trước; mở lại hội thoại tải lịch sử từ server.
- Câu trả lời là gợi ý AI; không thay thế kiểm thử chất lượng nội dung.

## 7. Giới hạn

- Chưa streaming: chờ đủ câu trả lời (thường 2–6 s với `gemini-2.5-flash`).
- Không có API xóa hội thoại (docs/04 §8).
- Hạn mức đếm theo DB, không chia sẻ giữa nhiều cụm DB (MVP một backend).
- Chất lượng câu trả lời phụ thuộc model; chỉ kiểm tra tay một nhóm câu (docs/28 §4), chưa có bộ đánh giá tự động.
- Ngày 13 (nhật ký cân nặng) chưa vào context: cân nặng lấy từ hồ sơ.
