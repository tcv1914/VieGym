package com.viegym.backend.workout;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.Test;

/** W01–W06, W12 trong plan/huong-dan-ngay-7.md §8, trên PostgreSQL thật. */
class WorkoutProgramIntegrationTests extends WorkoutTestSupport {
    private static final String BASE = "/api/v1/workout-programs";

    // W01
    @Test
    void customProgramKeepsOrderAndValues() throws Exception {
        String token = newUser();
        String created = createProgram(token, twoDayProgram("Giáo án của tôi"));
        String id = JsonPath.read(created, "$.id");

        getJson(token, BASE + "/" + id).andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Giáo án của tôi"))
            .andExpect(jsonPath("$.isTemplate").value(false))
            .andExpect(jsonPath("$.isActive").value(false))
            .andExpect(jsonPath("$.version").value(0))
            .andExpect(jsonPath("$.days[*].name", contains("Buổi A", "Buổi B")))
            .andExpect(jsonPath("$.days[*].dayOrder", contains(1, 2)))
            .andExpect(jsonPath("$.days[0].exercises[*].exerciseId", contains(GOBLET_SQUAT, PUSH_UP)))
            .andExpect(jsonPath("$.days[0].exercises[*].orderNo", contains(1, 2)))
            .andExpect(jsonPath("$.days[0].exercises[1].exerciseName").value("Hít đất (Push-up)"))
            .andExpect(jsonPath("$.days[0].exercises[1].exerciseActive").value(true))
            .andExpect(jsonPath("$.days[1].exercises[0].targetSets").value(4))
            .andExpect(jsonPath("$.days[1].exercises[0].targetReps").value(8))
            .andExpect(jsonPath("$.days[1].exercises[0].restSeconds").value(120));

        getJson(token, BASE).andExpect(status().isOk())
            .andExpect(jsonPath("$.items", hasSize(1)))
            .andExpect(jsonPath("$.items[0].id").value(id))
            .andExpect(jsonPath("$.items[0].dayCount").value(2));
    }

    // W02 — chọn mẫu = sao chép; sửa bản sao không đổi mẫu; mẫu không sửa được.
    @Test
    void templateCopyIsIndependent() throws Exception {
        String token = newUser();
        // Test khác có thể thêm mẫu kiểm thử: chỉ khẳng định hai mẫu seed có mặt.
        String templates = body(getJson(token, BASE + "?scope=templates").andExpect(status().isOk()));
        assertThat(JsonPath.<List<String>>read(templates, "$.items[*].id"))
            .contains(FULL_BODY_TEMPLATE, UPPER_LOWER_TEMPLATE);
        assertThat(JsonPath.<List<Boolean>>read(templates, "$.items[*].isTemplate")).containsOnly(true);
        assertThat(JsonPath.<List<Integer>>read(templates,
            "$.items[?(@.id == '" + FULL_BODY_TEMPLATE + "')].dayCount")).containsExactly(3);
        String templateBefore = body(getJson(token, BASE + "/" + FULL_BODY_TEMPLATE).andExpect(status().isOk()));

        String copy = createProgram(token, Map.of("templateId", FULL_BODY_TEMPLATE, "activate", true));
        String copyId = JsonPath.read(copy, "$.id");
        assertThat(copyId).isNotEqualTo(FULL_BODY_TEMPLATE);
        assertThat(JsonPath.<String>read(copy, "$.sourceTemplateId")).isEqualTo(FULL_BODY_TEMPLATE);
        assertThat(JsonPath.<Boolean>read(copy, "$.isTemplate")).isFalse();
        assertThat(JsonPath.<Boolean>read(copy, "$.isActive")).isTrue();
        assertThat(JsonPath.<List<String>>read(copy, "$.days[*].name")).containsExactly("Buổi A", "Buổi B", "Buổi C");
        // Bài giữ nguyên tham chiếu thư viện, nhưng dòng trong giáo án là bản mới.
        assertThat(JsonPath.<List<String>>read(copy, "$.days[0].exercises[*].exerciseId"))
            .isEqualTo(JsonPath.read(templateBefore, "$.days[0].exercises[*].exerciseId"));
        assertThat(JsonPath.<List<String>>read(copy, "$.days[*].id"))
            .doesNotContainAnyElementsOf(JsonPath.read(templateBefore, "$.days[*].id"));

        // Sửa bản sao: bỏ buổi C, đổi số liệu buổi A.
        Map<String, Object> edit = Map.of("name", "Bản của tôi", "version", JsonPath.read(copy, "$.version"), "days", List.of(
            Map.of("id", JsonPath.read(copy, "$.days[0].id"), "name", "Buổi A",
                "exercises", List.of(exercise(GOBLET_SQUAT, 5, 5, 180)))));
        putJson(token, BASE + "/" + copyId, edit).andExpect(status().isOk())
            .andExpect(jsonPath("$.days", hasSize(1)));

        assertThat(body(getJson(token, BASE + "/" + FULL_BODY_TEMPLATE))).isEqualTo(templateBefore);
        putJson(token, BASE + "/" + FULL_BODY_TEMPLATE, edit).andExpect(status().isForbidden())
            .andExpect(jsonPath("$.code").value("FORBIDDEN"));
        postJson(token, BASE + "/" + FULL_BODY_TEMPLATE + "/activate", null).andExpect(status().isForbidden());

        // Template không tồn tại; templateId kèm days.
        postJson(token, BASE, Map.of("templateId", UUID.randomUUID())).andExpect(status().isNotFound());
        Map<String, Object> both = new HashMap<>(twoDayProgram("X"));
        both.put("templateId", FULL_BODY_TEMPLATE);
        postJson(token, BASE, both).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.templateId").exists());
        // Mẫu không lẫn vào danh sách của user.
        getJson(token, BASE).andExpect(jsonPath("$.items[*].id", contains(copyId)));
    }

    // W03 — mỗi lỗi trả 400 theo trường và không lưu gì.
    @Test
    void invalidContentIsRejectedWithoutSaving() throws Exception {
        String token = newUser();
        record Case(Object body, String field) {
        }
        List<Case> cases = List.of(
            new Case(Map.of("name", "X", "days", List.of()), "days"),
            new Case(Map.of("name", "X"), "days"),
            new Case(Map.of("days", List.of(day("A", exercise(PUSH_UP, 3, 10, 60)))), "name"),
            new Case(Map.of("name", "  ", "days", List.of(day("A", exercise(PUSH_UP, 3, 10, 60)))), "name"),
            new Case(Map.of("name", "X", "days", List.of(Map.of("name", "A", "exercises", List.of()))),
                "days[0].exercises"),
            new Case(Map.of("name", "X", "days", List.of(day(" ", exercise(PUSH_UP, 3, 10, 60)))), "days[0].name"),
            new Case(Map.of("name", "X", "days", List.of(
                day("A", exercise(PUSH_UP, 3, 10, 60)),
                day("B", exercise(PUSH_UP, 3, 10, 60), exercise(PUSH_UP, 4, 8, 60)))),
                "days[1].exercises[1].exerciseId"),
            new Case(Map.of("name", "X", "days", List.of(day("A", exercise(PUSH_UP, 0, 10, 60)))),
                "days[0].exercises[0].targetSets"),
            new Case(Map.of("name", "X", "days", List.of(day("A", exercise(PUSH_UP, 11, 10, 60)))),
                "days[0].exercises[0].targetSets"),
            new Case(Map.of("name", "X", "days", List.of(day("A", exercise(PUSH_UP, 3, 101, 60)))),
                "days[0].exercises[0].targetReps"),
            new Case(Map.of("name", "X", "days", List.of(day("A", exercise(PUSH_UP, 3, 10, 601)))),
                "days[0].exercises[0].restSeconds"),
            new Case(Map.of("name", "a".repeat(101), "days", List.of(day("A", exercise(PUSH_UP, 3, 10, 60)))),
                "name"),
            new Case(Map.of("name", "X", "version", 0, "days", List.of(day("A", exercise(PUSH_UP, 3, 10, 60)))),
                "version"),
            new Case(Map.of("name", "X", "days", List.of(Map.of("id", UUID.randomUUID(), "name", "A",
                "exercises", List.of(exercise(PUSH_UP, 3, 10, 60)))))
                , "days[0].id"),
            new Case(Map.of("name", "X", "days", List.of(day("A", Map.of("exerciseId", PUSH_UP)))),
                "days[0].exercises[0].targetSets"));
        for (Case c : cases) {
            postJson(token, BASE, c.body()).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.fieldErrors['" + c.field() + "']").exists());
        }
        List<Map<String, Object>> eightDays = new ArrayList<>();
        for (int i = 0; i < 8; i++) {
            eightDays.add(day("B" + i, exercise(PUSH_UP, 3, 10, 60)));
        }
        postJson(token, BASE, Map.of("name", "X", "days", eightDays)).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.days").exists());
        postJson(token, BASE, "{\"name\":").andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.code").value("MALFORMED_JSON"));

        getJson(token, BASE).andExpect(jsonPath("$.items").isEmpty());
    }

    // W04 — bài ẩn hoặc ID lạ: 422 chỉ rõ dòng, không lưu một phần.
    @Test
    void inactiveOrUnknownExerciseIsRejected() throws Exception {
        String token = newUser();
        UUID inactive = UUID.randomUUID();
        jdbc.update("""
            insert into exercises (id, code, name, name_search, muscle_group, equipment, difficulty,
                                   instructions, common_mistakes, is_active)
            values (?, ?, ?, 'bai an', 'CHEST', 'NONE', 'BEGINNER', 'Bước', 'Lỗi', false)
            """, inactive, "test-inactive-" + inactive, "Bài ẩn " + inactive);
        Map<String, Object> request = Map.of("name", "X", "days", List.of(
            day("A", exercise(PUSH_UP, 3, 10, 60), exercise(inactive.toString(), 3, 10, 60)),
            day("B", exercise(UUID.randomUUID().toString(), 3, 10, 60))));
        postJson(token, BASE, request).andExpect(status().isUnprocessableContent())
            .andExpect(jsonPath("$.code").value("EXERCISE_INACTIVE"))
            .andExpect(jsonPath("$.fieldErrors['days[0].exercises[1].exerciseId']").exists())
            .andExpect(jsonPath("$.fieldErrors['days[1].exercises[0].exerciseId']").exists())
            .andExpect(jsonPath("$.fieldErrors['days[0].exercises[0].exerciseId']").doesNotExist());
        getJson(token, BASE).andExpect(jsonPath("$.items").isEmpty());
    }

    // Mẫu chứa bài đã bị ẩn: từ chối sao chép, không âm thầm bỏ bài rồi báo thành công.
    @Test
    void templateWithHiddenExerciseCannotBeCopied() throws Exception {
        String token = newUser();
        UUID hidden = UUID.randomUUID();
        UUID template = UUID.randomUUID();
        UUID day = UUID.randomUUID();
        jdbc.update("""
            insert into exercises (id, code, name, name_search, muscle_group, equipment, difficulty,
                                   instructions, common_mistakes, is_active)
            values (?, ?, ?, 'an trong mau', 'CHEST', 'NONE', 'BEGINNER', 'Bước', 'Lỗi', false)
            """, hidden, "test-tpl-hidden-" + hidden, "Ẩn trong mẫu " + hidden);
        jdbc.update("insert into workout_programs (id, name, is_template) values (?, 'Mẫu kiểm thử', true)",
            template);
        jdbc.update("insert into workout_days (id, program_id, day_order, name) values (?, ?, 1, 'A')", day,
            template);
        jdbc.update("""
            insert into workout_exercises (workout_day_id, exercise_id, order_no, target_sets, target_reps,
                                           rest_seconds)
            values (?, ?::uuid, 1, 3, 10, 60), (?, ?, 2, 3, 10, 60)
            """, day, PUSH_UP, day, hidden);

        postJson(token, BASE, Map.of("templateId", template)).andExpect(status().isUnprocessableContent())
            .andExpect(jsonPath("$.code").value("EXERCISE_INACTIVE"))
            .andExpect(jsonPath("$.fieldErrors['days[0].exercises[1].exerciseId']").exists());
        getJson(token, BASE).andExpect(jsonPath("$.items").isEmpty());
    }

    // W05 — tài nguyên riêng tư: của người khác trả 404 như không tồn tại.
    @Test
    void otherUsersProgramIsInvisible() throws Exception {
        String a = newUser();
        String b = newUser();
        String program = createProgram(a, twoDayProgram("Của A"));
        String id = JsonPath.read(program, "$.id");
        Map<String, Object> edit = new HashMap<>(twoDayProgram("B sửa"));
        edit.put("version", 0);

        getJson(b, BASE + "/" + id).andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("NOT_FOUND"));
        putJson(b, BASE + "/" + id, edit).andExpect(status().isNotFound());
        postJson(b, BASE + "/" + id + "/activate", null).andExpect(status().isNotFound());
        getJson(b, BASE).andExpect(jsonPath("$.items").isEmpty());
        getJson(a, BASE + "/" + id).andExpect(jsonPath("$.name").value("Của A"))
            .andExpect(jsonPath("$.isActive").value(false));

        getJson(a, BASE + "/abc").andExpect(status().isBadRequest());
        getJson(a, BASE + "?scope=all").andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.scope").exists());
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get(BASE))
            .andExpect(status().isUnauthorized());
    }

    // W06 — kích hoạt đồng thời nhiều giáo án: cuối cùng đúng một bản active.
    @Test
    void concurrentActivationLeavesOneActive() throws Exception {
        String token = newUser();
        List<String> ids = new ArrayList<>();
        for (int i = 0; i < 4; i++) {
            ids.add(JsonPath.read(createProgram(token, twoDayProgram("P" + i)), "$.id"));
        }
        ExecutorService pool = Executors.newFixedThreadPool(8);
        try {
            List<Callable<Integer>> tasks = new ArrayList<>();
            for (int i = 0; i < 16; i++) {
                String id = ids.get(i % ids.size());
                tasks.add(() -> postJson(token, BASE + "/" + id + "/activate", null)
                    .andReturn().getResponse().getStatus());
            }
            for (Future<Integer> f : pool.invokeAll(tasks)) {
                assertThat(f.get()).isEqualTo(200);
            }
        } finally {
            pool.shutdown();
        }
        String userId = jdbc.queryForObject("select user_id::text from workout_programs where id = ?::uuid",
            String.class, ids.get(0));
        assertThat(count("select count(*) from workout_programs where user_id = ?::uuid and is_active", userId))
            .isEqualTo(1);

        // Kích hoạt bản khác tắt bản cũ; kích hoạt lại bản đang active không lỗi.
        postJson(token, BASE + "/" + ids.get(2) + "/activate", null).andExpect(jsonPath("$.isActive").value(true));
        postJson(token, BASE + "/" + ids.get(2) + "/activate", null).andExpect(status().isOk());
        getJson(token, BASE).andExpect(jsonPath("$.items[?(@.isActive == true)].id", contains(ids.get(2))));
    }

    // W12 — hai màn sửa cùng version: màn sau nhận 409, không ghi đè im lặng.
    @Test
    void staleVersionIsRejected() throws Exception {
        String token = newUser();
        String program = createProgram(token, twoDayProgram("Gốc"));
        String id = JsonPath.read(program, "$.id");
        Map<String, Object> first = new HashMap<>(twoDayProgram("Màn 1"));
        first.put("version", 0);
        putJson(token, BASE + "/" + id, first).andExpect(status().isOk())
            .andExpect(jsonPath("$.version").value(1));

        Map<String, Object> second = new HashMap<>(twoDayProgram("Màn 2"));
        second.put("version", 0);
        putJson(token, BASE + "/" + id, second).andExpect(status().isConflict())
            .andExpect(jsonPath("$.code").value("VERSION_CONFLICT"));
        second.remove("version");
        putJson(token, BASE + "/" + id, second).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.version").exists());
        getJson(token, BASE + "/" + id).andExpect(jsonPath("$.name").value("Màn 1"))
            .andExpect(jsonPath("$.version").value(1));
    }

    // PUT giữ buổi có id, đổi thứ tự, xóa buổi không có lịch; activate:false tắt, null giữ nguyên.
    @Test
    void updateReordersKeepsIdsAndDeletesUnusedDays() throws Exception {
        String token = newUser();
        Map<String, Object> three = Map.of("name", "Ba buổi", "activate", true, "days", List.of(
            day("A", exercise(PUSH_UP, 3, 10, 60)),
            day("B", exercise(GOBLET_SQUAT, 3, 10, 60)),
            day("C", exercise(LAT_PULLDOWN, 3, 10, 60), exercise(DEAD_BUG, 3, 10, 30))));
        String program = createProgram(token, three);
        String id = JsonPath.read(program, "$.id");
        String a = JsonPath.read(program, "$.days[0].id");
        String b = JsonPath.read(program, "$.days[1].id");
        String c = JsonPath.read(program, "$.days[2].id");
        int version = JsonPath.read(program, "$.version");

        Map<String, Object> edit = Map.of("name", "Đã sửa", "version", version, "days", List.of(
            Map.of("id", c, "name", "C mới", "exercises", List.of(exercise(DEAD_BUG, 2, 12, 30),
                exercise(LAT_PULLDOWN, 3, 10, 60))),
            Map.of("id", a, "name", "A", "exercises", List.of(exercise(PUSH_UP, 3, 10, 60))),
            day("D", exercise(GLUTE_BRIDGE, 3, 15, 45))));
        String updated = body(putJson(token, BASE + "/" + id, edit).andExpect(status().isOk())
            .andExpect(jsonPath("$.isActive").value(true))
            .andExpect(jsonPath("$.days[*].name", contains("C mới", "A", "D")))
            .andExpect(jsonPath("$.days[*].dayOrder", contains(1, 2, 3)))
            .andExpect(jsonPath("$.days[0].id").value(c))
            .andExpect(jsonPath("$.days[1].id").value(a))
            .andExpect(jsonPath("$.days[0].exercises[*].exerciseId", contains(DEAD_BUG, LAT_PULLDOWN))));
        assertThat(count("select count(*) from workout_days where id = ?::uuid", b)).isZero();
        assertThat(count("select count(*) from workout_days where program_id = ?::uuid", id)).isEqualTo(3);

        Map<String, Object> off = new HashMap<>(edit);
        off.put("version", JsonPath.read(updated, "$.version"));
        off.put("activate", false);
        off.put("days", List.of(day("Một buổi", exercise(PUSH_UP, 3, 10, 60))));
        putJson(token, BASE + "/" + id, off).andExpect(status().isOk())
            .andExpect(jsonPath("$.isActive").value(false))
            .andExpect(jsonPath("$.days", hasSize(1)));
    }
}
