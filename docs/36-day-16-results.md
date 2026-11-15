# Kết quả kiểm thử — ngày 16 (2026-11-15)

Plan gọi file này là `docs/35-day-16-results.md` (số docs lệch +1). Kế hoạch: `35-test-plan.md`.

## 1. Tổng hợp

| Bộ | PASS | FAIL | BLOCKED | NOT_RUN | Ghi chú |
|---|---:|---:|---:|---:|---|
| Backend (JUnit + Testcontainers PG 17) | 169 | 0 | 0 | 0 | +2 so với ngày 15: T-F01, T-D01 |
| Mobile (`flutter test`) | 115 | 0 | 0 | 0 | `flutter analyze`: không có lỗi |
| Admin (Vitest) | 7 | 0 | 0 | 0 | |
| ai-service (pytest) | 15 | 0 | 0 | 0 | provider giả |
| Công thức độc lập (`qa/formula_oracle.py`, STAGING) | 309 | 0 | 0 | 0 | 9 ca cố định + 300 ngẫu nhiên, seed 16 |
| Hợp đồng API (`qa/api_contract.py`, STAGING) | 58 | 0 | 0 | 0 | lần chạy đầu 57/58, xem §3 |
| Hành trình (`infra/staging/journey_smoke.py`) | 39 | 0 | 0 | 0 | từ ngày 15 |
| Test tay Android/admin (docs/34 §4, docs/32 §5, docs/26 §5) | — | — | — | 43 bước | chuyển sang ngày 18 |

Môi trường: build commit `a1d1573` + thay đổi ngày 16. STAGING ở `127.0.0.1:18080` (docs/34 §3), Windows 11, 16 CPU logic, Docker Desktop 29.9 cấp 8 GB RAM. Các script đã chạy lại sau khi sửa và đều đạt.

## 2. Công thức

Bộ tính độc lập dùng `fractions.Fraction` (chính xác tuyệt đối) và HALF_UP ở bước cuối, viết lại từ docs/11. Nó không dịch từ `HealthCalculator.java`, vốn dùng `BigDecimal` DECIMAL64. Bộ tính khớp backend ở **mọi** trường của 309 hồ sơ. Không có ca nào lệch do cắt ở chữ số thứ 16.

| Ca | BMI | BMR | TDEE | Mục tiêu | P / C / F | Ngưỡng |
|---|---:|---:|---:|---:|---|---|
| Fixture plan (nam 25t, 175/70, SEDENTARY, MAINTAIN) | 22,86 | 1673,8 | 2008,5 | 2008,5 | 112,0 / 264,6 / 55,8 | không |
| Demo docs/04 ca 1 | 22,49 | 1607,5 | 2491,6 | 2791,6 | 117,0 / 406,4 / 77,5 | không |
| Trần protein | 300,00 | 3064,0 | 3676,8 | 3176,8 | 278,0 / 317,7 / 88,2 | không |
| Ngưỡng nữ | 17,78 | 776,5 | 931,8 | 1200,0 | 80,0 / 145,0 / 33,3 | có |
| Ngưỡng nam (carbs 181,25 → 181,3) | 19,53 | 1355,0 | 1626,0 | 1500,0 | 100,0 / 181,3 / 41,7 | có |
| Sinh nhật 18 đúng hôm nay | 19,53 | 1249,0 | 1717,4 | 1717,4 | 80,0 / 242,0 / 47,7 | không |
| Sinh nhật 80 đúng hôm nay | 20,76 | 1267,5 | 2408,3 | 2708,3 | 108,0 / 399,8 / 75,2 | không |
| Biên trên 250 cm / 300 kg | 48,00 | 4367,5 | 8298,3 | 8598,3 | 540,0 / 1072,2 / 238,8 | không |
| Biên dưới 100 cm / 30 kg | 30,00 | 514,0 | 616,8 | 1200,0 | 60,0 / 165,0 / 33,3 | có |

Plan dùng chính sách demo 25/50/25 (P 125,53 / C 251,06 / F 55,79). Dự án theo docs/11 (quyết định ngày 2), nên expected là P 112,0 / C 264,6 / F 55,8. BMI, BMR và TDEE trùng với plan. Plan ghi BMR 1673,75, dự án làm tròn 1 chữ số HALF_UP thành 1673,8. TDEE tính từ BMR **chưa làm tròn** nên ra 2008,5.

Input sai (T-F07, C11–C19):
- 8 kiểu sai đều trả 400 với `fieldErrors` đúng trường: chiều cao 99,9, cân 300,1, âm, enum `HIGH`/`UNSPECIFIED`, tháng 13, ngày sinh tương lai, thiếu `goal`;
- sau đó `GET` vẫn 404, tức không có hồ sơ hay target 0 nào được ghi.

## 3. Hợp đồng API

58/58 sau khi sửa. Các nhóm đã kiểm (chi tiết ở test plan §3):
- body lỗi chuẩn ở mọi ca lỗi, không lộ tên lớp, SQL hay stack;
- phân trang `/foods`: đi hết 10 trang ×100 = 912 món, không trùng, không thiếu; trang cuối `hasNext=false`; quá trang thì `items` rỗng; `size=101` và `page=-1` → 400;
- field nguy hiểm `role`, `id`, `userId`, `targetKcal`, `bmi`, `kcal`, `proteinG` và `userId` trên query dashboard đều bị bỏ qua;
- sau input sai **không có dữ liệu ghi dở** ở hồ sơ, thực đơn, workout log/lịch và hội thoại AI;
- replay workout khác payload → 409 kèm `workoutLogId`, log cũ giữ nguyên `note`.

| Lần | Ca | Kết quả | Nguyên nhân | Xử lý |
|---|---|---|---|---|
| 1 (21:01) | C53 "chỉ gửi `from` → 400" | **FAIL** (200, `items` rỗng) | Expected sai. Quy tắc "chỉ gửi một → 400" là của `/workout-schedules`. docs/05 §4 chỉ quy định `from > to` hoặc khoảng quá dài → 400; gửi một mình `from` thì backend lấy 90 ngày từ `from` | Sửa ca thành `from > to` → 400 `fieldErrors.from` |
| 2 (21:01) | C53 | PASS | | |

## 4. Nghiệp vụ và transaction

Mọi ca bắt buộc ở plan §2 đều có test trên PostgreSQL 17 (bảng ở test plan §2), và đều PASS trong 169/169:
- rollback giữa chừng: `failureMidwayRollsBackEverything`;
- race cùng lịch: `concurrentLogsCreateOne`;
- cancel/log cạnh tranh: `cancelAndCompleteRace`;
- replay: `resendReturnsExistingLog`;
- refresh đồng thời: `concurrentRefreshWithSameTokenSucceedsOnce`;
- reset đồng thời: `concurrentResetsWithSameCodeSucceedOnce`;
- admin sửa đồng thời: `concurrentEditsWithSameRevisionSucceedOnce`.

Thêm ngày 16:
- **T-F01** `HealthCalculatorTest.planDay16FixtureMaleMaintain`: fixture của plan, expected tính tay theo docs/11.
- **T-D01** `UserDayBoundaryIntegrationTests.todayFollowsUserTimezoneAcrossMidnight`: đồng hồ cố định ở 23:59:59 và 00:00:00 giờ VN. Ở cả hai mốc ngày UTC vẫn là hôm trước, nên test phân biệt được múi giờ user với UTC. Kết quả kiểm: ngày mặc định của thực đơn và dashboard; cân ngày mai bị từ chối lúc 23:59:59 nhưng nhận lúc 00:00:00; lịch cho "hôm qua theo giờ VN" bị từ chối dù UTC vẫn là ngày đó. Trước đây chưa test nào chạm được ranh giới này, vì "hôm nay" lấy theo giờ máy. Lần chạy đầu hỏng một assertion: dashboard của user chưa có hồ sơ trả `latestWeightLog = null`, đúng docs/05 §11. Đã bỏ assertion đó; backend không có lỗi.

Không áp dụng (theo quyết định ngày 2, không phải bỏ sót):
- meal "trùng key" và "sửa revision cũ": NUT-BR08, docs/23 §6;
- "snapshot giáo án": docs/16 §1, lịch trỏ buổi + archive;
- `UNSPECIFIED`: `sex` bắt buộc MALE/FEMALE.

## 5. Hiệu năng (quan sát latency, không phải load test)

Điều kiện đo:
- `qa/latency.py` chạy lúc 21:05 trên STAGING, cùng máy với client, gọi qua `127.0.0.1` (Docker Desktop port-forward);
- dữ liệu: 1 user, 42 mục thực đơn trong 7 ngày, 5 buổi tập × 5 bài × 3 hiệp; toàn DB có 912 món và 32 bài tập đang hiển thị;
- không cache ứng dụng; mỗi dòng warm-up 10 request; Python `urllib`, mỗi request mở một kết nối mới.

| Endpoint | Đồng thời | Request | p50 ms | p95 ms | max ms | Lỗi | req/s |
|---|---:|---:|---:|---:|---:|---:|---:|
| POST /auth/login (BCrypt) | 1 | 50 | 131 | 156 | 168 | 0% | 8 |
| POST /auth/login (BCrypt) | 10 | 50 | 136 | 217 | 264 | 0% | 60 |
| GET /foods?keyword=com | 1 | 200 | 15 | 41 | 72 | 0% | 48 |
| GET /foods?keyword=com | 10 | 200 | 21 | 53 | 105 | 0% | 370 |
| GET /dashboard | 1 | 200 | 17 | 39 | 77 | 0% | 47 |
| GET /dashboard | 10 | 200 | 21 | 47 | 78 | 0% | 358 |
| GET /workout-logs | 1 | 200 | 9 | 30 | 37 | 0% | 79 |
| GET /workout-logs | 10 | 200 | 16 | 50 | 102 | 0% | 418 |
| GET /meal-plans | 1 | 200 | 8 | 31 | 48 | 0% | 83 |
| GET /meal-plans | 10 | 200 | 14 | 30 | 39 | 0% | 585 |
| POST /weight-logs (ghi) | 1 | 200 | 9 | 33 | 38 | 0% | 79 |
| POST /weight-logs (ghi) | 10 | 200 | 16 | 36 | 56 | 0% | 517 |

AI: 3 lượt trong smoke ngày 15 mất 1,9–2,3 s (Gemini `gemini-2.5-flash`). Chưa đo có hệ thống vì provider có hạn mức và giới hạn 5 câu/phút.

Nhận xét:
- Mọi API đọc/ghi có p95 dưới 110 ms ở mức 10 đồng thời, còn xa mục tiêu tự đặt 1 s và timeout 10 s của app.
- Login chậm hơn là có chủ ý (BCrypt).
- Không thấy dấu hiệu N+1: dashboard tổng hợp 4 nguồn vẫn ~20 ms. Chưa đếm query trực tiếp.
- Không thêm cache hay index.
- Số liệu này **không** suy ra được tải sản xuất: chỉ 1 user, client và server cùng máy, không có mạng thật.

## 6. Lỗi và retest

Không tìm thấy lỗi nghiệp vụ mới. Cả 3 lần FAIL trong ngày đều do expected của script/test sai và đã ghi ở trên:
- C53;
- T-D01 lần đầu;
- bước 6 của journey (ngày 15).

Backlog vẫn như docs/33 §2. Không có P0/P1 cho demo nội bộ. BUG-01 (giới hạn tần suất login) làm ở ngày 17.

## 7. Checklist

- [x] Công thức đối chiếu với expected độc lập (309/309 + unit test tính tay).
- [x] Replay, race, rollback trên PostgreSQL 17.
- [x] API, validation, phân trang, mã lỗi (58/58).
- [x] Lỗi script đã retest. Test tay ghi NOT_RUN.
- [x] Hiệu năng có điều kiện đo và giới hạn rõ.
- [x] Tổng PASS/FAIL/BLOCKED/NOT_RUN lấy từ lần chạy thực.
