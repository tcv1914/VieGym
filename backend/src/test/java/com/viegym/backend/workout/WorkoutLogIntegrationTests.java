package com.viegym.backend.workout;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

/** L01–L22 trong plan/huong-dan-ngay-8.md §9 (theo quyết định ngày 2, docs/18 §1). */
class WorkoutLogIntegrationTests extends WorkoutTestSupport {
    private static final String LOGS = "/api/v1/workout-logs";
    private static final String SCHEDULES = "/api/v1/workout-schedules";

    /** Lịch hôm nay của buổi A (Goblet Squat, Chống đẩy) trong giáo án mới. */
    private String scheduleToday(String token) throws Exception {
        String program = createProgram(token, twoDayProgram("Ghi buổi"));
        String dayA = JsonPath.read(program, "$.days[0].id");
        return JsonPath.read(createSchedule(token, dayA, today(), "18:00"), "$.id");
    }

    private static Map<String, Object> set(int reps, Object kg) {
        Map<String, Object> set = new HashMap<>();
        set.put("reps", reps);
        set.put("weightKg", kg);
        return set;
    }

    private static Map<String, Object> ex(String exerciseId, Map<?, ?>... sets) {
        return Map.of("exerciseId", exerciseId, "sets", List.of(sets));
    }

    private static Map<String, Object> log(String scheduleId, Map<?, ?>... exercises) {
        Map<String, Object> body = new HashMap<>();
        body.put("scheduleId", scheduleId);
        body.put("exercises", List.of(exercises));
        return body;
    }

    /** Fixture plan §9: 2 bài, 4 hiệp, 40 reps, volume tạ ngoài 380. */
    private static Map<String, Object> fixture(String scheduleId) {
        Map<String, Object> body = log(scheduleId,
            ex(GOBLET_SQUAT, set(10, 20), set(8, 22.5)),
            ex(PUSH_UP, set(12, 0), set(10, 0)));
        Instant start = Instant.now().minus(1, ChronoUnit.HOURS).truncatedTo(ChronoUnit.SECONDS);
        body.put("startedAt", start.toString());
        body.put("endedAt", start.plus(45, ChronoUnit.MINUTES).toString());
        body.put("note", "  Dữ liệu demo  ");
        return body;
    }

    private int logCount(String scheduleId) {
        return count("select count(*) from workout_logs where schedule_id = ?::uuid", scheduleId);
    }

    private String scheduleStatus(String scheduleId) {
        return jdbc.queryForObject("select status from workout_schedules where id = ?::uuid", String.class,
            scheduleId);
    }

    // L01, L11, L20 — lưu fixture, lịch COMPLETED, đọc lại chi tiết/danh sách/lịch.
    @Test
    void logFixtureCompletesSchedule() throws Exception {
        String token = newUser();
        String scheduleId = scheduleToday(token);

        String created = body(postJson(token, LOGS, fixture(scheduleId)).andExpect(status().isCreated())
            .andExpect(jsonPath("$.scheduleId").value(scheduleId))
            .andExpect(jsonPath("$.workoutDate").value(today().toString()))
            .andExpect(jsonPath("$.workoutName").value("Buổi A"))
            .andExpect(jsonPath("$.programName").value("Ghi buổi"))
            .andExpect(jsonPath("$.note").value("Dữ liệu demo"))
            .andExpect(jsonPath("$.exerciseCount").value(2))
            .andExpect(jsonPath("$.setCount").value(4))
            .andExpect(jsonPath("$.totalReps").value(40))
            .andExpect(jsonPath("$.totalVolumeKg").value(380.0))
            .andExpect(jsonPath("$.exercises[0].orderNo").value(1))
            .andExpect(jsonPath("$.exercises[0].exerciseId").value(GOBLET_SQUAT))
            .andExpect(jsonPath("$.exercises[0].sets[1].setNo").value(2))
            .andExpect(jsonPath("$.exercises[0].sets[1].weightKg").value(22.5))
            .andExpect(jsonPath("$.exercises[1].sets[0].weightKg").value(0.0)));
        String logId = JsonPath.read(created, "$.id");
        assertThat(scheduleStatus(scheduleId)).isEqualTo("COMPLETED");

        getJson(token, LOGS + "/" + logId).andExpect(status().isOk())
            .andExpect(jsonPath("$.exercises", hasSize(2)))
            .andExpect(jsonPath("$.exercises[1].sets[1].reps").value(10))
            .andExpect(jsonPath("$.startedAt").isNotEmpty())
            .andExpect(jsonPath("$.totalReps").value(40));
        getJson(token, LOGS).andExpect(status().isOk())
            .andExpect(jsonPath("$.totalItems").value(1))
            .andExpect(jsonPath("$.items[0].id").value(logId))
            .andExpect(jsonPath("$.items[0].exerciseCount").value(2))
            .andExpect(jsonPath("$.items[0].setCount").value(4))
            .andExpect(jsonPath("$.items[0].totalReps").value(40))
            .andExpect(jsonPath("$.items[0].totalVolumeKg").value(380.0))
            .andExpect(jsonPath("$.items[0].exercises").doesNotExist());
        getJson(token, SCHEDULES + "/" + scheduleId).andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("COMPLETED"))
            .andExpect(jsonPath("$.workoutLogId").value(logId));
        getJson(token, SCHEDULES + "?from=" + today() + "&to=" + today()).andExpect(status().isOk())
            .andExpect(jsonPath("$.items[0].workoutLogId").value(logId));
    }

    // L02, L03, L19 — gửi lại (cùng hoặc khác nội dung) không tạo log thứ hai, trả id log hiện có.
    @Test
    void resendReturnsExistingLog() throws Exception {
        String token = newUser();
        String scheduleId = scheduleToday(token);
        String logId = JsonPath.read(body(postJson(token, LOGS, fixture(scheduleId))
            .andExpect(status().isCreated())), "$.id");

        postJson(token, LOGS, fixture(scheduleId)).andExpect(status().isConflict())
            .andExpect(jsonPath("$.code").value("WORKOUT_ALREADY_LOGGED"))
            .andExpect(jsonPath("$.workoutLogId").value(logId));
        postJson(token, LOGS, log(scheduleId, ex(PUSH_UP, set(99, 0)))).andExpect(status().isConflict())
            .andExpect(jsonPath("$.workoutLogId").value(logId));

        assertThat(logCount(scheduleId)).isEqualTo(1);
        getJson(token, LOGS + "/" + logId).andExpect(jsonPath("$.totalReps").value(40));
    }

    // L04, L05 — hai request song song cùng lịch: đúng một 201, request còn lại 409 kèm id log đó.
    @Test
    void concurrentLogsCreateOne() throws Exception {
        String token = newUser();
        String scheduleId = scheduleToday(token);
        List<Integer> statuses = race(
            () -> rawPost(token, LOGS, fixture(scheduleId)),
            () -> rawPost(token, LOGS, log(scheduleId, ex(PUSH_UP, set(5, 0)))));
        assertThat(statuses).containsExactlyInAnyOrder(201, 409);
        assertThat(logCount(scheduleId)).isEqualTo(1);
        assertThat(scheduleStatus(scheduleId)).isEqualTo("COMPLETED");
    }

    // L14 — hủy và hoàn thành đồng thời: chỉ một bên thắng, trạng thái khớp có/không có log.
    @Test
    void cancelAndCompleteRace() throws Exception {
        String token = newUser();
        String scheduleId = scheduleToday(token);
        Map<String, Object> cancel = new HashMap<>(Map.of("scheduledDate", today().toString(),
            "status", "CANCELLED"));
        List<Integer> statuses = race(
            () -> rawPost(token, LOGS, fixture(scheduleId)),
            () -> rawPut(token, SCHEDULES + "/" + scheduleId, cancel));
        assertThat(statuses).containsAnyOf(201, 200);
        assertThat(statuses).contains(409);
        String finalStatus = scheduleStatus(scheduleId);
        assertThat(finalStatus).isIn("COMPLETED", "CANCELLED");
        assertThat(logCount(scheduleId)).isEqualTo(finalStatus.equals("COMPLETED") ? 1 : 0);
    }

    // L06 — lỗi DB giữa chừng (sau khi đã chèn log và bài): rollback toàn bộ, lịch vẫn SCHEDULED.
    @Test
    void failureMidwayRollsBackEverything() throws Exception {
        String token = newUser();
        String scheduleId = scheduleToday(token);
        int logsBefore = count("select count(*) from workout_logs");
        int exercisesBefore = count("select count(*) from workout_log_exercises");
        int setsBefore = count("select count(*) from workout_set_logs");
        // Trigger chỉ tồn tại trong test: chặn hiệp có reps = 777.
        jdbc.execute("""
            CREATE OR REPLACE FUNCTION test_fail_set() RETURNS trigger AS $$
            BEGIN IF NEW.reps = 777 THEN RAISE EXCEPTION 'test failure'; END IF; RETURN NEW; END $$
            LANGUAGE plpgsql""");
        jdbc.execute("CREATE TRIGGER test_fail_set BEFORE INSERT ON workout_set_logs "
            + "FOR EACH ROW EXECUTE FUNCTION test_fail_set()");
        try {
            postJson(token, LOGS, log(scheduleId, ex(GOBLET_SQUAT, set(10, 20)), ex(PUSH_UP, set(777, 0))))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.code").value("INTERNAL_ERROR"))
                .andExpect(jsonPath("$.message").value("Lỗi hệ thống, vui lòng thử lại sau"));
        } finally {
            jdbc.execute("DROP TRIGGER test_fail_set ON workout_set_logs");
            jdbc.execute("DROP FUNCTION test_fail_set()");
        }
        assertThat(count("select count(*) from workout_logs")).isEqualTo(logsBefore);
        assertThat(count("select count(*) from workout_log_exercises")).isEqualTo(exercisesBefore);
        assertThat(count("select count(*) from workout_set_logs")).isEqualTo(setsBefore);
        assertThat(scheduleStatus(scheduleId)).isEqualTo("SCHEDULED");
        // Sau khi sửa lỗi, ghi lại bình thường.
        postJson(token, LOGS, fixture(scheduleId)).andExpect(status().isCreated());
    }

    // L07, L08 — A không ghi vào lịch của B, không đọc log của B.
    @Test
    void ownershipIsEnforced() throws Exception {
        String tokenA = newUser();
        String tokenB = newUser();
        String scheduleB = scheduleToday(tokenB);

        postJson(tokenA, LOGS, fixture(scheduleB)).andExpect(status().isNotFound());
        assertThat(scheduleStatus(scheduleB)).isEqualTo("SCHEDULED");

        String logB = JsonPath.read(body(postJson(tokenB, LOGS, fixture(scheduleB))
            .andExpect(status().isCreated())), "$.id");
        getJson(tokenA, LOGS + "/" + logB).andExpect(status().isNotFound());
        getJson(tokenA, LOGS).andExpect(jsonPath("$.totalItems").value(0));
        getJson(tokenA, SCHEDULES + "/" + scheduleB).andExpect(status().isNotFound());
        postJson(tokenA, LOGS, fixture(scheduleB)).andExpect(status().isNotFound());
        getJson(tokenB, LOGS + "/" + logB).andExpect(status().isOk());
    }

    // L09, L10 — dữ liệu sai bị chặn đúng trường, không lưu gì.
    @Test
    void invalidPayloadsAreRejected() throws Exception {
        String token = newUser();
        String scheduleId = scheduleToday(token);

        expectField(token, log(scheduleId), "exercises");
        expectField(token, log(scheduleId, ex(PUSH_UP)), "exercises[0].sets");
        expectField(token, log(scheduleId, ex(PUSH_UP, set(0, 0))), "exercises[0].sets[0].reps");
        expectField(token, log(scheduleId, ex(PUSH_UP, set(-3, 0))), "exercises[0].sets[0].reps");
        expectField(token, log(scheduleId, ex(PUSH_UP, set(1001, 0))), "exercises[0].sets[0].reps");
        expectField(token, log(scheduleId, ex(PUSH_UP, set(10, -1))), "exercises[0].sets[0].weightKg");
        expectField(token, log(scheduleId, ex(PUSH_UP, set(10, 1000))), "exercises[0].sets[0].weightKg");
        expectField(token, log(scheduleId, ex(PUSH_UP, set(10, 20.125))), "exercises[0].sets[0].weightKg");
        // Bỏ trống mức tạ không được hiểu là 0.
        expectField(token, log(scheduleId, ex(PUSH_UP, set(10, null))), "exercises[0].sets[0].weightKg");
        // Một bài hai lần trong cùng log.
        expectField(token, log(scheduleId, ex(PUSH_UP, set(10, 0)), ex(PUSH_UP, set(8, 0))),
            "exercises[1].exerciseId");
        // Bài không tồn tại (L09: ID lạ).
        expectField(token, log(scheduleId, ex("00000000-0000-4000-8000-000000000000", set(10, 0))),
            "exercises[0].exerciseId");
        // 21 bài, 21 hiệp.
        List<Map<String, Object>> manySets = new ArrayList<>();
        for (int i = 0; i < 21; i++) {
            manySets.add(set(5, 0));
        }
        expectField(token, log(scheduleId, Map.of("exerciseId", PUSH_UP, "sets", manySets)), "exercises[0].sets");
        // Thời gian.
        Map<String, Object> reversed = log(scheduleId, ex(PUSH_UP, set(10, 0)));
        reversed.put("startedAt", "2026-11-01T08:00:00+07:00");
        reversed.put("endedAt", "2026-11-01T07:00:00+07:00");
        expectField(token, reversed, "endedAt");
        Map<String, Object> future = log(scheduleId, ex(PUSH_UP, set(10, 0)));
        future.put("startedAt", Instant.now().plus(2, ChronoUnit.HOURS).toString());
        expectField(token, future, "startedAt");
        Map<String, Object> tooLong = log(scheduleId, ex(PUSH_UP, set(10, 0)));
        tooLong.put("startedAt", "2026-10-01T08:00:00Z");
        tooLong.put("endedAt", "2026-10-02T09:00:00Z");
        expectField(token, tooLong, "endedAt");
        // Số lần không phải số nguyên, mức tạ không phải số.
        String fraction = "{\"scheduleId\":\"%s\",\"exercises\":[{\"exerciseId\":\"%s\",\"sets\":[{\"reps\":10.5,\"weightKg\":0}]}]}"
            .formatted(scheduleId, PUSH_UP);
        postJson(token, LOGS, fraction).andExpect(status().isBadRequest());
        String nan = "{\"scheduleId\":\"%s\",\"exercises\":[{\"exerciseId\":\"%s\",\"sets\":[{\"reps\":10,\"weightKg\":\"NaN\"}]}]}"
            .formatted(scheduleId, PUSH_UP);
        postJson(token, LOGS, nan).andExpect(status().isBadRequest());

        assertThat(logCount(scheduleId)).isZero();
        assertThat(scheduleStatus(scheduleId)).isEqualTo("SCHEDULED");
    }

    private void expectField(String token, Object request, String field) throws Exception {
        postJson(token, LOGS, request).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
            .andExpect(jsonPath("$.fieldErrors['" + field + "']").isNotEmpty());
    }

    // L12 — lịch đã hủy và lịch tương lai bị từ chối.
    @Test
    void cancelledAndFutureSchedulesAreRejected() throws Exception {
        String token = newUser();
        String program = createProgram(token, twoDayProgram("Từ chối"));
        String dayA = JsonPath.read(program, "$.days[0].id");
        String tomorrow = JsonPath.read(createSchedule(token, dayA, today().plusDays(1), null), "$.id");
        postJson(token, LOGS, fixture(tomorrow)).andExpect(status().isConflict())
            .andExpect(jsonPath("$.code").value("INVALID_STATE"));

        String cancelled = scheduleToday(token);
        putJson(token, SCHEDULES + "/" + cancelled, Map.of("scheduledDate", today().toString(),
            "status", "CANCELLED")).andExpect(status().isOk());
        postJson(token, LOGS, fixture(cancelled)).andExpect(status().isConflict())
            .andExpect(jsonPath("$.code").value("INVALID_STATE"));

        // Lịch đã hoàn thành không hủy hay dời được nữa.
        String done = scheduleToday(token);
        postJson(token, LOGS, fixture(done)).andExpect(status().isCreated());
        putJson(token, SCHEDULES + "/" + done, Map.of("scheduledDate", today().toString(),
            "status", "CANCELLED")).andExpect(status().isConflict());
        assertThat(count("select count(*) from workout_logs where schedule_id in (?::uuid, ?::uuid)",
            tomorrow, cancelled)).isZero();
    }

    // L13, L18 — ghi muộn cho lịch đã qua ngày: workout_date là ngày của lịch, lọc theo khoảng đóng.
    @Test
    void lateLogKeepsScheduledDateAndFiltersByRange() throws Exception {
        String token = newUser();
        String scheduleId = scheduleToday(token);
        LocalDate past = today().minusDays(3);
        jdbc.update("update workout_schedules set scheduled_date = ? where id = ?::uuid", past,
            java.util.UUID.fromString(scheduleId));

        String logId = JsonPath.read(body(postJson(token, LOGS, fixture(scheduleId))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.workoutDate").value(past.toString()))), "$.id");
        String other = scheduleToday(token);
        String otherId = JsonPath.read(body(postJson(token, LOGS, log(other, ex(PUSH_UP, set(10, 0))))
            .andExpect(status().isCreated())), "$.id");

        getJson(token, LOGS + "?from=" + past + "&to=" + past).andExpect(jsonPath("$.totalItems").value(1))
            .andExpect(jsonPath("$.items[0].id").value(logId));
        getJson(token, LOGS + "?from=" + past.plusDays(1) + "&to=" + today())
            .andExpect(jsonPath("$.totalItems").value(1))
            .andExpect(jsonPath("$.items[0].id").value(otherId));
        // Mới nhất trước; phân trang.
        getJson(token, LOGS + "?size=1").andExpect(jsonPath("$.items[0].id").value(otherId))
            .andExpect(jsonPath("$.hasNext").value(true));
        getJson(token, LOGS + "?size=1&page=1").andExpect(jsonPath("$.items[0].id").value(logId))
            .andExpect(jsonPath("$.hasNext").value(false));
        // Validation bộ lọc.
        getJson(token, LOGS + "?from=" + today() + "&to=" + past).andExpect(status().isBadRequest());
        getJson(token, LOGS + "?from=" + today().minusDays(366) + "&to=" + today()).andExpect(status().isBadRequest());
        getJson(token, LOGS + "?size=0").andExpect(status().isBadRequest());
        getJson(token, LOGS + "?size=101").andExpect(status().isBadRequest());
        getJson(token, LOGS + "?page=-1").andExpect(status().isBadRequest());
        getJson(token, LOGS + "?from=2026-13-01").andExpect(status().isBadRequest());
    }

    // L16, L17, L22 — snapshot không đổi khi sửa giáo án/tên bài; bài trong kế hoạch đã ẩn vẫn ghi được;
    // bỏ một bài chỉ lưu bài đã tập; bài ngoài kế hoạch đã ẩn → 422.
    @Test
    void snapshotsAndInactiveExercises() throws Exception {
        String token = newUser();
        String scheduleId = scheduleToday(token);
        String originalName = jdbc.queryForObject("select name from exercises where id = ?::uuid", String.class,
            GOBLET_SQUAT);
        try {
            jdbc.update("update exercises set is_active = false where id in (?::uuid, ?::uuid)", GOBLET_SQUAT,
                DEAD_BUG);
            postJson(token, LOGS, log(scheduleId, ex(DEAD_BUG, set(10, 0)))).andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.code").value("EXERCISE_INACTIVE"))
                .andExpect(jsonPath("$.fieldErrors['exercises[0].exerciseId']").isNotEmpty());

            // Chỉ ghi Goblet Squat (đã ẩn nhưng nằm trong buổi), bỏ chống đẩy.
            String logId = JsonPath.read(body(postJson(token, LOGS, log(scheduleId, ex(GOBLET_SQUAT, set(10, 16))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.exerciseCount").value(1))), "$.id");

            jdbc.update("update exercises set name = 'Tên đã đổi' where id = ?::uuid", GOBLET_SQUAT);
            jdbc.update("update workout_days set name = 'Buổi đổi tên' where id = (select workout_day_id "
                + "from workout_schedules where id = ?::uuid)", java.util.UUID.fromString(scheduleId));
            getJson(token, LOGS + "/" + logId).andExpect(status().isOk())
                .andExpect(jsonPath("$.workoutName").value("Buổi A"))
                .andExpect(jsonPath("$.exercises", hasSize(1)))
                .andExpect(jsonPath("$.exercises[0].exerciseName").value(originalName));
        } finally {
            jdbc.update("update exercises set is_active = true, name = ? where id = ?::uuid", originalName,
                GOBLET_SQUAT);
            jdbc.update("update exercises set is_active = true where id = ?::uuid", DEAD_BUG);
        }
    }

    // BR-W08 — bài ngoài kế hoạch còn hoạt động được ghi; thứ tự theo mảng gửi lên.
    @Test
    void extraActiveExerciseIsAllowed() throws Exception {
        String token = newUser();
        String scheduleId = scheduleToday(token);
        postJson(token, LOGS, log(scheduleId, ex(DEAD_BUG, set(12, 0)), ex(GOBLET_SQUAT, set(8, 12))))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.exercises[0].exerciseId").value(DEAD_BUG))
            .andExpect(jsonPath("$.exercises[1].orderNo").value(2));
    }

    // L21 — không có hoặc sai JWT → 401, không ghi gì.
    @Test
    void requiresAuthentication() throws Exception {
        String token = newUser();
        String scheduleId = scheduleToday(token);
        mvc.perform(post(LOGS).contentType(MediaType.APPLICATION_JSON).content(JSON.writeValueAsString(fixture(scheduleId))))
            .andExpect(status().isUnauthorized());
        mvc.perform(post(LOGS).header(HttpHeaders.AUTHORIZATION, "Bearer sai")
                .contentType(MediaType.APPLICATION_JSON).content(JSON.writeValueAsString(fixture(scheduleId))))
            .andExpect(status().isUnauthorized());
        mvc.perform(get(LOGS)).andExpect(status().isUnauthorized());
        assertThat(logCount(scheduleId)).isZero();
    }

    private int rawPost(String token, String path, Object body) throws Exception {
        return postJson(token, path, body).andReturn().getResponse().getStatus();
    }

    private int rawPut(String token, String path, Object body) throws Exception {
        return putJson(token, path, body).andReturn().getResponse().getStatus();
    }

    /** Chạy hai thao tác cùng lúc (mỗi thao tác một request, một giao dịch, một kết nối). */
    @SafeVarargs
    private static List<Integer> race(Callable<Integer>... tasks) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(tasks.length);
        try {
            CountDownLatch start = new CountDownLatch(1);
            List<Future<Integer>> futures = new ArrayList<>();
            for (Callable<Integer> task : tasks) {
                futures.add(pool.submit(() -> {
                    start.await();
                    return task.call();
                }));
            }
            start.countDown();
            List<Integer> result = new ArrayList<>();
            for (Future<Integer> f : futures) {
                result.add(f.get());
            }
            return result;
        } finally {
            pool.shutdownNow();
        }
    }
}
