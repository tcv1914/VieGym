# Hợp đồng API — VieGym MVP

## 1. Quy ước chung

| Nội dung | Quy ước |
|---|---|
| Base URL | `/api/v1` |
| Định dạng | JSON UTF‑8, field `camelCase` |
| Xác thực | `Authorization: Bearer <accessToken>` cho mọi API trừ nhóm Auth công khai |
| ID | UUID dạng chuỗi |
| Ngày | `YYYY-MM-DD` (ngày theo múi giờ user) |
| Thời điểm | ISO‑8601 UTC, ví dụ `2026-10-20T03:15:00Z` |
| Số thập phân | JSON number, dấu chấm (`1.5`) |
| Quyền | **Public** — không cần token; **User** — USER hoặc ADMIN đã đăng nhập; **Admin** — chỉ ADMIN |
| Chủ sở hữu | Luôn lấy từ token; request không có `userId` (BR-G01) |

### 1.1 Lỗi

```json
{
  "code": "VALIDATION_ERROR",
  "message": "Dữ liệu không hợp lệ",
  "fieldErrors": {
    "servings": "Số khẩu phần phải lớn hơn 0"
  },
  "timestamp": "2026-10-20T03:15:00Z",
  "path": "/api/v1/meal-plans/entries"
}
```

`fieldErrors` chỉ có khi `code = VALIDATION_ERROR`. Một số lỗi có thêm field riêng (ghi ở từng API).

| HTTP | Sử dụng | `code` thường gặp |
|---|---|---|
| `200` | Đọc/cập nhật thành công | |
| `201` | Tạo thành công | |
| `204` | Xóa/đăng xuất thành công, không body | |
| `400` | Dữ liệu sai | `VALIDATION_ERROR`, `MALFORMED_JSON` |
| `401` | Chưa xác thực/token sai/hết hạn | `UNAUTHORIZED`, `TOKEN_EXPIRED`, `INVALID_CREDENTIALS`, `INVALID_REFRESH_TOKEN` |
| `403` | Thiếu quyền chức năng / tài khoản khóa | `FORBIDDEN`, `ACCOUNT_LOCKED` |
| `404` | Không tìm thấy hoặc không thuộc user | `NOT_FOUND`, `HEALTH_PROFILE_REQUIRED` |
| `409` | Xung đột dữ liệu/trạng thái | `EMAIL_ALREADY_EXISTS`, `WORKOUT_ALREADY_LOGGED`, `INVALID_STATE`, `AI_REQUEST_IN_PROGRESS` |
| `422` | Tham chiếu hợp lệ về cú pháp nhưng không dùng được | `FOOD_INACTIVE`, `EXERCISE_INACTIVE` |
| `429` | Vượt giới hạn tần suất | `RATE_LIMITED` |
| `500` | Lỗi hệ thống | `INTERNAL_ERROR` |
| `502`/`504` | AI service lỗi/timeout | `AI_UPSTREAM_ERROR`, `AI_TIMEOUT` |

### 1.2 Phân trang

Query: `page` (từ 0, mặc định 0), `size` (1–100, mặc định 20), `sort` (nếu API hỗ trợ).

```json
{
  "items": [],
  "page": 0,
  "size": 20,
  "totalItems": 57,
  "totalPages": 3
}
```

---

## 2. Auth

### `POST /auth/register` — Public

```json
{ "email": "minh@example.com", "password": "Matkhau123", "fullName": "Minh" }
```

**201**

```json
{ "id": "uuid", "email": "minh@example.com", "fullName": "Minh", "role": "USER" }
```

Validation: email hợp lệ ≤ 254; password BR-A02; `fullName` 1–100 sau trim.
Lỗi: `400 VALIDATION_ERROR`, `409 EMAIL_ALREADY_EXISTS`.
Đăng ký không tự đăng nhập; app gọi tiếp `/auth/login`.

### `POST /auth/login` — Public

```json
{ "email": "minh@example.com", "password": "Matkhau123" }
```

**200**

```json
{
  "accessToken": "eyJ...",
  "accessTokenExpiresIn": 900,
  "refreshToken": "opaque-random-string",
  "tokenType": "Bearer",
  "user": { "id": "uuid", "email": "minh@example.com", "fullName": "Minh", "role": "USER", "hasHealthProfile": false }
}
```

Lỗi: `400`, `401 INVALID_CREDENTIALS`, `403 ACCOUNT_LOCKED`.
`hasHealthProfile = false` → app chuyển sang màn hồ sơ sức khỏe.

### `POST /auth/refresh` — Public

```json
{ "refreshToken": "opaque-random-string" }
```

**200**: cùng cấu trúc với login (token mới, xoay vòng — BR-A04).
Lỗi: `401 INVALID_REFRESH_TOKEN` (sai, hết hạn, đã thu hồi), `403 ACCOUNT_LOCKED`.

### `POST /auth/logout` — Public

```json
{ "refreshToken": "opaque-random-string" }
```

**204**. Không cần access token (có thể đã hết hạn). Thu hồi refresh token trong body; token không tồn tại hoặc đã thu hồi vẫn trả 204.

### `POST /auth/forgot-password` — Public

```json
{ "email": "minh@example.com" }
```

**204** trong mọi trường hợp (BR-A06). Giới hạn 3 yêu cầu/email/giờ.

### `POST /auth/reset-password` — Public

```json
{ "email": "minh@example.com", "code": "482913", "newPassword": "Matkhau456" }
```

**204**. Lỗi: `400 VALIDATION_ERROR`, `400 INVALID_RESET_CODE` (sai/hết hạn/đã dùng/đã bị vô hiệu sau 5 lần sai — BR-A06), `429 RATE_LIMITED` (vượt giới hạn theo IP, kèm header `Retry-After`).
Không phân biệt "sai mã" với "mã đã bị vô hiệu" để tránh lộ thông tin.

### `GET /users/me` — User

**200**: `{ "id", "email", "fullName", "role", "timezone", "hasHealthProfile" }`.

---

## 3. Hồ sơ sức khỏe

### `GET /health-profile/me` — User

**200**

```json
{
  "profile": {
    "sex": "MALE",
    "dateOfBirth": "2004-05-10",
    "age": 22,
    "heightCm": 170.0,
    "weightKg": 65.0,
    "activityLevel": "MODERATE",
    "goal": "GAIN_MUSCLE",
    "updatedAt": "2026-10-20T03:15:00Z"
  },
  "targets": {
    "bmi": 22.49,
    "bmrKcal": 1607.5,
    "tdeeKcal": 2491.6,
    "targetKcal": 2791.6,
    "proteinG": 117.0,
    "carbsG": 406.4,
    "fatG": 77.5,
    "kcalFloorApplied": false,
    "formulaVersion": "MSJ-v1",
    "calculatedAt": "2026-10-20T03:15:00Z"
  }
}
```

Lỗi: `404 HEALTH_PROFILE_REQUIRED` khi chưa có hồ sơ.

### `PUT /health-profile/me` — User

Tạo mới hoặc cập nhật (idempotent).

```json
{
  "sex": "MALE",
  "dateOfBirth": "2004-05-10",
  "heightCm": 170,
  "weightKg": 65,
  "activityLevel": "MODERATE",
  "goal": "GAIN_MUSCLE"
}
```

**200**: cùng cấu trúc `GET`. Validation theo `04-business-rules.md` §3.1. Lỗi: `400 VALIDATION_ERROR`.

---

## 4. Cân nặng

### `GET /weight-logs?from=YYYY-MM-DD&to=YYYY-MM-DD` — User

Mặc định 90 ngày gần nhất; khoảng tối đa 366 ngày. Sắp xếp `logDate` tăng dần (phục vụ biểu đồ), không phân trang.

**200**

```json
{ "items": [ { "id": "uuid", "logDate": "2026-10-20", "weightKg": 65.0, "note": null } ] }
```

Lỗi: `400` khi `from > to` hoặc khoảng quá dài.

### `POST /weight-logs` — User

```json
{ "logDate": "2026-10-20", "weightKg": 64.6, "note": "Sau khi ngủ dậy" }
```

**201** (tạo mới) / **200** (cập nhật cùng ngày — BR-WL01): `{ "id", "logDate", "weightKg", "note" }`.
Validation: `logDate` không ở tương lai; `weightKg` 30–300; `note` ≤ 500.

---

## 5. Bài tập

### `GET /exercises` — User

Query: `page`, `size`, `keyword` (không phân biệt dấu/hoa thường), `muscleGroup`, `equipment`, `difficulty`.
Chỉ trả bài `is_active` (Admin dùng API admin để xem bài ẩn).

**200**: trang các phần tử

```json
{ "id": "uuid", "name": "Squat với tạ đơn", "muscleGroup": "LEGS", "equipment": "DUMBBELL", "difficulty": "BEGINNER", "mediaUrl": null }
```

Lỗi: `400` khi enum lọc sai.

### `GET /exercises/{id}` — User

**200**: phần tử trên + `"instructions": "..."`. Lỗi: `404` (bao gồm bài đã ẩn).

---

## 6. Giáo án

### `GET /workout-programs?scope=mine|templates` — User

Mặc định `mine`. **200**: `{ "items": [ { "id", "name", "description", "isTemplate", "isActive", "dayCount" } ] }` (số lượng nhỏ, không phân trang).

### `GET /workout-programs/{id}` — User

Đọc được giáo án của mình hoặc giáo án mẫu.

**200**

```json
{
  "id": "uuid",
  "name": "Full Body cơ bản",
  "description": "3 buổi/tuần cho người mới",
  "isTemplate": false,
  "isActive": true,
  "days": [
    {
      "id": "uuid",
      "dayOrder": 1,
      "name": "Buổi A",
      "exercises": [
        { "id": "uuid", "orderNo": 1, "exerciseId": "uuid", "exerciseName": "Squat với tạ đơn", "targetSets": 3, "targetReps": 10, "restSeconds": 90 }
      ]
    }
  ]
}
```

Lỗi: `404`.

### `POST /workout-programs` — User

Hai cách:

```json
{ "templateId": "uuid", "activate": true }
```

hoặc tự tạo:

```json
{
  "name": "Giáo án của Minh",
  "description": null,
  "activate": true,
  "days": [
    { "name": "Buổi A", "exercises": [ { "exerciseId": "uuid", "targetSets": 3, "targetReps": 10, "restSeconds": 90 } ] }
  ]
}
```

**201**: cấu trúc như `GET /workout-programs/{id}`.
Validation: có `templateId` **hoặc** `name` + `days`, không cả hai; 1–7 buổi; mỗi buổi 1–15 bài; `targetSets` 1–10, `targetReps` 1–100, `restSeconds` 0–600. `dayOrder`/`orderNo` do backend gán theo thứ tự mảng.
Lỗi: `400`, `404` (template không tồn tại), `422 EXERCISE_INACTIVE`.

### `PUT /workout-programs/{id}` — User

Body như tạo tự do (`name`, `description`, `activate`, `days`). Buổi có sẵn gửi kèm `id` để giữ nguyên; buổi không có trong body bị gỡ (archive nếu còn lịch tham chiếu — BR-W07).
**200**. Lỗi: `400`, `403 FORBIDDEN` khi sửa giáo án mẫu, `404`, `422 EXERCISE_INACTIVE`.

---

## 7. Lịch tập

### `GET /workout-schedules?from=YYYY-MM-DD&to=YYYY-MM-DD&status=` — User

Khoảng tối đa 62 ngày; mặc định tuần hiện tại (thứ Hai–Chủ nhật).

**200**

```json
{
  "items": [
    {
      "id": "uuid",
      "scheduledDate": "2026-10-20",
      "startTime": "18:00",
      "status": "SCHEDULED",
      "note": null,
      "workoutDay": { "id": "uuid", "name": "Buổi A", "programName": "Full Body cơ bản" },
      "workoutLogId": null
    }
  ]
}
```

### `POST /workout-schedules` — User

```json
{ "workoutDayId": "uuid", "scheduledDate": "2026-10-20", "startTime": "18:00", "note": null }
```

**201**: phần tử như trên. Lỗi: `400`, `404` (buổi không thuộc user), `409 INVALID_STATE` (buổi đã archived).

### `GET /workout-schedules/{id}` — User

**200**: phần tử như trên + `"exercises"` của buổi (giống `days[].exercises`) để mở màn ghi nhận. Lỗi: `404`.

### `PUT /workout-schedules/{id}` — User

```json
{ "scheduledDate": "2026-10-21", "startTime": "07:00", "note": "Dời sang sáng", "status": "SCHEDULED" }
```

`status` chỉ nhận `SCHEDULED` (giữ) hoặc `CANCELLED`. **Không** nhận `COMPLETED` — hoàn thành chỉ qua `POST /workout-logs` (BR-W04).
**200**. Lỗi: `400` (gửi `COMPLETED`), `404`, `409 INVALID_STATE` (lịch đã COMPLETED/CANCELLED).

---

## 8. Workout log

### `POST /workout-logs` — User

```json
{
  "scheduleId": "uuid",
  "startedAt": "2026-10-20T11:00:00Z",
  "endedAt": "2026-10-20T11:50:00Z",
  "note": "Hoàn thành buổi tập đầu tiên",
  "exercises": [
    {
      "exerciseId": "uuid",
      "sets": [
        { "reps": 10, "weightKg": 10 },
        { "reps": 10, "weightKg": 10 },
        { "reps": 8, "weightKg": 10 }
      ]
    }
  ]
}
```

**201**: cấu trúc như `GET /workout-logs/{id}`. Lịch chuyển `COMPLETED` cùng giao dịch.
Validation: 1–20 bài, mỗi bài 1–20 set; `reps` 1–1000; `weightKg` 0–999,99; `endedAt ≥ startedAt`; `note` ≤ 1000.
Lỗi:
- `400 VALIDATION_ERROR`
- `404` — lịch không tồn tại/không thuộc user
- `409 INVALID_STATE` — lịch đã hủy
- `409 WORKOUT_ALREADY_LOGGED` — kèm `"workoutLogId": "uuid"` để app mở log hiện có
- `422 EXERCISE_INACTIVE`

### `GET /workout-logs?from=&to=&page=&size=` — User

Sắp xếp `workoutDate` giảm dần. **200**: trang các phần tử

```json
{ "id": "uuid", "workoutDate": "2026-10-20", "workoutName": "Buổi A", "exerciseCount": 4, "setCount": 12, "totalVolumeKg": 1180.0 }
```

`totalVolumeKg = Σ reps × weightKg`.

### `GET /workout-logs/{id}` — User

**200**

```json
{
  "id": "uuid",
  "scheduleId": "uuid",
  "workoutDate": "2026-10-20",
  "workoutName": "Buổi A",
  "startedAt": "2026-10-20T11:00:00Z",
  "endedAt": "2026-10-20T11:50:00Z",
  "note": "Hoàn thành buổi tập đầu tiên",
  "exercises": [
    {
      "orderNo": 1,
      "exerciseId": "uuid",
      "exerciseName": "Squat với tạ đơn",
      "sets": [ { "setNo": 1, "reps": 10, "weightKg": 10.0 } ]
    }
  ]
}
```

Lỗi: `404`.

---

## 9. Món ăn

### `GET /foods` — User

Query: `page`, `size`, `keyword` (không phân biệt dấu). Chỉ món `is_active`.

**200**: trang các phần tử

```json
{
  "id": "uuid",
  "name": "Phở bò",
  "servingSize": 500,
  "servingUnit": "g",
  "servingDescription": "1 tô vừa",
  "kcalPerServing": 430,
  "proteinPerServing": 25,
  "carbsPerServing": 55,
  "fatPerServing": 12
}
```

### `GET /foods/{id}` — User

**200**: phần tử trên + `"source"`. Lỗi: `404` (bao gồm món đã ẩn).

---

## 10. Thực đơn

### `GET /meal-plans?date=YYYY-MM-DD` — User

Mặc định hôm nay theo múi giờ user. Chưa có thực đơn vẫn trả **200** với bữa rỗng (UC07‑A1).

**200**

```json
{
  "date": "2026-10-20",
  "meals": {
    "BREAKFAST": [
      {
        "id": "uuid",
        "foodId": "uuid",
        "foodName": "Phở bò",
        "servingSize": 500,
        "servingUnit": "g",
        "servings": 1.5,
        "kcal": 645.0,
        "proteinG": 37.5,
        "carbsG": 82.5,
        "fatG": 18.0
      }
    ],
    "LUNCH": [],
    "DINNER": [],
    "SNACK": []
  },
  "totals": { "kcal": 645.0, "proteinG": 37.5, "carbsG": 82.5, "fatG": 18.0 },
  "targets": { "kcal": 2791.6, "proteinG": 117.0, "carbsG": 406.4, "fatG": 77.5 },
  "remaining": { "kcal": 2146.6, "proteinG": 79.5, "carbsG": 323.9, "fatG": 59.5 }
}
```

`targets`/`remaining` là `null` khi chưa có hồ sơ (UC07‑A8). `remaining` âm = vượt mục tiêu (UC07‑A7).

### `POST /meal-plans/entries` — User

```json
{ "date": "2026-10-20", "mealType": "BREAKFAST", "foodId": "uuid", "servings": 1.5 }
```

**201**: toàn bộ thực đơn của ngày (cấu trúc `GET /meal-plans`), để app cập nhật tổng ngay.
Validation: `mealType` thuộc 4 giá trị; `servings` BR-N02; `date` BR-N07. Các field `kcal`/macro trong body bị bỏ qua (BR-N04).
Lỗi: `400`, `404` (món không tồn tại), `422 FOOD_INACTIVE`.

### `PUT /meal-plans/entries/{id}` — User

```json
{ "servings": 2, "mealType": "LUNCH" }
```

Cả hai field tùy chọn, ít nhất một. **200**: toàn bộ thực đơn ngày. Lỗi: `400`, `404`.

### `DELETE /meal-plans/entries/{id}` — User

**200**: toàn bộ thực đơn ngày sau khi xóa (không dùng 204 vì app cần tổng mới). Lỗi: `404`.

---

## 11. Dashboard

### `GET /dashboard?date=YYYY-MM-DD` — User

**200**

```json
{
  "date": "2026-10-20",
  "health": { "hasProfile": true, "weightKg": 65.0, "bmi": 22.49, "goal": "GAIN_MUSCLE", "latestWeightLog": { "logDate": "2026-10-20", "weightKg": 64.6 } },
  "nutrition": {
    "totals": { "kcal": 645.0, "proteinG": 37.5, "carbsG": 82.5, "fatG": 18.0 },
    "targets": { "kcal": 2791.6, "proteinG": 117.0, "carbsG": 406.4, "fatG": 77.5 }
  },
  "training": {
    "today": [ { "scheduleId": "uuid", "name": "Buổi A", "status": "COMPLETED", "workoutLogId": "uuid" } ],
    "week": { "scheduled": 3, "completed": 1, "cancelled": 0 }
  }
}
```

Tuần = thứ Hai–Chủ nhật chứa `date`. Không có dữ liệu → giá trị `null`/mảng rỗng, không lỗi.

---

## 12. AI Coach

### `POST /ai/coach/chat` — User

```json
{
  "clientRequestId": "6f1c8a1e-6f0d-4c41-9d0e-2b1f6f0f9a10",
  "conversationId": null,
  "message": "Dựa trên mục tiêu tăng cơ và thực đơn hôm nay của tôi, hãy gợi ý bữa tối."
}
```

Chỉ nhận câu hỏi và định danh; **không** nhận hồ sơ, thực đơn hay `userId` — context do backend lấy (BR-AI03).

**200** (thành công, hoặc gửi lặp một request đã SUCCEEDED):

```json
{
  "requestId": "uuid",
  "clientRequestId": "6f1c8a1e-...",
  "status": "SUCCEEDED",
  "conversation": { "id": "uuid", "title": "Dựa trên mục tiêu tăng cơ và thực đơn hôm nay..." },
  "userMessage": { "id": "uuid", "role": "USER", "content": "...", "createdAt": "2026-10-20T12:00:00Z" },
  "assistantMessage": { "id": "uuid", "role": "ASSISTANT", "content": "...", "createdAt": "2026-10-20T12:00:08Z" }
}
```

**Thất bại AI** — `504 AI_TIMEOUT` hoặc `502 AI_UPSTREAM_ERROR`/`AI_EMPTY_RESPONSE`, body lỗi chuẩn kèm:

```json
{ "requestId": "uuid", "conversationId": "uuid", "userMessageId": "uuid", "retryable": true }
```

Câu hỏi đã lưu; app thử lại bằng **cùng** `clientRequestId` (BR-AI06).

Validation: `clientRequestId` UUID bắt buộc; `message` 1–2.000 ký tự sau trim; `conversationId` nếu có phải thuộc user.
Lỗi khác: `400`, `404` (hội thoại không thuộc user), `409 AI_REQUEST_IN_PROGRESS`, `429 RATE_LIMITED` (kèm header `Retry-After`).

### `GET /ai/conversations?page=&size=` — User

Sắp xếp `lastMessageAt` giảm dần. **200**: trang `{ "id", "title", "lastMessageAt", "createdAt" }`.

### `GET /ai/conversations/{id}/messages?page=&size=` — User

Sắp xếp `createdAt` tăng dần; mặc định `size=50`. **200**: trang các phần tử

```json
{ "id": "uuid", "role": "USER", "content": "...", "createdAt": "...", "requestStatus": "FAILED", "clientRequestId": "6f1c8a1e-..." }
```

`requestStatus`/`clientRequestId` chỉ có ở tin nhắn USER, để app hiện nút "Thử lại" cho câu hỏi FAILED.
Lỗi: `404` (không tồn tại hoặc thuộc user khác — AI-BR03).

### Hợp đồng nội bộ backend → `ai-service`

`POST {AI_SERVICE_URL}/internal/chat`, header `X-Internal-Key` (chỉ trong mạng nội bộ, không public).

```json
{
  "requestId": "uuid",
  "systemPrompt": "...",
  "context": { "profile": {}, "targets": {}, "todayMealPlan": {}, "recentWorkouts": [], "upcomingSchedules": [] },
  "history": [ { "role": "USER", "content": "..." }, { "role": "ASSISTANT", "content": "..." } ],
  "message": "..."
}
```

**200**: `{ "content": "...", "model": "...", "promptTokens": 1200, "completionTokens": 350 }`. Lỗi: `502`/`504`.

---

## 13. Admin (UC12 — chức năng hỗ trợ, chi tiết hóa khi làm trang admin)

| Endpoint | Ghi chú |
|---|---|
| `GET/POST /admin/foods`, `PUT /admin/foods/{id}` | Có `isActive`; GET trả cả món ẩn |
| `GET/POST /admin/exercises`, `PUT /admin/exercises/{id}` | Tương tự |
| `GET /admin/users`, `PUT /admin/users/{id}/status` | `ACTIVE`/`LOCKED`; không tự khóa chính mình |

Tất cả yêu cầu role ADMIN; User gọi → `403 FORBIDDEN`. Không có `DELETE` (ẩn thay vì xóa).

---

## 14. Đối chiếu use case ↔ API

| Use case | API |
|---|---|
| UC01 | `/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/logout`, `/users/me` |
| UC02 | `/health-profile/me` |
| UC03 | `/exercises` |
| UC04 | `/workout-programs` |
| UC05 | `/workout-schedules` |
| UC06 | `/workout-logs` |
| UC07 | `/foods`, `/meal-plans`, `/meal-plans/entries` |
| UC08 | `/weight-logs` |
| UC09 | `/dashboard` |
| UC10 | `/ai/coach/chat`, `/ai/conversations` |
| UC11 | `/auth/forgot-password`, `/auth/reset-password` |
| UC12 | `/admin/*` |
