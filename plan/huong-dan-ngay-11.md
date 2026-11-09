# VieGym — Ngày 11: Dashboard cá nhân

**Mục tiêu:** Một màn tổng quan hiển thị đúng dinh dưỡng, lịch tập, cân nặng và tiến độ cơ bản của user, cập nhật sau thao tác. **Thời gian:** 6–8 giờ. Đây là hướng dẫn triển khai, chưa xác nhận đã chạy.

## 0. Chuẩn bị — 15 phút

- [ ] GET hồ sơ ngày 5, lịch/log ngày 7–8 và Meal Planner ngày 10 chạy được.
- [ ] Đã chốt timezone và snapshot mục tiêu ngày.
- [ ] Có fixture user mới, user có đủ dữ liệu và user B riêng.

## 1. Chốt những gì dashboard hiển thị — 45 phút

Tạo `docs/24-dashboard-contract.md`. Chỉ tổng hợp chức năng đã có:

| Khối | Dữ liệu | Nguồn |
|---|---|---|
| Dinh dưỡng | Kcal đã ghi, mục tiêu ngày, còn lại, P/C/F | Meal entries + target snapshot |
| Lịch hôm nay/ngày chọn | Buổi, giờ, trạng thái | Workout schedules |
| Buổi tiếp theo | Buổi SCHEDULED trong tương lai gần | Schedules |
| Tiến độ tuần | Số lịch hoàn thành/tổng lịch không hủy | Schedules |
| Cơ thể | Cân nặng và BMI hiện tại | Health profile; ngày 13 nối weight logs |

Không tự thêm thống kê “calories đã đốt” từ reps/mức tạ vì chưa có mô hình được kiểm chứng. AI ngày 12 chưa có thì chỉ để lối vào hoặc trạng thái chưa khả dụng, không tạo gợi ý giả như phản hồi thật.

Chốt mẫu số tiến độ tuần: tất cả lịch thuộc tuần không CANCELLED; tử số là các lịch đó đã COMPLETED. Không chia cho 0; tổng=0 thì progress=null và UI “Chưa có lịch”. Nếu log nhập muộn, completion tính theo ngày lịch, còn lịch sử buổi thực tế theo performedAt; giải thích trong contract.

## 2. API tổng hợp — 45 phút

```http
GET /api/v1/dashboard?date=2026-11-03
Authorization: Bearer <access-token>
```

Date tùy chọn, mặc định hôm nay theo timezone profile. Không nhận userId. Trả JSON ổn định:

```json
{
  "date": "2026-11-03",
  "timezone": "Asia/Ho_Chi_Minh",
  "profileStatus": "READY",
  "nutrition": {
    "consumedCalories": 500,
    "targetCalories": 2000,
    "remainingCalories": 1500,
    "proteinGrams": 25,
    "carbGrams": 75,
    "fatGrams": 10,
    "targetSource": "SNAPSHOT"
  },
  "workouts": {
    "today": [], "next": null,
    "weeklyCompleted": 2, "weeklyScheduled": 3
  },
  "body": {"weightKg": 70, "bmi": 22.86},
  "generatedAt": "<server-timestamp>"
}
```

Số liệu minh họa chỉ dùng fixture. Nếu target unavailable/null thì remaining=null. Nếu chưa profile, body=null/profileStatus=MISSING; vẫn có thể trả dữ liệu các module dùng được. GET không tự tạo meal plan hoặc sửa mục tiêu.

## 3. Backend aggregation — 60–90 phút

Tạo DashboardController/Service/Response. Service dùng lại phép tính và query của các module, không copy ba phiên bản công thức.

1. Lấy user/timezone và xác định đầu ngày/tuần bằng khoảng nửa mở.
2. Tổng hợp meal entries theo date; snapshot target ưu tiên nếu đã có plan, preview hiện tại nếu chưa.
3. Đọc lịch ngày và thống kê tuần theo quy tắc.
4. Tìm next trong khoảng rõ ràng, ví dụ 30 ngày từ hiện tại; nếu đang xem ngày quá khứ thì field next vẫn theo hiện tại và tên/contract ghi rõ.
5. Đọc hồ sơ cùng snapshot kết quả đang hiệu lực.
6. Trả một response nhất quán ở mức đã chọn. Nếu cần cùng snapshot database cho nhiều query, dùng read-only transaction isolation phù hợp và test; transaction mặc định không tự bảo đảm mọi query đọc cùng thời điểm.

Không join food entries và workout sets rồi SUM trực tiếp vì quan hệ nhiều-nhiều qua user có thể nhân số dòng và đếm gấp nhiều lần. Tổng hợp riêng từng nhóm trước khi ghép.

Chưa thêm cache; với dữ liệu MVP ưu tiên query có user/date index. Nếu cache đã tồn tại, key phải gồm user/date/timezone và invalidation sau cập nhật; tuyệt đối không dùng key chung cho mọi tài khoản.

- [ ] Không lặp công thức ngày 5/10.
- [ ] Không đếm trùng do join.
- [ ] Dữ liệu null có ý nghĩa đúng.

## 4. Flutter layout và trạng thái — 90 phút

Tạo `features/dashboard/{data,application,presentation}`:

1. Thẻ kcal lớn, macro bên dưới, lịch hôm nay, cân nặng và tiến độ tuần.
2. Dùng số server trả, đơn vị rõ ràng.
3. Progress bar có thể giới hạn chiều dài hiển thị, nhưng số vượt mục tiêu vẫn hiện đúng.
4. Thiếu profile có nút hoàn thiện; chưa ăn có nút thêm món; chưa lịch có nút tạo lịch.
5. Nhấn thẻ dẫn tới đúng màn/date/scheduleId.
6. Pull-to-refresh và retry; hiển thị trạng thái stale nếu giữ dữ liệu cũ khi mất mạng.
7. Không kéo dài loading vì một animation hoặc ảnh hỏng.

Không hiển thị “Bạn chưa ăn” từ dữ liệu chưa ghi; dùng “Chưa ghi nhận bữa ăn”. Không diễn giải giá trị BMI thành chẩn đoán.

## 5. Làm mới sau thao tác — 45 phút

Invalidate dashboard provider sau thêm/sửa/xóa meal entry, hoàn thành workout, sửa profile, sửa/hủy lịch. Key theo user/date; hủy/ignore request phiên cũ khi logout.

Luồng kiểm tra: thêm món ở bữa trưa → back dashboard thấy tổng mới; hoàn thành lịch → số hoàn thành tăng; đổi user A sang B → không flash dữ liệu A. Khi đang xem ngày khác, cập nhật đúng ngày bị ảnh hưởng, không ghi response nhầm tab.

## 6. Test và đo cơ bản — 60 phút

| Mã | Test | Expected |
|---|---|---|
| D01 | User mới | CTA phù hợp, không null crash |
| D02 | Fixture ngày 10 | Kcal500/P25/C75/F10 |
| D03 | Tuần 3 lịch, 2 completed, 1 cancelled bổ sung | 2/3, không 2/4 |
| D04 | Không lịch | Không chia 0 |
| D05 | Target unavailable | Không mục tiêu 0 giả |
| D06 | Thêm món/hoàn thành workout | Dữ liệu refresh đúng |
| D07 | A/B và đổi tài khoản | Không lộ cache |
| D08 | Gần ranh giới tuần | Đúng timezone |
| D09 | Join nhiều món/nhiều set | Không nhân tổng |

Đo thời gian API trên dữ liệu fixture và ghi cấu hình máy/số mẫu, không tuyên bố đạt P95 SRS chỉ từ một request. Đợt đo chuẩn làm ngày 16. Ghi `docs/25-day-11-verification.md`.

## 7. Lỗi thường gặp và đóng ngày

Kcal gấp đôi: kiểm tra join. Tiến độ sai: kiểm tra CANCELLED và mẫu số. Ngày sai: kiểm tra UTC/timezone. UI cũ: kiểm tra provider key/invalidation. Null crash: kiểm tra model nullable.

- [ ] Dashboard hiển thị dữ liệu thật.
- [ ] Null/rỗng/vượt mục tiêu rõ ràng.
- [ ] Điều hướng và refresh sau ghi hoạt động.
- [ ] Có test A/B và fixture tổng hợp.
- [ ] Commit: `feat: add personal dashboard aggregation`.

Nhật ký: dữ liệu đã nối, kết quả fixture, cache/invalidation, latency quan sát, lỗi, commit. Ngày 12 tích hợp chatbot theo context này.
