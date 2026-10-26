# Wireframe màn hình — VieGym MVP

Wireframe dạng khung chữ: chỉ bố cục, trường dữ liệu, nút và điều hướng; chưa có màu sắc, logo hay animation. API tham chiếu `05-api-contract.md`, quy tắc tham chiếu `04-business-rules.md`.

## 1. Điều hướng

```text
Mở app
  └─ Có refresh token? ──không──► Đăng nhập ◄──► Đăng ký
         │ có                        │ quên mật khẩu → Nhập email → Nhập mã + mật khẩu mới
         ▼                           ▼
   POST /auth/refresh ──lỗi──► Đăng nhập
         │ ok
         ▼
   hasHealthProfile? ──không──► Hồ sơ sức khỏe (bắt buộc lần đầu)
         │ có                          │ lưu
         ▼                             ▼
  ┌──────────────────────── Thanh điều hướng dưới ────────────────────────┐
  │ Trang chủ │ Luyện tập │ Dinh dưỡng │ AI │ Cá nhân                      │
  └───────────────────────────────────────────────────────────────────────┘
  Trang chủ  = Dashboard
  Luyện tập  = Lịch tuần → Chi tiết buổi → Ghi buổi tập → Kết quả
               └ tab: Thư viện bài tập │ Giáo án
  Dinh dưỡng = Meal Planner → Tìm món → Nhập khẩu phần
  AI         = Danh sách hội thoại → Khung chat
  Cá nhân    = Profile → Hồ sơ sức khỏe │ Cân nặng │ Đăng xuất
```

## 2. Quy ước bốn trạng thái

Mọi màn có dữ liệu từ API dùng cùng quy ước:

| Trạng thái | Hiển thị |
|---|---|
| Đang tải | Khung xương (skeleton) hoặc vòng xoay ở giữa; nút gửi bị khóa và hiện vòng xoay nhỏ |
| Có dữ liệu | Nội dung bình thường |
| Chưa có dữ liệu | Hình minh họa + một câu giải thích + nút hành động chính (ví dụ "Thêm món") |
| Lỗi | Thông báo dễ hiểu (không hiện mã nội bộ) + nút "Thử lại"; lỗi trường nhập hiện ngay dưới trường |

Lỗi `401` ở bất kỳ màn nào: thử `POST /auth/refresh` một lần, thất bại thì về Đăng nhập. Timeout request: 10 giây.

## 3. Màn hình

### 3.1 Đăng nhập / Đăng ký — UC01, UC11

```text
┌──────────────────────────────┐      ┌──────────────────────────────┐
│           VieGym             │      │ ←  Tạo tài khoản              │
│                              │      │                              │
│ Email                        │      │ Họ tên                       │
│ [__________________________] │      │ [__________________________] │
│ Mật khẩu                     │      │ Email                        │
│ [____________________] (👁)  │      │ [__________________________] │
│ ⚠ Email hoặc mật khẩu sai    │      │   ⚠ Email đã được sử dụng    │
│                              │      │ Mật khẩu                     │
│ [        Đăng nhập        ]  │      │ [____________________] (👁)  │
│                              │      │   8–72 ký tự, có chữ và số   │
│ Quên mật khẩu?               │      │                              │
│ Chưa có tài khoản? Đăng ký   │      │ [         Đăng ký         ]  │
└──────────────────────────────┘      └──────────────────────────────┘
```

| Thành phần | Ghi chú |
|---|---|
| API | `POST /auth/login`, `POST /auth/register` (rồi gọi login), `/auth/forgot-password`, `/auth/reset-password` |
| Đang tải | Nút đổi thành vòng xoay, khóa nhập |
| Lỗi | `401 INVALID_CREDENTIALS` → "Email hoặc mật khẩu sai"; `403 ACCOUNT_LOCKED` → "Tài khoản đã bị khóa"; `409 EMAIL_ALREADY_EXISTS` dưới trường email; mất mạng → banner + "Thử lại" |
| Điều hướng | Thành công: `hasHealthProfile` false → Hồ sơ sức khỏe, true → Dashboard |

Quên mật khẩu gồm 2 bước: (1) nhập email → luôn báo "Nếu email tồn tại, mã đã được gửi"; (2) nhập mã 6 số + mật khẩu mới → thành công về Đăng nhập. Sai mã → "Mã không hợp lệ hoặc đã hết hạn" (không nói còn bao nhiêu lần).

### 3.2 Hồ sơ sức khỏe — UC02

```text
┌──────────────────────────────┐
│ ←  Hồ sơ sức khỏe             │
│                              │
│ Giới tính (dùng cho công thức)│
│ ( ) Nam   ( ) Nữ             │
│ Ngày sinh      [10/05/2004 📅]│
│ Chiều cao (cm) [ 170,0     ] │
│ Cân nặng (kg)  [  65,0     ] │
│ Mức vận động   [Vừa phải  ▼] │
│   3–5 buổi/tuần              │
│ Mục tiêu                     │
│ ( ) Giảm cân ( ) Giữ cân     │
│ (•) Tăng cơ                  │
│                              │
│ [          Lưu            ]  │
├──────────────────────────────┤
│ Kết quả (sau khi lưu)        │
│ BMI 22,49 · BMR 1.607,5      │
│ TDEE 2.491,6 kcal            │
│ Mục tiêu 2.791,6 kcal/ngày   │
│ P 117,0g · C 406,4g · F 77,5g│
│ ⓘ Đã áp dụng mức kcal tối    │
│   thiểu (nếu kcalFloorApplied)│
└──────────────────────────────┘
```

| Thành phần | Ghi chú |
|---|---|
| API | `GET /health-profile/me`, `PUT /health-profile/me` |
| Chưa có dữ liệu | `404 HEALTH_PROFILE_REQUIRED` → form trống, ẩn phần kết quả; lần đầu không có nút ←, phải lưu mới vào app |
| Lỗi | Lỗi trường theo `fieldErrors` (tuổi 18–80, chiều cao 100–250, cân nặng 30–300) |
| Hiển thị số | Dấu phẩy thập phân theo vi‑VN; gửi API bằng dấu chấm |

### 3.3 Dashboard — UC09

```text
┌──────────────────────────────┐
│ Xin chào, Minh   ‹ 20/10/2026 ›│
├──────────────────────────────┤
│ Dinh dưỡng hôm nay           │
│ 645 / 2.792 kcal  ▓▓░░░░░░░  │
│ Protein 37,5/117,0 g ▓▓░░░░  │
│ Carbs   82,5/406,4 g ▓░░░░░  │
│ Fat     18,0/77,5 g  ▓▓░░░░  │
│ [ + Thêm món ]               │
├──────────────────────────────┤
│ Lịch tập hôm nay             │
│ Buổi A — Full Body  [Bắt đầu]│
│ Tuần này: 1/3 buổi hoàn thành│
├──────────────────────────────┤
│ Cân nặng  64,6 kg (20/10)    │
│ BMI 22,49 · Mục tiêu: Tăng cơ│
├──────────────────────────────┤
│ 🏠  🏋  🍜  🤖  👤             │
└──────────────────────────────┘
```

| Thành phần | Ghi chú |
|---|---|
| API | `GET /dashboard?date=` |
| Chưa có dữ liệu | Từng thẻ rỗng riêng: "Chưa ghi món nào" + Thêm món; "Hôm nay không có lịch" + Lên lịch; "Chưa ghi cân nặng" + Ghi cân nặng |
| Điều hướng | Thêm món → Meal Planner; Bắt đầu → Ghi buổi tập; buổi COMPLETED → Xem kết quả (`workoutLogId`) |

### 3.4 Thư viện bài tập — UC03

```text
┌──────────────────────────────┐      ┌──────────────────────────────┐
│ Luyện tập                    │      │ ←  Squat với tạ đơn           │
│ [Lịch] [Thư viện] [Giáo án]  │      │ ┌──────────────────────────┐ │
│ 🔍 [squat_______________]    │      │ │       (ảnh/video)        │ │
│ Nhóm cơ [Tất cả▼] Dụng cụ[▼] │      │ └──────────────────────────┘ │
│ Độ khó  [Tất cả▼]            │      │ Chân · Tạ đơn · Cơ bản       │
├──────────────────────────────┤      │                              │
│ Squat với tạ đơn             │      │ Hướng dẫn                    │
│ Chân · Tạ đơn · Cơ bản     › │      │ 1. Đứng rộng bằng vai...     │
│ Goblet squat                 │      │ 2. ...                       │
│ Chân · Tạ đơn · Cơ bản     › │      │                              │
│ (cuộn để tải thêm)           │      │                              │
└──────────────────────────────┘      └──────────────────────────────┘
```

| Thành phần | Ghi chú |
|---|---|
| API | `GET /exercises?keyword=&muscleGroup=&equipment=&difficulty=&page=`, `GET /exercises/{id}` |
| Tìm kiếm | Gõ xong 400 ms mới gọi; không phân biệt dấu ("squat", "đẩy ngực" = "day nguc") |
| Chưa có dữ liệu | "Không tìm thấy bài tập phù hợp" + "Xóa bộ lọc" |
| Lỗi | Chi tiết `404` (bài đã ẩn) → "Bài tập không còn khả dụng" + quay lại |

### 3.5 Giáo án và lịch tập — UC04, UC05

```text
┌──────────────────────────────┐      ┌──────────────────────────────┐
│ [Lịch] [Thư viện] [Giáo án]  │      │ ←  Sửa giáo án          [Lưu]│
│ Giáo án đang dùng            │      │ Tên [Full Body cơ bản_____]  │
│ Full Body cơ bản  [Sửa]      │      │                              │
│ ▸ Buổi A (4 bài)             │      │ Buổi A                  [⋮]  │
│ ▸ Buổi B (4 bài)             │      │  1 Squat tạ đơn   3×10 · 90s │
│                              │      │  2 Hít đất        3×12 · 60s │
│ Giáo án mẫu                  │      │  [+ Thêm bài]                │
│ Full Body 3 buổi  [Dùng mẫu] │      │ Buổi B                  [⋮]  │
│ Upper/Lower 4 buổi[Dùng mẫu] │      │  ...                         │
│ [+ Tự tạo giáo án]           │      │ [+ Thêm buổi]                │
└──────────────────────────────┘      └──────────────────────────────┘

┌──────────────────────────────┐      ┌──────────────────────────────┐
│ [Lịch] [Thư viện] [Giáo án]  │      │ ←  Thêm lịch tập             │
│ ‹  Tuần 20/10 – 26/10  ›     │      │ Buổi   [Buổi A — Full Body▼] │
│ T2 20 Buổi A 18:00  ✔ Xong   │      │ Ngày   [20/10/2026 📅]       │
│ T3 21 —                      │      │ Giờ    [18:00 ⏰] (tùy chọn) │
│ T4 22 Buổi B 18:00  ○ Chờ    │      │ Ghi chú[________________]    │
│ T5 23 —                      │      │                              │
│ T6 24 Buổi A 18:00  ✕ Đã hủy │      │ [          Lưu            ]  │
│ T7 25 —   CN 26 —            │      └──────────────────────────────┘
│                      [ + ]   │
└──────────────────────────────┘
```

| Thành phần | Ghi chú |
|---|---|
| API | `GET/POST/PUT /workout-programs`, `GET/POST/PUT /workout-schedules` |
| Sửa bài trong buổi | Hộp thoại: sets 1–10, reps 1–100, nghỉ 0–600 giây; chọn bài mở Thư viện ở chế độ chọn |
| Lịch | Chạm buổi Chờ → Chi tiết buổi (Bắt đầu / Dời lịch / Hủy); buổi Xong → Kết quả; Đã hủy chỉ xem |
| Chưa có dữ liệu | Chưa có giáo án → "Chọn giáo án mẫu hoặc tự tạo"; tuần trống → "Chưa có lịch tuần này" + Thêm lịch |
| Lỗi | `409 INVALID_STATE` (buổi đã archived/lịch đã xong) → thông báo và tải lại; `422 EXERCISE_INACTIVE` → đánh dấu bài cần thay |

### 3.6 Ghi buổi tập — UC06

```text
┌──────────────────────────────┐
│ ✕  Buổi A — 20/10    ⏱ 32:15 │
├──────────────────────────────┤
│ 1. Squat với tạ đơn  (3×10)  │
│  Set  Reps   Tạ (kg)         │
│   1  [10]   [10,0]  ✔        │
│   2  [10]   [10,0]  ✔        │
│   3  [ 8]   [10,0]  ✔        │
│  [+ Thêm set]                │
│ 2. Hít đất  (3×12)           │
│   1  [12]   [ 0  ]           │
│   ⚠ Reps phải lớn hơn 0      │
│  [+ Thêm set]  [Bỏ bài này]  │
│ [+ Thêm bài ngoài kế hoạch]  │
│ Ghi chú [_________________]  │
├──────────────────────────────┤
│ [   Hoàn thành buổi tập   ]  │
└──────────────────────────────┘
```

| Thành phần | Ghi chú |
|---|---|
| API | `GET /workout-schedules/{id}` (bài dự kiến), `POST /workout-logs`, `GET /workout-logs/{id}` |
| Nhập liệu | Mở sẵn số set/reps dự kiến; tạ 0 = không dùng tạ ngoài; chấp nhận ít set hơn kế hoạch (A1, A2) |
| Đang tải | Nút "Hoàn thành" khóa và quay — chặn bấm hai lần |
| Lỗi | Không có set hợp lệ → "Cần ghi ít nhất một set" (A4); mất mạng → giữ nguyên dữ liệu đã nhập + "Thử lại" (A8); `409 WORKOUT_ALREADY_LOGGED` → "Buổi này đã được ghi" + mở log theo `workoutLogId` (A7) |
| Thoát | Bấm ✕ khi có dữ liệu → hộp thoại "Tiếp tục nhập / Bỏ dữ liệu" (A10) |
| Thành công | Màn Kết quả: tổng set, tổng khối lượng (Σ reps × kg), danh sách set; nút "Về lịch tập" |

### 3.7 Meal Planner — UC07

```text
┌──────────────────────────────┐      ┌──────────────────────────────┐
│ Dinh dưỡng   ‹ 20/10/2026 ›  │      │ ←  Thêm vào Bữa sáng          │
│ 645 / 2.792 kcal · còn 2.147 │      │ 🔍 [pho bo______________]    │
│ P 37,5/117 C 82,5/406 F 18/78│      │ Phở bò                       │
├──────────────────────────────┤      │ 1 tô vừa (500 g) · 430 kcal ›│
│ Bữa sáng            645 kcal │      │ Phở gà                       │
│  Phở bò ×1,5        645 kcal │      │ 1 tô vừa (500 g) · 380 kcal ›│
│  [+ Thêm món]                │      ├──────────────────────────────┤
│ Bữa trưa              0 kcal │      │ Phở bò — 1 tô vừa (500 g)    │
│  [+ Thêm món]                │      │ Số khẩu phần  [–] 1,5 [+]    │
│ Bữa tối               0 kcal │      │ = 645 kcal · P 37,5 · C 82,5 │
│  [+ Thêm món]                │      │   · F 18,0 (tạm tính)        │
│ Bữa phụ               0 kcal │      │ [      Thêm vào bữa        ] │
│  [+ Thêm món]                │      └──────────────────────────────┘
└──────────────────────────────┘
```

| Thành phần | Ghi chú |
|---|---|
| API | `GET /meal-plans?date=`, `GET /foods?keyword=`, `POST /meal-plans/entries`, `PUT`/`DELETE /meal-plans/entries/{id}` |
| Tổng | Luôn lấy từ response của backend; số "tạm tính" trên app chỉ để xem trước (BR-N04) |
| Sửa/xóa | Chạm món → sửa khẩu phần hoặc đổi bữa; vuốt trái → xóa có xác nhận |
| Chưa có dữ liệu | Bữa rỗng hiện 0 kcal (A1); tìm món không có kết quả → "Không tìm thấy món" (A2) |
| Không có hồ sơ | `targets = null` → ẩn thanh mục tiêu, hiện "Hoàn thiện hồ sơ để so sánh mục tiêu" (A8) |
| Vượt mục tiêu | Thanh chuyển màu cảnh báo, ghi "vượt X kcal" (A7) |
| Lỗi | Khẩu phần ≤ 0 hoặc > 20 → lỗi tại trường (A3); `422 FOOD_INACTIVE` → "Món không còn khả dụng" (A4); mất mạng → giữ lựa chọn + "Thử lại" (A10) |

### 3.8 AI Coach — UC10

```text
┌──────────────────────────────┐      ┌──────────────────────────────┐
│ AI Coach            [+ Mới]  │      │ ←  Gợi ý bữa tối tăng cơ      │
│ Gợi ý bữa tối tăng cơ        │      │                              │
│ Hôm nay 19:02              › │      │        ┌────────────────────┐│
│ Đau gối khi squat            │      │        │Dựa trên mục tiêu...││
│ Hôm qua                    › │      │        └────────────────────┘│
│                              │      │┌─────────────────────┐       │
│                              │      ││Bạn còn khoảng 2.147  │       │
│                              │      ││kcal; có thể ăn...    │       │
│                              │      │└─────────────────────┘       │
│                              │      │        ┌────────────────────┐│
│                              │      │        │Còn bữa phụ thì sao?││
│                              │      │        └────────────────────┘│
│                              │      │        ⚠ Chưa gửi được [↻]   │
│                              │      │ ··· AI đang trả lời          │
│                              │      ├──────────────────────────────┤
│                              │      │ [Nhập câu hỏi...    ] [Gửi]  │
│                              │      │                    12/2000   │
└──────────────────────────────┘      └──────────────────────────────┘
```

| Thành phần | Ghi chú |
|---|---|
| API | `GET /ai/conversations`, `GET /ai/conversations/{id}/messages`, `POST /ai/coach/chat` |
| Gửi | App sinh `clientRequestId` mỗi lần bấm Gửi; tin nhắn hiện ngay với trạng thái đang gửi, khóa nút Gửi đến khi có kết quả |
| Đang trả lời | Bong bóng "··· AI đang trả lời" (timeout phía AI 30 giây) |
| Lỗi | `502/504` hoặc `requestStatus = FAILED` → dưới câu hỏi hiện "Chưa nhận được trả lời" + ↻ (gửi lại **cùng** `clientRequestId`); `429` → "Bạn gửi quá nhanh, thử lại sau N giây" theo `Retry-After`; quá 2.000 ký tự → khóa Gửi |
| Chưa có dữ liệu | Danh sách rỗng → "Hỏi AI về luyện tập và dinh dưỡng" + vài câu hỏi gợi ý |
| Ghi chú | Dòng nhỏ cố định: "AI chỉ tư vấn, không thay thế chuyên gia y tế" |

### 3.9 Cá nhân — UC08, UC02, UC01

```text
┌──────────────────────────────┐      ┌──────────────────────────────┐
│ Cá nhân                      │      │ ←  Cân nặng                   │
│ Minh                         │      │ [30 ngày] [90 ngày] [1 năm]  │
│ minh@example.com             │      │  66 ┤ •                      │
├──────────────────────────────┤      │  65 ┤   • • •                │
│ Hồ sơ sức khỏe             › │      │  64 ┤         • •            │
│ Cân nặng  64,6 kg          › │      │     └──────────────          │
│ Giáo án đang dùng          › │      │ 20/10  64,6 kg  Sau ngủ dậy  │
├──────────────────────────────┤      │ 18/10  65,0 kg               │
│ [        Đăng xuất        ]  │      │                      [ + ]   │
└──────────────────────────────┘      └──────────────────────────────┘
```

| Thành phần | Ghi chú |
|---|---|
| API | `GET /users/me`, `GET/POST /weight-logs`, `POST /auth/logout` |
| Ghi cân nặng | Hộp thoại: ngày (không chọn được ngày tương lai), cân nặng 30–300, ghi chú; lưu xong hỏi "Cập nhật hồ sơ và tính lại mục tiêu?" (BR-H02) |
| Chưa có dữ liệu | "Chưa có dữ liệu cân nặng" + Ghi cân nặng |
| Đăng xuất | Xác nhận → gọi logout (lỗi mạng vẫn xóa token local) → về Đăng nhập |

## 4. Đối chiếu luồng chính

| Luồng | Các màn |
|---|---|
| Đăng nhập → hồ sơ → dashboard | 3.1 → 3.2 (lần đầu) → 3.3 |
| Ghi buổi tập | 3.3 "Bắt đầu" hoặc 3.5 Lịch → Chi tiết buổi → 3.6 → Kết quả → 3.5 Lịch (✔ Xong) |
| Thêm món | 3.3 "Thêm món" hoặc tab Dinh dưỡng → 3.7 → Tìm món → Nhập khẩu phần → 3.7 (tổng mới) |
| Hỏi AI | Tab AI → 3.8 danh sách → khung chat |
