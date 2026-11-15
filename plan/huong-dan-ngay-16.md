# VieGym — Ngày 16: Kiểm thử chức năng, tính toán và API

**Mục tiêu:** Có bằng chứng các nghiệp vụ chính đúng, sửa lỗi có tái kiểm tra. **Thời lượng:** 7–8 giờ.

## 0. Chuẩn bị môi trường — 30 phút

- [ ] Chốt commit/build cần kiểm thử và bản schema migration.
- [ ] Database test riêng, reset được bằng dữ liệu fixture.
- [ ] Không dùng provider/email thật cho tất cả test tự động.
- [ ] Có đồng hồ cố định trong test ngày/TTL/timezone.

Tạo `docs/34-test-plan.md` và `docs/35-day-16-results.md`. Mỗi case có ID, yêu cầu liên quan, setup, input, expected, actual, PASS/FAIL/BLOCKED/NOT_RUN và evidence. Không mặc định PASS vì chưa thấy lỗi.

## 1. Kiểm thử công thức bằng kết quả độc lập — 75 phút

Đặt fixture: 70 kg, 175 cm, 25 tuổi, phương trình MALE, activity 1,2, maintain. Theo chính sách demo ngày 5:

```text
BMI = 70 / 1,75² = 22,857142... → 22,86
BMR = 10×70 + 6,25×175 − 5×25 + 5 = 1673,75
TDEE = 1673,75 × 1,2 = 2008,50 kcal
Protein = 2008,50 × 0,25 / 4 = 125,53125 g
Fat = 2008,50 × 0,25 / 9 = 55,791666... g
Carb = 2008,50 × 0,50 / 4 = 251,0625 g
```

Chốt chính xác điểm làm tròn trước khi viết assertion. Đề xuất giữ độ chính xác nội bộ, chỉ làm tròn đầu ra theo contract. Nếu hệ thống đã quy định làm tròn target trước macro, expected phải theo đúng quy định đó và được ghi rõ. Những tỷ lệ này là chính sách demo đã chọn, không phải khuyến cáo sức khỏe.

Test thêm: phương trình FEMALE, UNSPECIFIED, input thiếu/âm, ngày sinh trong tương lai, sinh nhật ở ranh giới ngày, activity không thuộc enum. UNSPECIFIED không được trả target 0 hoặc giữ target cũ.

Fixture meal ngày 10: A 200 kcal/P10/C30/F4 ×1,5 + B 100/P5/C15/F2 ×2 = 500 kcal/P25/C75/F10. Tổng từ snapshot phải giữ nguyên sau khi admin sửa catalog.

## 2. Test nghiệp vụ và transaction — 120 phút

| Nhóm | Ca bắt buộc |
|---|---|
| Auth | Login đúng/sai, refresh rotation, token cũ, logout revoke |
| Giáo án/lịch | Copy template độc lập, một active program, snapshot không đổi |
| Workout | Log hợp lệ, future timestamp, hủy rồi log, replay cùng/khác payload |
| Meal | Servings thập phân, trùng key, sửa revision cũ, snapshot nguồn |
| Dashboard | Không join nhân tổng, mẫu số bỏ cancelled, zero/null |
| Weight | Sửa/xóa điểm mới nhất, target hiện tại và snapshot cũ |
| Reset | Token một lần dùng, hết hạn, session cũ mất hiệu lực |

Với rollback, tạo lỗi có kiểm soát giữa quá trình ghi log: sau lỗi không còn log dở và lịch chưa COMPLETED. Test race hai request cùng schedule: chỉ có một log. Test cạnh tranh cancel/log: kết quả phù hợp thứ tự khóa và trạng thái cuối, không có CANCELLED kèm log hoàn tất trái quy tắc.

Các case phụ thuộc unique constraint, locking và SQL nên chạy với PostgreSQL test cùng major version triển khai. Database in-memory có thể không mô phỏng đúng hành vi.

## 3. Test API và hợp đồng — 60 phút

Tạo collection hoặc test tích hợp dùng biến môi trường, không hardcode token. Kiểm tra status, cấu trúc response, kiểu số/ngày, pagination và mã lỗi nghiệp vụ.

Thử payload thiếu field, field thừa nguy hiểm như userId/role, enum sai, độ dài lớn, size vượt giới hạn, ngày không hợp lệ. Đảm bảo input không hợp lệ không tạo dữ liệu một phần.

Lệnh minh họa khi repository có đúng wrapper/scripts:

```powershell
# Chạy ở thư mục backend, với test profile dùng DB riêng
.\mvnw.cmd test

# Chạy ở thư mục Flutter
flutter analyze
flutter test
```

Đọc scripts thực tế trước khi chạy frontend/FastAPI tests; không ghi một lệnh đã thành công nếu project chưa có test tương ứng. Không chạy test phá dữ liệu trên staging dùng để demo.

## 4. Đo hiệu năng có kiểm soát — 60 phút

Chọn login, food search, dashboard, history và một API ghi. AI đo riêng vì phụ thuộc provider. Ghi cấu hình máy/host, số dòng dữ liệu, commit, cache, warm-up, số request và mức đồng thời.

Thực hiện lượt nhỏ trước để kiểm tra dữ liệu, sau đó chạy mức tải phù hợp SRS và khả năng môi trường. Thu p50/p95, tỷ lệ lỗi, throughput; không suy ra tải sản xuất từ vài request trên laptop. Nếu không đủ công cụ/thời gian, báo kết quả là quan sát latency thủ công, không gọi là load test.

Nếu chậm, kiểm tra query count/N+1, index theo điều kiện lọc và pagination trước khi thêm cache. Mỗi thay đổi hiệu năng phải chạy lại test đúng nghiệp vụ liên quan.

## 5. Sửa lỗi và retest — 90 phút

1. Ưu tiên P0/P1 rồi lỗi phép tính/snapshot.
2. Viết regression test cho lỗi nghiệp vụ có thể tái phát.
3. Sửa tối thiểu, chạy case lỗi và nhóm test chịu ảnh hưởng.
4. Đính kèm commit sửa và kết quả mới; giữ kết quả FAIL cũ để có lịch sử.
5. Không thêm test chỉ lặp lại implementation mà không kiểm tra hành vi.

## 6. Checklist đóng ngày

- [ ] Công thức được đối chiếu với expected độc lập.
- [ ] Có kiểm thử replay, race và rollback trên PostgreSQL.
- [ ] Có kết quả API, validation, pagination và mã lỗi.
- [ ] Lỗi đã sửa được retest, test chưa chạy ghi NOT_RUN.
- [ ] Số liệu hiệu năng có điều kiện đo và giới hạn rõ ràng.
- [ ] Ghi tổng PASS/FAIL/BLOCKED/NOT_RUN từ dữ liệu thực.
- [ ] Commit gợi ý: `test: cover core business rules and fix regressions`.

Ngày 17 tập trung phân quyền, dữ liệu cá nhân và chất lượng AI.
