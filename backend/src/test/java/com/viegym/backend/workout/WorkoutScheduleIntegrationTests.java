package com.viegym.backend.workout;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** W07–W11, W14, W15 (phần bảo vệ trạng thái) trong plan/huong-dan-ngay-7.md §8. */
class WorkoutScheduleIntegrationTests extends WorkoutTestSupport {
    private static final String BASE = "/api/v1/workout-schedules";
    private static final String PROGRAMS = "/api/v1/workout-programs";

    /** Thứ Hai của tuần cách tuần hiện tại {@code weeks} tuần. */
    private static LocalDate mondayIn(int weeks) {
        return WorkoutScheduleService.weekStart(today()).plusWeeks(weeks);
    }

    @Test
    void weekStartIsMonday() {
        assertThat(WorkoutScheduleService.weekStart(LocalDate.of(2026, 11, 1))).isEqualTo(LocalDate.of(2026, 10, 26));
        assertThat(WorkoutScheduleService.weekStart(LocalDate.of(2026, 10, 26))).isEqualTo(LocalDate.of(2026, 10, 26));
        assertThat(WorkoutScheduleService.weekStart(LocalDate.of(2027, 1, 1)).getDayOfWeek())
            .isEqualTo(DayOfWeek.MONDAY);
    }

    // Tạo, đọc chi tiết, danh sách tuần sắp theo ngày rồi giờ (không giờ xếp sau).
    @Test
    void createAndListWeek() throws Exception {
        String token = newUser();
        String program = createProgram(token, twoDayProgram("Lịch"));
        String dayA = JsonPath.read(program, "$.days[0].id");
        String dayB = JsonPath.read(program, "$.days[1].id");
        LocalDate monday = mondayIn(1);

        String created = createSchedule(token, dayA, monday.plusDays(2), "18:00");
        assertThat(JsonPath.<String>read(created, "$.status")).isEqualTo("SCHEDULED");
        assertThat(JsonPath.<String>read(created, "$.startTime")).isEqualTo("18:00");
        assertThat(JsonPath.<String>read(created, "$.workoutDay.programName")).isEqualTo("Lịch");
        assertThat(JsonPath.<List<String>>read(created, "$.exercises[*].exerciseId"))
            .containsExactly(GOBLET_SQUAT, PUSH_UP);
        createSchedule(token, dayB, monday.plusDays(2), null);
        createSchedule(token, dayB, monday.plusDays(2), "07:30");

        getJson(token, BASE + "?from=" + monday + "&to=" + monday.plusDays(6)).andExpect(status().isOk())
            .andExpect(jsonPath("$.from").value(monday.toString()))
            .andExpect(jsonPath("$.items", hasSize(3)))
            .andExpect(jsonPath("$.items[*].startTime", contains("07:30", "18:00", null)))
            .andExpect(jsonPath("$.items[0].workoutDay.name").value("Buổi B"))
            .andExpect(jsonPath("$.items[0].workoutLogId").isEmpty())
            .andExpect(jsonPath("$.items[0].exercises").doesNotExist());

        String id = JsonPath.read(created, "$.id");
        getJson(token, BASE + "/" + id).andExpect(status().isOk())
            .andExpect(jsonPath("$.exercises", hasSize(2)))
            .andExpect(jsonPath("$.exercises[0].targetSets").value(3));

        // Không gửi khoảng = tuần hiện tại theo múi giờ user.
        getJson(token, BASE).andExpect(status().isOk())
            .andExpect(jsonPath("$.from").value(mondayIn(0).toString()))
            .andExpect(jsonPath("$.to").value(mondayIn(0).plusDays(6).toString()))
            .andExpect(jsonPath("$.items").isEmpty());
        getJson(token, BASE + "?from=" + monday + "&to=" + monday.plusDays(6) + "&status=CANCELLED")
            .andExpect(jsonPath("$.items").isEmpty());
    }

    // W10 — khoảng đóng [from, to]: thứ Hai và Chủ nhật thuộc tuần, không lọt sang tuần bên cạnh.
    @Test
    void weekBoundariesAreInclusive() throws Exception {
        String token = newUser();
        String day = JsonPath.read(createProgram(token, twoDayProgram("Biên")), "$.days[0].id");
        LocalDate monday = mondayIn(2);
        createSchedule(token, day, monday, "00:00");
        createSchedule(token, day, monday.plusDays(6), "23:59");

        getJson(token, BASE + "?from=" + monday + "&to=" + monday.plusDays(6))
            .andExpect(jsonPath("$.items[*].scheduledDate",
                contains(monday.toString(), monday.plusDays(6).toString())));
        getJson(token, BASE + "?from=" + monday.minusDays(7) + "&to=" + monday.minusDays(1))
            .andExpect(jsonPath("$.items").isEmpty());
        getJson(token, BASE + "?from=" + monday.plusDays(7) + "&to=" + monday.plusDays(13))
            .andExpect(jsonPath("$.items").isEmpty());
    }

    @Test
    void invalidRangeAndBodyAreRejected() throws Exception {
        String token = newUser();
        String day = JsonPath.read(createProgram(token, twoDayProgram("Sai")), "$.days[0].id");
        LocalDate t = today();
        for (String query : List.of("?from=" + t, "?to=" + t, "?from=" + t + "&to=" + t.minusDays(1),
            "?from=" + t + "&to=" + t.plusDays(62), "?from=2026-13-01&to=2026-13-07",
            "?from=" + t + "&to=" + t + "&status=FOO")) {
            getJson(token, BASE + query).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        }
        getJson(token, BASE + "?from=" + t + "&to=" + t.plusDays(61)).andExpect(status().isOk());

        postJson(token, BASE, Map.of("workoutDayId", day, "scheduledDate", t.minusDays(1).toString()))
            .andExpect(status().isBadRequest()).andExpect(jsonPath("$.fieldErrors.scheduledDate").exists());
        postJson(token, BASE, Map.of("workoutDayId", day)).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.scheduledDate").exists());
        postJson(token, BASE, Map.of("workoutDayId", day, "scheduledDate", t.toString(), "startTime", "25:00"))
            .andExpect(status().isBadRequest()).andExpect(jsonPath("$.fieldErrors.startTime").exists());
        postJson(token, BASE, Map.of("workoutDayId", day, "scheduledDate", t.toString(), "note", "x".repeat(501)))
            .andExpect(status().isBadRequest()).andExpect(jsonPath("$.fieldErrors.note").exists());
        // Hôm nay được phép.
        createSchedule(token, day, t, null);
    }

    // Giới hạn 5 lịch chưa hủy mỗi ngày; lịch đã hủy không tính.
    @Test
    void dailyLimitIgnoresCancelled() throws Exception {
        String token = newUser();
        String day = JsonPath.read(createProgram(token, twoDayProgram("Nhiều")), "$.days[0].id");
        LocalDate date = today().plusDays(3);
        String first = null;
        for (int i = 0; i < WorkoutScheduleService.MAX_PER_DAY; i++) {
            String s = createSchedule(token, day, date, null);
            first = first == null ? JsonPath.read(s, "$.id") : first;
        }
        postJson(token, BASE, Map.of("workoutDayId", day, "scheduledDate", date.toString()))
            .andExpect(status().isBadRequest()).andExpect(jsonPath("$.fieldErrors.scheduledDate").exists());
        putJson(token, BASE + "/" + first, update(date, null, "CANCELLED")).andExpect(status().isOk());
        createSchedule(token, day, date, null);
    }

    // W07, W11 — buổi/lịch của người khác: 404, không lộ dữ liệu.
    @Test
    void otherUsersDaysAndSchedulesAreInvisible() throws Exception {
        String a = newUser();
        String b = newUser();
        String dayOfA = JsonPath.read(createProgram(a, twoDayProgram("A")), "$.days[0].id");
        LocalDate date = today().plusDays(1);
        String schedule = JsonPath.read(createSchedule(a, dayOfA, date, "06:00"), "$.id");

        postJson(b, BASE, Map.of("workoutDayId", dayOfA, "scheduledDate", date.toString()))
            .andExpect(status().isNotFound());
        // Buổi của giáo án mẫu cũng không xếp lịch trực tiếp được (phải sao chép trước).
        postJson(b, BASE, Map.of("workoutDayId", "7e000000-0000-4000-8000-000000000101",
            "scheduledDate", date.toString())).andExpect(status().isNotFound());
        getJson(b, BASE + "/" + schedule).andExpect(status().isNotFound());
        putJson(b, BASE + "/" + schedule, update(date, null, "CANCELLED")).andExpect(status().isNotFound());
        putJson(b, BASE + "/" + schedule, update(date.plusDays(1), "09:00", "SCHEDULED"))
            .andExpect(status().isNotFound());
        getJson(b, BASE + "?from=" + date + "&to=" + date).andExpect(jsonPath("$.items").isEmpty());

        getJson(a, BASE + "/" + schedule).andExpect(jsonPath("$.status").value("SCHEDULED"))
            .andExpect(jsonPath("$.startTime").value("06:00"));
    }

    // Dời lịch, hủy, hủy lại (W14), không nhận COMPLETED, không sửa lịch đã xong (W15 phần bảo vệ).
    @Test
    void rescheduleCancelAndFinalStates() throws Exception {
        String token = newUser();
        String day = JsonPath.read(createProgram(token, twoDayProgram("Đổi")), "$.days[0].id");
        LocalDate date = today().plusDays(1);
        String id = JsonPath.read(createSchedule(token, day, date, "18:00"), "$.id");

        Map<String, Object> move = update(date.plusDays(1), "07:00", "SCHEDULED");
        move.put("note", "  Dời sang sáng  ");
        putJson(token, BASE + "/" + id, move).andExpect(status().isOk())
            .andExpect(jsonPath("$.scheduledDate").value(date.plusDays(1).toString()))
            .andExpect(jsonPath("$.startTime").value("07:00"))
            .andExpect(jsonPath("$.note").value("Dời sang sáng"));
        putJson(token, BASE + "/" + id, update(today().minusDays(1), null, "SCHEDULED"))
            .andExpect(status().isBadRequest());
        putJson(token, BASE + "/" + id, update(date, null, "COMPLETED")).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.status").exists());
        putJson(token, BASE + "/" + id, update(date, null, null)).andExpect(status().isBadRequest());

        putJson(token, BASE + "/" + id, update(date.plusDays(1), "07:00", "CANCELLED")).andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("CANCELLED"));
        putJson(token, BASE + "/" + id, update(date.plusDays(1), "07:00", "CANCELLED"))
            .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("INVALID_STATE"));
        putJson(token, BASE + "/" + id, update(date.plusDays(2), "08:00", "SCHEDULED"))
            .andExpect(status().isConflict());
        getJson(token, BASE + "/" + id).andExpect(jsonPath("$.status").value("CANCELLED"))
            .andExpect(jsonPath("$.startTime").value("07:00"));

        // Lịch COMPLETED (ngày 8 mới tạo được qua workout log): chỉ kiểm tra lớp chặn sửa/hủy.
        String done = JsonPath.read(createSchedule(token, day, date, null), "$.id");
        jdbc.update("update workout_schedules set status = 'COMPLETED' where id = ?::uuid", done);
        putJson(token, BASE + "/" + done, update(date, null, "CANCELLED")).andExpect(status().isConflict());
        getJson(token, BASE + "/" + done).andExpect(jsonPath("$.status").value("COMPLETED"));
    }

    // W08 (theo docs/03) — gỡ buổi đã có lịch: buổi được archive, lịch vẫn mở được với bài cũ;
    // buổi archive không xếp lịch mới được và không giữ lại được bằng id.
    @Test
    void removingScheduledDayArchivesIt() throws Exception {
        String token = newUser();
        String program = createProgram(token, twoDayProgram("Archive"));
        String programId = JsonPath.read(program, "$.id");
        String dayA = JsonPath.read(program, "$.days[0].id");
        String dayB = JsonPath.read(program, "$.days[1].id");
        String schedule = JsonPath.read(createSchedule(token, dayB, today().plusDays(1), null), "$.id");

        Map<String, Object> onlyA = Map.of("name", "Chỉ còn A", "version", 0, "days", List.of(
            Map.of("id", dayA, "name", "Buổi A", "exercises", List.of(exercise(PUSH_UP, 3, 10, 60)))));
        putJson(token, PROGRAMS + "/" + programId, onlyA).andExpect(status().isOk())
            .andExpect(jsonPath("$.days[*].id", contains(dayA)));
        assertThat(count("select count(*) from workout_days where id = ?::uuid and archived_at is not null", dayB))
            .isEqualTo(1);
        getJson(token, PROGRAMS).andExpect(jsonPath("$.items[0].dayCount").value(1));

        getJson(token, BASE + "/" + schedule).andExpect(status().isOk())
            .andExpect(jsonPath("$.workoutDay.archived").value(true))
            .andExpect(jsonPath("$.workoutDay.programName").value("Chỉ còn A"))
            .andExpect(jsonPath("$.exercises[*].exerciseId", contains(LAT_PULLDOWN, GLUTE_BRIDGE)));
        postJson(token, BASE, Map.of("workoutDayId", dayB, "scheduledDate", today().plusDays(2).toString()))
            .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("INVALID_STATE"));

        Map<String, Object> revive = Map.of("name", "X", "version", 1, "days", List.of(
            Map.of("id", dayB, "name", "B", "exercises", List.of(exercise(PUSH_UP, 3, 10, 60)))));
        putJson(token, PROGRAMS + "/" + programId, revive).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors['days[0].id']").exists());

        // Buổi giữ lại: lịch đọc bài hiện tại của buổi (docs/03), sửa bài thì lịch thấy bài mới.
        String scheduleA = JsonPath.read(createSchedule(token, dayA, today().plusDays(1), null), "$.id");
        Map<String, Object> changeA = Map.of("name", "Chỉ còn A", "version", 1, "days", List.of(
            Map.of("id", dayA, "name", "Buổi A", "exercises", List.of(exercise(DEAD_BUG, 2, 8, 30)))));
        putJson(token, PROGRAMS + "/" + programId, changeA).andExpect(status().isOk());
        getJson(token, BASE + "/" + scheduleA).andExpect(jsonPath("$.exercises[*].exerciseId", contains(DEAD_BUG)))
            .andExpect(jsonPath("$.workoutDay.archived").value(false));
    }

    // Bài trong buổi bị ẩn sau khi tạo giáo án: chặn xếp lịch mới, giáo án vẫn đọc được và đánh dấu.
    @Test
    void hiddenExerciseBlocksNewSchedule() throws Exception {
        String token = newUser();
        UUID hidden = UUID.randomUUID();
        jdbc.update("""
            insert into exercises (id, code, name, name_search, muscle_group, equipment, difficulty,
                                   instructions, common_mistakes, is_active)
            values (?, ?, ?, 'sap an', 'CHEST', 'NONE', 'BEGINNER', 'Bước', 'Lỗi', true)
            """, hidden, "test-hidden-" + hidden, "Sắp ẩn " + hidden);
        String program = createProgram(token, Map.of("name", "Ẩn", "days", List.of(
            day("A", exercise(PUSH_UP, 3, 10, 60), exercise(hidden.toString(), 3, 10, 60)))));
        String day = JsonPath.read(program, "$.days[0].id");
        String before = JsonPath.read(createSchedule(token, day, today().plusDays(1), null), "$.id");
        jdbc.update("update exercises set is_active = false where id = ?", hidden);

        postJson(token, BASE, Map.of("workoutDayId", day, "scheduledDate", today().plusDays(2).toString()))
            .andExpect(status().isUnprocessableContent())
            .andExpect(jsonPath("$.code").value("EXERCISE_INACTIVE"))
            .andExpect(jsonPath("$.fieldErrors['exercises[1].exerciseId']").exists());
        getJson(token, PROGRAMS + "/" + JsonPath.read(program, "$.id")).andExpect(status().isOk())
            .andExpect(jsonPath("$.days[0].exercises[1].exerciseActive").value(false));
        // Lịch đã tạo trước vẫn đọc được.
        getJson(token, BASE + "/" + before).andExpect(status().isOk())
            .andExpect(jsonPath("$.exercises[1].exerciseActive").value(false));
    }

    private static Map<String, Object> update(LocalDate date, String time, String status) {
        Map<String, Object> body = new HashMap<>();
        body.put("scheduledDate", date.toString());
        body.put("startTime", time);
        body.put("status", status);
        return body;
    }
}
