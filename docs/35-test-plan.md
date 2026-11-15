# Kế hoạch kiểm thử — ngày 16

Plan gọi file này là `docs/34-test-plan.md`. Số docs lệch +1 (docs/34 là báo cáo ngày 15). Kết quả nằm ở `36-day-16-results.md`.

## 0. Môi trường và đối tượng kiểm thử

| Mục | Giá trị |
|---|---|
| Build | commit `a1d1573` (ngày 15) + thay đổi ngày 16; schema Flyway V1–V14 |
| Test tự động backend | Testcontainers PostgreSQL 17, cùng major version với DEV/STAGING. DB tạo mới mỗi lần chạy, seed bằng migration, mỗi test tự tạo tài khoản riêng. Không chạm DEV/STAGING |
| Provider/email trong test tự động | Không dùng thật. AI dùng stub HTTP (`AiCoachIntegrationTests`, `HttpAiClientTest`); pytest dùng provider giả; email dùng `ResetCodeDelivery` giả |
| Đồng hồ | Backend inject `Clock`. Trước ngày 16, test ngày dùng ngày cố định (`weekBoundaryAndUserTimezone`) hoặc "hôm nay" theo giờ máy. TTL được kiểm bằng cách sửa `expires_at` trong DB (`expiredCodeIsRejected`). **Ngày 16 thêm** `UserDayBoundaryIntegrationTests` với Clock cố định ở 23:59:59 và 00:00:00 giờ VN (T-D01) |
| Script trên môi trường chạy | `qa/*.py` và `infra/staging/journey_smoke.py`, chạy trên STAGING (`127.0.0.1:18080`). Mỗi lần chạy tự tạo tài khoản `*.<thời điểm>@staging.viegym.vn`. Không chạy trên dữ liệu demo |

Trạng thái: PASS / FAIL / BLOCKED / NOT_RUN. Một ca chưa chạy thì ghi NOT_RUN, không coi là PASS.

## 1. Công thức (T-F)

Quy tắc áp dụng là docs/11 (quyết định ngày 2), **không phải** chính sách demo 25/50/25 của plan. Expected tính lại theo docs/11 và ghi rõ trong từng ca.

| ID | Yêu cầu | Setup / input | Expected | Evidence |
|---|---|---|---|---|
| T-F01 | docs/11 §3–4 | Fixture plan: nam 25 tuổi (sinh nhật hôm nay), 175 cm, 70 kg, SEDENTARY, MAINTAIN | BMI 22,86; BMR 1673,8; TDEE 2008,5; mục tiêu 2008,5; P 112,0 / C 264,6 / F 55,8 | `HealthCalculatorTest.planDay16FixtureMaleMaintain`, `qa/formula_oracle.py` |
| T-F02 | §3 nữ | Ca trần protein, ngưỡng nữ 1200 | như docs/11 §5 | `proteinCapCaseFemaleLoseWeight`, `femaleTargetRaisedToFloor`, oracle |
| T-F03 | §3 ngưỡng nam, HALF_UP | Nam 30t 160/50 | carbs 181,25 → 181,3 | `maleTargetRaisedToFloorAndCarbsRoundHalfUp`, oracle |
| T-F04 | 5 hệ số vận động | Nam 30t 180/80 | TDEE từng mức | `HealthCalculatorTest` (parameterized) |
| T-F05 | Độc lập với code | 300 hồ sơ ngẫu nhiên (seed 16) + 9 ca cố định, tính bằng phân số chính xác, HALF_UP ở bước cuối | Khớp mọi trường `targets` và `age` | `qa/formula_oracle.py` |
| T-F06 | Tuổi ở ranh giới | Sinh nhật 18 và 80 tuổi đúng hôm nay; 18 tuổi thiếu 1 ngày; 81 tuổi | 18/80 được nhận; 17/81 → 400 | `ageBoundariesAreAccepted`, `invalidValuesAre…`, oracle |
| T-F07 | Input sai | Thiếu, âm, ngày sinh tương lai, enum lạ (`HIGH`, `UNSPECIFIED`) | 400 `fieldErrors`; hồ sơ/mục tiêu cũ giữ nguyên, không có target 0 | `invalidValuesAreRejectedWithoutChangingSavedProfile`, `unknownEnumOrBadDateReturnsFieldError`, `qa/api_contract.py` C11–C19 |
| T-F08 | UNSPECIFIED | Không áp dụng: `sex` chỉ có MALE/FEMALE và bắt buộc (docs/11 §2). Gửi `UNSPECIFIED` → 400 | 400, không trả target | C15 |
| T-F09 | Meal fixture | A 200/10/30/4 × 1,5 + B 100/5/15/2 × 2 | 500 / 25 / 75 / 10 | `MealNutritionTest.fixtureFromPlan`, `MealPlanIntegrationTests.fixtureAddUpdateDelete` |
| T-F10 | Snapshot | Admin sửa/ẩn món sau khi thêm vào bữa | Tổng thực đơn không đổi | `foodEditDoesNotChangeEntries`, `deactivatedFoodKeepsMealSnapshots`, journey 6.4 |

## 2. Nghiệp vụ và transaction (T-B)

| ID | Nhóm | Ca bắt buộc của plan | Evidence (PostgreSQL Testcontainers) |
|---|---|---|---|
| T-B01 | Auth | Login đúng/sai, refresh rotation, token cũ, logout revoke | `loginReturnsTokens…`, `wrongPasswordAndUnknownEmailGiveSameError`, `refreshRotatesAndReuseRevokesSessions`, `concurrentRefreshWithSameTokenSucceedsOnce`, `logoutRevokesOnlyCurrentSession`, `forgedExpiredOrForeignTokensAreRejected` |
| T-B02 | Giáo án/lịch | Copy template độc lập, một active program | `templateCopyIsIndependent`, `concurrentActivationLeavesOneActive`, `staleVersionIsRejected`. "Snapshot không đổi": theo docs/16 §1, lịch trỏ `workout_day` + archive (`removingScheduledDayArchivesIt`), không snapshot |
| T-B03 | Workout | Log hợp lệ, future timestamp, hủy rồi log, replay cùng/khác payload | `logFixtureCompletesSchedule`, `invalidPayloadsAreRejected`, `cancelledAndFutureSchedulesAreRejected`, `resendReturnsExistingLog`; C42, C47 |
| T-B04 | Rollback | Lỗi có kiểm soát giữa lúc ghi | `failureMidwayRollsBackEverything` (trigger chặn hiệp thứ 2): không có log dở, lịch vẫn SCHEDULED |
| T-B05 | Race | Hai request cùng lịch; cancel và log cạnh tranh | `concurrentLogsCreateOne`, `cancelAndCompleteRace` (không có CANCELLED kèm log) |
| T-B06 | Meal | Servings thập phân, snapshot nguồn | `fixtureAddUpdateDelete`, `eachAddIsSeparateEntryAndClientNutritionIgnored`, `concurrentFirstAddCreatesOnePlan`. **"Trùng key" và "sửa revision cũ": không áp dụng.** NUT-BR08 quy định mỗi lần thêm là một mục, không có khóa chống lặp hay revision (docs/23 §6) |
| T-B07 | Dashboard | Không nhân tổng khi join, mẫu số bỏ cancelled, zero/null | `manyEntriesAndSetsAreNotMultiplied`, `weeklyProgressExcludesCancelled`, `newUserGetsEmptyButCompleteShape`, `nutritionMatchesMealPlanFixture` |
| T-B08 | Weight | Sửa/xóa điểm mới nhất; target hiện tại | `sameDateUpdatesExistingLog`, `logsDoNotChangeProfileAndDashboardShowsLatest` (xóa bản mới nhất → dashboard lùi về bản trước), `concurrentSameDateSavesKeepOneRow` |
| T-B09 | Reset | Mã một lần, hết hạn, session cũ mất hiệu lực | `concurrentResetsWithSameCodeSucceedOnce`, `expiredCodeIsRejected`, `successfulResetChangesPasswordAndRevokesSessions`, `wrongCodeFiveTimesInvalidatesTheCode`, `newCodeInvalidatesPreviousOne` |
| T-B10 | Admin | Revision cũ, sửa đồng thời, khóa thu hồi phiên | `staleRevisionConflicts`, `concurrentEditsWithSameRevisionSucceedOnce`, `lockRevokesSessionsAndUnlockNeedsNewLogin` |
| T-B11 | AI | Replay cùng key, lỗi provider giữ câu hỏi, giới hạn | `resendWithSameKeyReturnsSameResult`, `providerFailureKeepsQuestionAndRetryReusesIt`, `rateLimitPerMinute/PerDay` |

## 3. API và hợp đồng (T-A)

`qa/api_contract.py` gồm C01–C58. Script tự đăng ký tài khoản, không hardcode token. Các ca kiểm tra:
- status và `code`;
- body lỗi chuẩn (`code`, `message`, `timestamp` ISO UTC, `path`; `fieldErrors` chỉ có ở `VALIDATION_ERROR`; không lộ `Exception`, `org.`, `SQL`);
- kiểu số/ngày;
- phân trang: đi hết trang, không trùng, không thiếu; trang cuối; quá trang; `size` 101; `page` −1;
- field nguy hiểm (`role`, `id`, `userId`, `targetKcal`, `kcal`): bị bỏ qua;
- enum sai, độ dài vượt giới hạn, ngày không hợp lệ;
- sau input sai **không có dữ liệu ghi một phần** (C19, C36, C46, C58).

Kèm theo là `journey_smoke.py`: 39 kiểm tra xuyên module.

## 4. Hiệu năng (T-P)

`qa/latency.py` đo trên STAGING:
- endpoint: login, tìm món, dashboard, lịch sử tập, thực đơn, một API ghi (`POST /weight-logs`);
- dữ liệu: 1 user có 42 mục thực đơn trong 7 ngày và 5 buổi tập;
- warm-up 10 request, sau đó 200 request (login: 50) ở mức đồng thời 1 và 10;
- chỉ số: p50, p95, max, tỷ lệ lỗi, req/s.

AI không đo ở đây: phụ thuộc provider và bị giới hạn 5 câu/phút.

SRS không đặt ngưỡng hiệu năng. Mục tiêu tự đặt: p95 < 1 s cho API đọc ở mức demo, thấp hơn nhiều so với timeout 10 s của app. Kết quả chỉ là quan sát latency trên laptop, **không phải load test**.

## 5. Ngoài ngày 16

| Ca | Trạng thái | Chuyển sang |
|---|---|---|
| Hành trình Android 13 bước (docs/34 §4), admin trình duyệt 18 bước (docs/32 §5), dashboard Android 12 bước (docs/26 §5) | NOT_RUN | Ngày 18 (E2E Android) |
| Phân quyền IDOR sâu, rate limit login, chất lượng chatbot | NOT_RUN | Ngày 17 |
