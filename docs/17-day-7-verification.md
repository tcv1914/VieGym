# Kiểm tra ngày 7 — giáo án và lịch tập

Thiết kế: `16-workout-program-schedule-design.md`. Ngày kiểm tra: 2026-11-02.

## 1. Môi trường

Như ngày 4–6 (`10-day-4-verification.md` §1). Flyway local: **V6 `create workout programs and schedules`**, **V7 `seed workout templates`** áp dụng thành công (DB lên v7). App cài bản debug qua `adb install`, gọi backend qua `adb reverse tcp:8080 tcp:8080`.

## 2. Kiểm thử tự động

| Phần | Lệnh | Kết quả |
|---|---|---|
| Backend | `.\mvnw.cmd test` (PostgreSQL thật) | 74/74 đạt (18 test mới: `WorkoutProgramIntegrationTests` 9, `WorkoutScheduleIntegrationTests` 9) |
| Mobile | `flutter analyze` | No issues found |
| Mobile | `flutter test` | 40/40 đạt (13 test mới trong `test/workout_test.dart`) |

Test widget phát hiện và đã sửa một lỗi: form có thay đổi nhưng `PopScope.canPop` chưa cập nhật (cờ `_dirty` đổi không qua `setState`) nên bấm Back thoát mà không hỏi.

## 3. Bộ nghiệm thu plan ngày 7

| Mã | Tình huống | Bằng chứng | Kết quả |
|---|---|---|---|
| W01 | 2 buổi, mỗi buổi 2 bài, đọc lại đúng thứ tự | `customProgramKeepsOrderAndValues`; test tay bước 5 | Đạt |
| W02 | Dùng mẫu rồi sửa bản cá nhân, mẫu không đổi | `templateCopyIsIndependent`; test tay bước 2 | Đạt |
| W03 | Buổi rỗng/bài trùng/sets sai → 400, rollback | `invalidContentIsRejectedWithoutSaving`; widget test; test tay bước 4 | Đạt |
| W04 | Bài inactive/ID lạ → từ chối, không lưu một phần | `inactiveOrUnknownExerciseIsRejected`, `templateWithHiddenExerciseCannotBeCopied` | Đạt (422 `EXERCISE_INACTIVE`) |
| W05 | A đọc/sửa/activate giáo án B → 404 | `otherUsersProgramIsInvisible`; smoke API; test tay bước 12 | Đạt |
| W06 | Hai lần activate đồng thời | `concurrentActivationLeavesOneActive`; DB: tối đa 1 active/user | Đạt |
| W07 | Xếp lịch từ buổi của giáo án khác | `otherUsersDaysAndSchedulesAreInvisible`; smoke API (B → 404) | Đạt |
| W08 | Xếp lịch rồi sửa giáo án | `removingScheduledDayArchivesIt` | Theo BR-W07: buổi bị gỡ được archive, lịch giữ và tập được; sửa bài của buổi áp cho lịch chưa tập (không snapshot — docs/16 §1) |
| W09 | Xếp lịch với revision cũ | — | Không áp dụng: lịch không nhận version giáo án (docs/16 §1) |
| W10 | Lịch sát đầu/cuối tuần | `weekBoundariesAreInclusive`, unit test `weekStart`; test tay bước 7–9 | Đạt (khoảng ngày đóng, không có giờ UTC) |
| W11 | B sửa giờ/hủy lịch của A | `otherUsersDaysAndSchedulesAreInvisible` | Đạt (404) |
| W12 | Hai màn sửa cùng version | `staleVersionIsRejected`; widget test 409; smoke API | Đạt (409 `VERSION_CONFLICT`, app hỏi tải bản mới) |
| W13 | Idempotency-Key | — | **Chưa làm**; app không tự retry POST, lỗi mạng nhắc tải lại kiểm tra (docs/16 §6) |
| W14 | Hủy lại lịch đã hủy | `rescheduleCancelAndFinalStates`; smoke API | Đạt (409 `INVALID_STATE`, dữ liệu không đổi) |
| W15 | MISSED đồng thời với hoàn thành | Thiết kế | Không có ghi MISSED phía server nên không thể ghi đè COMPLETED; kiểm tra runtime khi có luồng log ngày 8 |
| W16 | Quay lại/đổi tuần/mất mạng | Widget test lịch tuần; test tay bước 9 | Đạt; mất mạng hiện lỗi + "Thử lại" |

## 4. Smoke API (backend local, tài khoản phonea/phoneb)

```text
templates 200 [ 'Full Body cơ bản — 3 buổi/3', 'Thân trên / Thân dưới — 4 buổi/4' ]
copy 201 Full Body cơ bản — 3 buổi v0 3 buổi
activate 200 true
B reads A program 404 NOT_FOUND
schedule 201 2026-11-03 18:00 SCHEDULED 5 bài
B schedules A day 404
stale version (v1 current, sent v0) 409 VERSION_CONFLICT
week 200 2026-11-02 2026-11-08 1
cancel 200 CANCELLED
cancel again 409 INVALID_STATE
```

Dữ liệu smoke đã xóa trước khi test tay.

## 5. Test tay trên Android

User tự thao tác 12 bước (danh sách giáo án rỗng → dùng mẫu → kích hoạt → tự tạo có lỗi số hiệp → lưu 2 buổi, đổi thứ tự → hỏi khi rời form → lịch tuần, hôm nay → xếp lịch → chuyển tuần → dời → hủy → đổi sang tài khoản B): **đạt 12/12**.

Dữ liệu server sau test:

```text
 email            | name                      | is_active | version | from_template | days
 phonea@viegym.vn | Full Body cơ bản — 3 buổi | t         | 1       | t             | 3
 phonea@viegym.vn | giáo án 1                 | f         | 0       | f             | 2

 email            | scheduled_date | start_time | status    | day
 phonea@viegym.vn | 2026-11-05     |            | CANCELLED | Buổi A
```

- Một giáo án active/user; bản sao có `source_template_id`; bỏ sửa ở bước 6 không đổi version.
- Chỉ còn một lịch (đã dời sang 05/11 rồi hủy, không đặt giờ); lịch tuần sau ở bước 9 không có trong DB. phoneb không có dữ liệu.

## 6. Giới hạn, chuyển sang ngày sau

Xem `16-workout-program-schedule-design.md` §6. Ngày 8: ghi log từng set, chuyển lịch sang COMPLETED trong cùng giao dịch, kiểm tra W15 bằng runtime.
