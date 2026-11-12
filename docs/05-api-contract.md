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
| `401` | Chưa xác thực/token sai/hết hạn | `UNAUTHORIZED` (thiếu/sai/hết hạn access token, phiên đã thu hồi), `INVALID_CREDENTIALS`, `INVALID_REFRESH_TOKEN` |
| `403` | Thiếu quyền chức năng / tài khoản khóa | `FORBIDDEN`, `ACCOUNT_LOCKED` |
| `404` | Không tìm thấy hoặc không thuộc user | `NOT_FOUND`, `HEALTH_PROFILE_REQUIRED` |
| `409` | Xung đột dữ liệu/trạng thái | `EMAIL_ALREADY_EXISTS`, `WORKOUT_ALREADY_LOGGED`, `INVALID_STATE`, `AI_REQUEST_IN_PROGRESS` |
| `422` | Tham chiếu hợp lệ về cú pháp nhưng không dùng được | `FOOD_INACTIVE`, `EXERCISE_INACTIVE`, `MEAL_PLAN_LIMIT` (vượt giới hạn số lượng) |
| `429` | Vượt giới hạn tần suất | `RATE_LIMITED` |
| `500` | Lỗi hệ thống | `INTERNAL_ERROR` |
| `502`/`504` | AI service lỗi/timeout | `AI_UPSTREAM_ERROR`, `AI_TIMEOUT` |
| `503` | [Ngày 12] AI Coach bị tắt bằng cấu hình | `AI_DISABLED` |

### 1.2 Phân trang

Query: `page` (từ 0, mặc định 0), `size` (1–100, mặc định 20), `sort` (nếu API hỗ trợ).

```json
{
  "items": [],
  "page": 0,
  "size": 20,
  "totalItems": 57,
  "totalPages": 3,
  "hasNext": true
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

**204**. Không cần access token (có thể đã hết hạn). Thu hồi phiên chứa refresh token trong body cùng mọi refresh token của phiên đó; access token của phiên bị từ chối ngay. Phiên trên thiết bị khác không ảnh hưởng. Token không tồn tại hoặc đã thu hồi vẫn trả 204.

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

**200**: cùng cấu trúc `GET`. Validation theo `04-business-rules.md` §3.1. Lỗi: `400 VALIDATION_ERROR` có `fieldErrors` theo trường, kể cả khi enum lạ hoặc ngày sai định dạng. Field lạ (`userId`, `bmi`, `targetKcal`…) bị bỏ qua. Cách tính: `11-health-calculation-rules.md`.

`profile.age` là tuổi hôm nay theo múi giờ user; `targets` là kết quả lúc lưu gần nhất, GET không tính lại (BR-H04).

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

Query (đều tùy chọn): `page`, `size`, `keyword` (≤ 100 ký tự sau chuẩn hóa; không phân biệt dấu/hoa thường, `%`/`_` được tìm như chữ thường), `muscleGroup`, `equipment`, `difficulty`. Các bộ lọc kết hợp AND; tham số rỗng = không lọc.
Chỉ trả bài `is_active` (Admin dùng API admin để xem bài ẩn). Sắp xếp theo tên bỏ dấu rồi `id`.

**200**: trang các phần tử

```json
{ "id": "uuid", "name": "Đẩy ngực với tạ đơn (Dumbbell Bench Press)", "muscleGroup": "CHEST", "equipment": "DUMBBELL", "difficulty": "BEGINNER", "thumbnailUrl": "http://…/media/exercises/0289-….jpg" }
```

Lỗi: `400 VALIDATION_ERROR` (`fieldErrors` theo tên tham số) khi enum lọc sai (phân biệt hoa/thường), `page` < 0 hoặc không phải số, `size` ngoài 1–100, `keyword` quá dài. Không có kết quả → `200` với `items` rỗng.

### `GET /exercises/{id}` — User

**200**: phần tử trên + `"instructions"`, `"commonMistakes"` (mỗi dòng một ý), `"mediaType"` (`IMAGE`/`GIF`/`VIDEO`/null), `"mediaUrl"`, `"contentSource"`, `"mediaLicense"`. App phải hiển thị `mediaLicense` cạnh media.
Lỗi: `400` khi `id` không phải UUID; `404 NOT_FOUND` khi không có hoặc bài đã ẩn.

### `GET /exercise-filters` — User

**200**: mã dùng trong query kèm nhãn hiển thị, để app không giữ bộ danh mục riêng.

```json
{ "muscleGroups": [ { "code": "CHEST", "name": "Ngực" } ], "equipment": [ { "code": "NONE", "name": "Không dụng cụ" } ], "difficulties": [ { "code": "BEGINNER", "name": "Cơ bản" } ] }
```

### Media — Public

`GET /media/exercises/{file}`: ảnh/GIF tĩnh, không cần token (Image.network không gửi Bearer). URL lấy từ `thumbnailUrl`/`mediaUrl`, không tự ghép.

---

## 6. Giáo án

### `GET /workout-programs?scope=mine|templates` — User

Mặc định `mine`. **200**: `{ "items": [ { "id", "name", "description", "isTemplate", "isActive", "dayCount" } ] }` (số lượng nhỏ, không phân trang).

### `GET /workout-programs/{id}` — User

[Ngày 7] Response có thêm `sourceTemplateId`, `version`; mỗi bài có thêm `exerciseActive` (false = bài đã bị ẩn, cần thay) và `thumbnailUrl`. Chỉ trả buổi chưa archived.

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
[Ngày 7] Thêm `version` **bắt buộc** (lấy từ GET); `activate` null = giữ trạng thái.
**200**, kèm `version` mới. Lỗi: `400`, `403 FORBIDDEN` khi sửa giáo án mẫu, `404`, `409 VERSION_CONFLICT` (version cũ), `422 EXERCISE_INACTIVE`.

### `POST /workout-programs/{id}/activate` — User [Thêm ngày 7]

Kích hoạt giáo án của mình, tự tắt giáo án đang active (BR-W01); đã active thì không đổi. **200**: như GET. Lỗi: `403` (mẫu), `404`.

Giới hạn MVP: 20 giáo án/user → `409 INVALID_STATE` khi tạo thêm.

---

## 7. Lịch tập

### `GET /workout-schedules?from=YYYY-MM-DD&to=YYYY-MM-DD&status=` — User

Khoảng đóng [from, to], tối đa 62 ngày; không gửi cả hai = tuần hiện tại (thứ Hai–Chủ nhật) theo múi giờ user; chỉ gửi một → 400. Sắp xếp theo ngày, giờ (null cuối), id. [Ngày 7] Response có thêm `from`, `to`; `workoutDay` có thêm `programId`, `archived`.

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

**201**: như `GET /workout-schedules/{id}`. Lỗi: `400` (ngày đã qua theo múi giờ user, quá 5 lịch chưa hủy/ngày), `404` (buổi không thuộc user), `409 INVALID_STATE` (buổi đã archived), `422 EXERCISE_INACTIVE` (buổi có bài bị ẩn) [Ngày 7].

### `GET /workout-schedules/{id}` — User

**200**: phần tử như trên + `"exercises"` của buổi (giống `days[].exercises`) để mở màn ghi nhận. Lỗi: `404`.
[Ngày 8] `workoutLogId` (cả danh sách và chi tiết) là id log khi lịch đã `COMPLETED`, còn lại `null`.

### `PUT /workout-schedules/{id}` — User

```json
{ "scheduledDate": "2026-10-21", "startTime": "07:00", "note": "Dời sang sáng", "status": "SCHEDULED" }
```

`status` chỉ nhận `SCHEDULED` (giữ) hoặc `CANCELLED`. **Không** nhận `COMPLETED` — hoàn thành chỉ qua `POST /workout-logs` (BR-W04).
Khi `CANCELLED` chỉ đổi trạng thái, ngày/giờ/ghi chú trong body bị bỏ qua. Đổi sang ngày khác phải là hôm nay trở đi.
**200**. Lỗi: `400` (gửi `COMPLETED`, ngày mới đã qua), `404`, `409 INVALID_STATE` (lịch đã COMPLETED/CANCELLED).

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
Validation: 1–20 bài (không trùng `exerciseId`), mỗi bài 1–20 set; `reps` nguyên 1–1000; `weightKg` bắt buộc 0–999,99, tối đa 2 số lẻ; `startedAt`/`endedAt` tùy chọn, không ở tương lai (dung sai 5 phút), `endedAt ≥ startedAt`, ≤ 24 giờ; `note` ≤ 1000. Client không gửi `setNo`/`orderNo` (server đánh theo thứ tự mảng).
Lỗi:
- `400 VALIDATION_ERROR` — `fieldErrors` theo đường dẫn, vd. `exercises[0].sets[1].reps`
- `404` — lịch không tồn tại/không thuộc user
- `409 INVALID_STATE` — lịch đã hủy, hoặc chưa tới ngày của lịch (BR-W09)
- `409 WORKOUT_ALREADY_LOGGED` — kèm `"workoutLogId": "uuid"` ở cấp gốc body lỗi để app mở log hiện có. Áp dụng cho **mọi** lần gửi lặp, dù nội dung giống hay khác; log đã lưu không bị đổi
- `422 EXERCISE_INACTIVE` — bài ngoài buổi đã bị ẩn (bài trong buổi đã ẩn vẫn ghi được)

Sau khi mất mạng, app xác minh bằng `GET /workout-schedules/{id}`: `workoutLogId` khác null nghĩa là đã lưu. [Ngày 8]

### `GET /workout-logs?from=&to=&page=&size=` — User

`from`/`to`: khoảng đóng theo `workoutDate`, mỗi đầu tùy chọn; gửi cả hai thì tối đa 366 ngày, `from > to` → 400. Phân trang §1.2. Sắp xếp `workoutDate` giảm dần (rồi thời điểm ghi). **200**: trang các phần tử

```json
{ "id": "uuid", "scheduleId": "uuid", "workoutDate": "2026-10-20", "workoutName": "Buổi A", "programName": "Full Body cơ bản",
  "startedAt": "2026-10-20T11:00:00Z", "endedAt": "2026-10-20T11:50:00Z",
  "exerciseCount": 4, "setCount": 12, "totalReps": 120, "totalVolumeKg": 1180.00 }
```

`totalVolumeKg = Σ reps × weightKg` — chỉ tạ ngoài; bài không tạ góp 0 vào volume nhưng vẫn tính trong `totalReps`.

### `GET /workout-logs/{id}` — User

**200**

```json
{
  "id": "uuid",
  "scheduleId": "uuid",
  "workoutDate": "2026-10-20",
  "workoutName": "Buổi A",
  "programName": "Full Body cơ bản",
  "startedAt": "2026-10-20T11:00:00Z",
  "endedAt": "2026-10-20T11:50:00Z",
  "note": "Hoàn thành buổi tập đầu tiên",
  "createdAt": "2026-10-20T11:51:02Z",
  "exerciseCount": 1, "setCount": 1, "totalReps": 10, "totalVolumeKg": 100.00,
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

Query: `page`, `size`, `keyword` (không phân biệt dấu, ≤ 100 ký tự), [Ngày 9] `category` (mã danh mục), `region` (`VPF`|`HAN`|`HAP`|`SFF`). Chỉ món `is_active`. Sắp theo tên bỏ dấu rồi id. Mã lọc lạ → `400 VALIDATION_ERROR`; không có kết quả → `200` `items` rỗng.

**200**: trang các phần tử

```json
{
  "id": "uuid",
  "code": "VPF-000272",
  "name": "Phở bò tái 24h",
  "category": { "code": "BANH_DA_BUN_PHO", "name": "Bánh đa, bún, phở" },
  "region": { "code": "VPF", "name": "Toàn quốc" },
  "servingDescription": "1 phần ăn theo nguồn",
  "servingSize": null,
  "servingUnit": null,
  "kcalPerServing": 314.00,
  "proteinPerServing": 18.70,
  "carbsPerServing": 47.40,
  "fatPerServing": 5.50,
  "dataQuality": "SOURCED",
  "imageUrl": "https://viendinhduong.vn/storage/app/uploads/…webp"
}
```

Mọi số dinh dưỡng là của **một khẩu phần** `servingDescription`; `servingSize`/`servingUnit` null khi nguồn không ghi khối lượng (docs/20 §2).

### `GET /foods/{id}` — User

**200**: phần tử trên + `"nameEn"`, `"source"`, `"sourceUrl"`, `"revision"`. Lỗi: `404` (bao gồm món đã ẩn).

### `GET /food-filters` — User [Ngày 9]

**200**: `{ "categories": [ { "code", "name" } ], "regions": [ { "code": "VPF", "name": "Toàn quốc" } ] }` — chỉ danh mục còn món hiển thị.

---

## 10. Thực đơn

### `GET /meal-plans?date=YYYY-MM-DD` — User

Mặc định hôm nay theo múi giờ user. Chưa có thực đơn vẫn trả **200** với bữa rỗng, tổng 0 (UC07‑A1); GET không tạo dữ liệu. Thiết kế ngày 10: `23-meal-planner-design.md`.

**200**

```json
{
  "date": "2026-10-20",
  "entryCount": 1,
  "meals": {
    "BREAKFAST": [
      {
        "id": "uuid",
        "foodId": "uuid",
        "foodName": "Phở bò",
        "mealType": "BREAKFAST",
        "servingDescription": "1 bát",
        "servingSize": 500,
        "servingUnit": "g",
        "servings": 1.5,
        "kcalPerServing": 430.0,
        "proteinPerServingG": 25.0,
        "carbsPerServingG": 55.0,
        "fatPerServingG": 12.0,
        "kcal": 645.0,
        "proteinG": 37.5,
        "carbsG": 82.5,
        "fatG": 18.0,
        "dataQuality": "SOURCED",
        "createdAt": "2026-10-20T00:30:00Z"
      }
    ],
    "LUNCH": [],
    "DINNER": [],
    "SNACK": []
  },
  "mealTotals": {
    "BREAKFAST": { "kcal": 645.0, "proteinG": 37.5, "carbsG": 82.5, "fatG": 18.0 },
    "LUNCH": { "kcal": 0.0, "proteinG": 0.0, "carbsG": 0.0, "fatG": 0.0 },
    "DINNER": { "kcal": 0.0, "proteinG": 0.0, "carbsG": 0.0, "fatG": 0.0 },
    "SNACK": { "kcal": 0.0, "proteinG": 0.0, "carbsG": 0.0, "fatG": 0.0 }
  },
  "totals": { "kcal": 645.0, "proteinG": 37.5, "carbsG": 82.5, "fatG": 18.0 },
  "targets": { "kcal": 2791.6, "proteinG": 117.0, "carbsG": 406.4, "fatG": 77.5 },
  "remaining": { "kcal": 2146.6, "proteinG": 79.5, "carbsG": 323.9, "fatG": 59.5 },
  "targetsCalculatedAt": "2026-10-19T08:00:00Z"
}
```

`*PerServing*` là snapshot một khẩu phần lúc thêm; `kcal`… của mục = `servings × snapshot`. Tổng cộng ở độ chính xác lưu trữ, làm tròn HALF_UP 2 chữ số khi trả về (NUT-BR07). `servingSize`/`servingUnit` `null` khi nguồn không ghi khối lượng (docs/20 §2).
`targets`/`remaining`/`targetsCalculatedAt` là `null` khi chưa có hồ sơ (UC07‑A8). `targets` là mục tiêu **hiện tại**, kể cả khi xem ngày cũ (NUT-BR09). `remaining` âm = vượt mục tiêu (UC07‑A7).

### `POST /meal-plans/entries` — User

```json
{ "date": "2026-10-20", "mealType": "BREAKFAST", "foodId": "uuid", "servings": 1.5 }
```

**201**: toàn bộ thực đơn của ngày (cấu trúc `GET /meal-plans`), để app cập nhật tổng ngay. Mỗi lần gọi tạo một mục mới (NUT-BR08), không có khóa chống gửi lặp.
Validation: `mealType` thuộc 4 giá trị; `servings` BR-N02; `date` BR-N07 (≥ 2000-01-01, ≤ hôm nay + 7 theo múi giờ user). Các field `kcal`/macro trong body bị bỏ qua (BR-N04).
Lỗi: `400`, `404` (món không tồn tại), `422 FOOD_INACTIVE`, `422 MEAL_PLAN_LIMIT` (quá 100 mục/ngày).

### `PUT /meal-plans/entries/{id}` — User

```json
{ "servings": 2, "mealType": "LUNCH" }
```

Cả hai field tùy chọn, ít nhất một. Tính lại từ snapshot, không đọc lại món; món đã ẩn vẫn sửa được. **200**: toàn bộ thực đơn ngày. Lỗi: `400`, `404` (không tồn tại hoặc của user khác).

### `DELETE /meal-plans/entries/{id}` — User

**200**: toàn bộ thực đơn ngày sau khi xóa (không dùng 204 vì app cần tổng mới). Thực đơn vẫn còn khi hết món (BR-N06). Lỗi: `404`.

---

## 11. Dashboard

### `GET /dashboard?date=YYYY-MM-DD` — User

**200**

```json
{
  "date": "2026-10-20",
  "timezone": "Asia/Ho_Chi_Minh",
  "health": { "hasProfile": true, "weightKg": 65.0, "heightCm": 170.0, "bmi": 22.49, "goal": "GAIN_MUSCLE", "latestWeightLog": null },
  "nutrition": {
    "entryCount": 3,
    "totals": { "kcal": 645.0, "proteinG": 37.5, "carbsG": 82.5, "fatG": 18.0 },
    "targets": { "kcal": 2791.6, "proteinG": 117.0, "carbsG": 406.4, "fatG": 77.5 },
    "remaining": { "kcal": 2146.6, "proteinG": 79.5, "carbsG": 323.9, "fatG": 59.5 },
    "targetsCalculatedAt": "2026-10-19T03:00:00Z"
  },
  "training": {
    "today": [ { "scheduleId": "uuid", "scheduledDate": "2026-10-20", "startTime": "18:00", "name": "Buổi A", "programName": "Full Body", "status": "COMPLETED", "workoutLogId": "uuid" } ],
    "week": { "from": "2026-10-19", "to": "2026-10-25", "scheduled": 3, "completed": 1, "cancelled": 0 },
    "next": null
  },
  "generatedAt": "2026-10-20T05:00:00.000Z"
}
```

Tuần = thứ Hai–Chủ nhật chứa `date`. Không có dữ liệu → giá trị `null`/mảng rỗng, không lỗi. [Ngày 11, docs/25]:
- `date` mặc định hôm nay theo `users.timezone`; ngoài 2000–2099 hoặc sai định dạng → 400. Không nhận `userId`.
- `nutrition` = kết quả `GET /meal-plans?date=` (mục tiêu **hiện tại**, NUT-BR09); chưa hồ sơ → `targets`/`remaining` = `null`; `remaining` âm = vượt.
- `week.scheduled` = số lịch **không hủy** (mẫu số tiến độ); `cancelled` chỉ để hiển thị.
- `today` gồm cả lịch đã hủy. `next` = lịch SCHEDULED sớm nhất trong 30 ngày tính từ **hôm nay thực**, không theo `date`.
- `health.hasProfile=false` → các trường khác `null`. `latestWeightLog` `null` tới khi có nhật ký cân nặng (ngày 13).

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

[Ngày 12, docs/27]:
- `409 AI_REQUEST_IN_PROGRESS` cả khi hội thoại đang có **một câu khác** chờ AI (mỗi hội thoại một câu chờ).
- `409 CLIENT_REQUEST_ID_REUSED`: cùng `clientRequestId` nhưng nội dung câu hỏi (sau trim) hoặc `conversationId` khác.
- `429` có thêm `details.retryAfterSeconds` (cùng giá trị header). Giới hạn phút tính mọi lần gọi AI kể cả thử lại; giới hạn ngày chỉ tính câu hỏi mới, theo múi giờ user.
- `503 AI_DISABLED` khi `AI_ENABLED=false`: không lưu câu hỏi.
- `502 AI_EMPTY_RESPONSE` khi model trả rỗng hoặc bị bộ lọc an toàn chặn.

### `GET /ai/conversations?page=&size=` — User

Sắp xếp `lastMessageAt` giảm dần. **200**: trang `{ "id", "title", "lastMessageAt", "createdAt" }`.

### `GET /ai/conversations/{id}/messages?page=&size=` — User

Sắp xếp `createdAt` tăng dần; mặc định `size=50`. **200**: trang các phần tử

```json
{ "id": "uuid", "role": "USER", "content": "...", "createdAt": "...", "requestStatus": "FAILED", "clientRequestId": "6f1c8a1e-..." }
```

`requestStatus`/`clientRequestId` chỉ có ở tin nhắn USER, để app hiện nút "Thử lại" cho câu hỏi FAILED.
Lỗi: `404` (không tồn tại hoặc thuộc user khác — AI-BR03).

[Ngày 12] Tin USER có thêm `errorCode` (khi FAILED). Request PROCESSING quá 2 phút được chuyển `FAILED / AI_TIMEOUT` ngay khi đọc (BR-AI07). `size` tối đa: danh sách hội thoại 50 (mặc định 20), tin nhắn 100 (mặc định 50).

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

[Ngày 12] `context` thực tế có thêm `today`, `timezone`, `weekday`; `profile.status` (`READY`/`MISSING`); mỗi món trong `todayMealPlan.entries` có `dataQuality`. Lỗi trả `{ "code": "AI_TIMEOUT" | "AI_UPSTREAM_ERROR" | "AI_EMPTY_RESPONSE" }`; sai/thiếu `X-Internal-Key` → `401`, ai-service chưa cấu hình khóa → `503`; payload sai → `422` trước khi gọi provider. `GET /health` công khai. Chi tiết: docs/27 §3–5.

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
| UC03 | `/exercises`, `/exercise-filters` |
| UC04 | `/workout-programs` |
| UC05 | `/workout-schedules` |
| UC06 | `/workout-logs` |
| UC07 | `/foods`, `/meal-plans`, `/meal-plans/entries` |
| UC08 | `/weight-logs` |
| UC09 | `/dashboard` |
| UC10 | `/ai/coach/chat`, `/ai/conversations` |
| UC11 | `/auth/forgot-password`, `/auth/reset-password` |
| UC12 | `/admin/*` |
