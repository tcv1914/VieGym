package com.viegym.backend.meal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.viegym.backend.TestcontainersConfiguration;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import tools.jackson.databind.json.JsonMapper;

/**
 * M01–M10 trong plan/huong-dan-ngay-10.md §6, theo quyết định ngày 2 (docs/23 §1). Món fixture
 * chèn riêng cho từng test và xóa sau test để không làm lệch số món của FoodLibraryIntegrationTests.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class MealPlanIntegrationTests {
    private static final String PLANS = "/api/v1/meal-plans";
    private static final String ENTRIES = "/api/v1/meal-plans/entries";
    private static final String PASSWORD = "Matkhau123";
    private static final ZoneId ZONE = ZoneId.of("Asia/Ho_Chi_Minh");
    private static final JsonMapper JSON = JsonMapper.builder().build();

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcTemplate jdbc;

    private final List<String> fixtureFoods = new ArrayList<>();

    @AfterEach
    void removeFixtureFoods() {
        for (String id : fixtureFoods) {
            jdbc.update("delete from meal_entries where food_id = ?::uuid", id);
            jdbc.update("delete from foods where id = ?::uuid", id);
        }
    }

    /** Món A plan §4: mỗi phần 200 kcal / P10 / C30 / F4. */
    private String foodA() {
        return fixtureFood("Món A", "200", "10", "30", "4");
    }

    /** Món B plan §4: mỗi phần 100 kcal / P5 / C15 / F2. */
    private String foodB() {
        return fixtureFood("Món B", "100", "5", "15", "2");
    }

    private String fixtureFood(String name, String kcal, String protein, String carbs, String fat) {
        String code = "TEST-" + UUID.randomUUID().toString().substring(0, 8);
        String id = jdbc.queryForObject("""
            insert into foods (code, name, name_search, category_id, serving_description, kcal_per_serving,
                               protein_per_serving, carbs_per_serving, fat_per_serving, data_quality, source)
            values (?, ?, ?, (select id from food_categories order by sort_order limit 1), '1 phần test',
                    ?::numeric, ?::numeric, ?::numeric, ?::numeric, 'SOURCED', 'Fixture test ngày 10')
            returning id::text
            """, String.class, code, name, name.toLowerCase(), kcal, protein, carbs, fat);
        fixtureFoods.add(id);
        return id;
    }

    private static LocalDate today() {
        return LocalDate.now(ZONE);
    }

    private static Map<String, Object> entry(LocalDate date, String mealType, String foodId, Object servings) {
        Map<String, Object> body = new HashMap<>();
        body.put("date", date.toString());
        body.put("mealType", mealType);
        body.put("foodId", foodId);
        body.put("servings", servings);
        return body;
    }

    private String newUser() throws Exception {
        String email = "m" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\",\"fullName\":\"Test\"}".formatted(email, PASSWORD)))
            .andExpect(status().isCreated());
        String body = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\"}".formatted(email, PASSWORD)))
            .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return JsonPath.read(body, "$.accessToken");
    }

    private ResultActions call(MockHttpServletRequestBuilder request, String token, Object body) throws Exception {
        request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token);
        if (body != null) {
            request.contentType(MediaType.APPLICATION_JSON)
                .content(body instanceof String s ? s : JSON.writeValueAsString(body));
        }
        return mvc.perform(request);
    }

    private ResultActions getPlan(String token, LocalDate date) throws Exception {
        return call(get(PLANS + (date == null ? "" : "?date=" + date)), token, null);
    }

    private ResultActions add(String token, Object body) throws Exception {
        return call(post(ENTRIES), token, body);
    }

    private ResultActions update(String token, String entryId, Object body) throws Exception {
        return call(put(ENTRIES + "/" + entryId), token, body);
    }

    private ResultActions remove(String token, String entryId) throws Exception {
        return call(delete(ENTRIES + "/" + entryId), token, null);
    }

    private static String body(ResultActions result) throws Exception {
        return result.andReturn().getResponse().getContentAsString();
    }

    private String userId(String token) throws Exception {
        return JsonPath.read(body(call(get("/api/v1/users/me"), token, null).andExpect(status().isOk())), "$.id");
    }

    private int count(String sql, Object... args) {
        return jdbc.queryForObject(sql, Integer.class, args);
    }

    private int planCount(String token) throws Exception {
        return count("select count(*) from meal_plans where user_id = ?::uuid", userId(token));
    }

    private int entryCount(String token) throws Exception {
        return count("select count(*) from meal_entries e join meal_plans p on p.id = e.meal_plan_id "
            + "where p.user_id = ?::uuid", userId(token));
    }

    private static ResultActions expectTotals(ResultActions result, double kcal, double protein, double carbs,
                                              double fat) throws Exception {
        return result.andExpect(jsonPath("$.totals.kcal").value(kcal))
            .andExpect(jsonPath("$.totals.proteinG").value(protein))
            .andExpect(jsonPath("$.totals.carbsG").value(carbs))
            .andExpect(jsonPath("$.totals.fatG").value(fat));
    }

    private void putProfile(String token, String weightKg) throws Exception {
        String profile = """
            {"sex":"MALE","dateOfBirth":"%s","heightCm":170,"weightKg":%s,
             "activityLevel":"MODERATE","goal":"MAINTAIN"}
            """.formatted(today().minusYears(22), weightKg);
        call(put("/api/v1/health-profile/me"), token, profile).andExpect(status().isOk());
    }

    // M01, A1, BR-N06 — fixture thêm/sửa/xóa khớp số cố định; thực đơn còn lại sau khi xóa.
    @Test
    void fixtureAddUpdateDelete() throws Exception {
        String token = newUser();
        String a = foodA();
        String b = foodB();
        LocalDate day = today();

        getPlan(token, day).andExpect(status().isOk())
            .andExpect(jsonPath("$.date").value(day.toString()))
            .andExpect(jsonPath("$.entryCount").value(0))
            .andExpect(jsonPath("$.meals.BREAKFAST", hasSize(0)))
            .andExpect(jsonPath("$.meals.SNACK", hasSize(0)))
            .andExpect(jsonPath("$.totals.kcal").value(0.0))
            .andExpect(jsonPath("$.targets").doesNotExist())
            .andExpect(jsonPath("$.remaining").doesNotExist());
        assertThat(planCount(token)).isZero();

        String first = body(add(token, entry(day, "LUNCH", a, 1.5)).andExpect(status().isCreated())
            .andExpect(jsonPath("$.meals.LUNCH[0].foodName").value("Món A"))
            .andExpect(jsonPath("$.meals.LUNCH[0].servings").value(1.5))
            .andExpect(jsonPath("$.meals.LUNCH[0].kcal").value(300.0))
            .andExpect(jsonPath("$.meals.LUNCH[0].kcalPerServing").value(200.0))
            .andExpect(jsonPath("$.meals.LUNCH[0].servingDescription").value("1 phần test")));
        String entryA = JsonPath.read(first, "$.meals.LUNCH[0].id");

        String second = body(expectTotals(add(token, entry(day, "DINNER", b, 2)).andExpect(status().isCreated()),
            500.0, 25.0, 75.0, 10.0)
            .andExpect(jsonPath("$.entryCount").value(2))
            .andExpect(jsonPath("$.mealTotals.LUNCH.kcal").value(300.0))
            .andExpect(jsonPath("$.mealTotals.DINNER.kcal").value(200.0))
            .andExpect(jsonPath("$.mealTotals.BREAKFAST.kcal").value(0.0)));
        String entryB = JsonPath.read(second, "$.meals.DINNER[0].id");

        expectTotals(update(token, entryA, Map.of("servings", 1)).andExpect(status().isOk()), 400.0, 20.0, 60.0, 8.0)
            .andExpect(jsonPath("$.meals.LUNCH[0].servings").value(1.0));
        expectTotals(getPlan(token, day).andExpect(status().isOk()), 400.0, 20.0, 60.0, 8.0);

        expectTotals(remove(token, entryB).andExpect(status().isOk()), 200.0, 10.0, 30.0, 4.0)
            .andExpect(jsonPath("$.meals.DINNER", hasSize(0)));

        // Đổi bữa: mục chuyển sang bữa mới, tổng giữ nguyên.
        update(token, entryA, Map.of("mealType", "SNACK")).andExpect(status().isOk())
            .andExpect(jsonPath("$.meals.LUNCH", hasSize(0)))
            .andExpect(jsonPath("$.meals.SNACK[0].id").value(entryA))
            .andExpect(jsonPath("$.mealTotals.SNACK.kcal").value(200.0))
            .andExpect(jsonPath("$.totals.kcal").value(200.0));

        remove(token, entryA).andExpect(status().isOk()).andExpect(jsonPath("$.entryCount").value(0));
        assertThat(planCount(token)).isEqualTo(1);
        remove(token, entryA).andExpect(status().isNotFound());
    }

    // M02, A3 — dữ liệu sai bị từ chối, không tạo thực đơn hay mục nào.
    @Test
    void invalidInputIsRejected() throws Exception {
        String token = newUser();
        String a = foodA();
        LocalDate day = today();
        record Case(String field, Object body) {
        }
        Map<String, Object> noDate = entry(day, "LUNCH", a, 1);
        noDate.remove("date");
        List<Case> cases = List.of(
            new Case("servings", entry(day, "LUNCH", a, 0)),
            new Case("servings", entry(day, "LUNCH", a, -1)),
            new Case("servings", entry(day, "LUNCH", a, 20.01)),
            new Case("servings", entry(day, "LUNCH", a, 21)),
            new Case("servings", entry(day, "LUNCH", a, 1.255)),
            new Case("servings", entry(day, "LUNCH", a, null)),
            new Case("servings", entry(day, "LUNCH", a, "abc")),
            new Case("mealType", entry(day, "BRUNCH", a, 1)),
            new Case("mealType", entry(day, null, a, 1)),
            new Case("foodId", entry(day, "LUNCH", null, 1)),
            new Case("foodId", entry(day, "LUNCH", "khong-phai-uuid", 1)),
            new Case("date", noDate),
            new Case("date", entry(LocalDate.of(1999, 12, 31), "LUNCH", a, 1)));
        for (Case c : cases) {
            add(token, c.body()).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.fieldErrors." + c.field()).exists());
        }
        call(post(ENTRIES), token, "{").andExpect(status().isBadRequest());
        assertThat(planCount(token)).isZero();

        // Biên hợp lệ: 0.01 và 20.
        add(token, entry(day, "LUNCH", a, 0.01)).andExpect(status().isCreated());
        String created = body(add(token, entry(day, "LUNCH", a, 20)).andExpect(status().isCreated())
            .andExpect(jsonPath("$.totals.kcal").value(4002.0)));
        String entryId = JsonPath.read(created, "$.meals.LUNCH[1].id");

        update(token, entryId, Map.of()).andExpect(status().isBadRequest());
        update(token, entryId, Map.of("servings", 0)).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.servings").exists());
        update(token, entryId, Map.of("servings", 1.001)).andExpect(status().isBadRequest());
        update(token, entryId, Map.of("mealType", "BRUNCH")).andExpect(status().isBadRequest());
        getPlan(token, day).andExpect(jsonPath("$.totals.kcal").value(4002.0));
        getPlan(token, null).andExpect(status().isOk());
        call(get(PLANS + "?date=2026-13-01"), token, null).andExpect(status().isBadRequest());
        call(put(ENTRIES + "/khong-phai-uuid"), token, Map.of("servings", 1)).andExpect(status().isBadRequest());
    }

    // M03, M04, NUT-BR08, BR-N04 — mỗi lần thêm là một mục riêng; kcal app gửi lên bị bỏ qua.
    @Test
    void eachAddIsSeparateEntryAndClientNutritionIgnored() throws Exception {
        String token = newUser();
        String a = foodA();
        Map<String, Object> body = entry(today(), "BREAKFAST", a, 1);
        body.put("kcal", 1);
        body.put("kcalPerServing", 1);
        body.put("userId", UUID.randomUUID().toString());

        add(token, body).andExpect(status().isCreated());
        add(token, body).andExpect(status().isCreated())
            .andExpect(jsonPath("$.meals.BREAKFAST", hasSize(2)))
            .andExpect(jsonPath("$.meals.BREAKFAST[0].kcalPerServing").value(200.0))
            .andExpect(jsonPath("$.totals.kcal").value(400.0));
        assertThat(entryCount(token)).isEqualTo(2);
        assertThat(planCount(token)).isEqualTo(1);
    }

    // M05, NUT-BR01 — hai request thêm món đầu ngày song song: một thực đơn, hai mục.
    @Test
    void concurrentFirstAddCreatesOnePlan() throws Exception {
        String token = newUser();
        String a = foodA();
        String b = foodB();
        LocalDate day = today().plusDays(1);
        CountDownLatch start = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            List<Callable<Integer>> tasks = List.of(a, b).stream().<Callable<Integer>>map(food -> () -> {
                start.await();
                return add(token, entry(day, "LUNCH", food, 1)).andReturn().getResponse().getStatus();
            }).toList();
            List<Future<Integer>> results = tasks.stream().map(pool::submit).toList();
            start.countDown();
            for (Future<Integer> result : results) {
                assertThat(result.get()).isEqualTo(201);
            }
        } finally {
            pool.shutdownNow();
        }
        assertThat(planCount(token)).isEqualTo(1);
        expectTotals(getPlan(token, day), 300.0, 15.0, 45.0, 6.0).andExpect(jsonPath("$.entryCount").value(2));
    }

    // M06, NUT-BR05 — admin sửa món: mục đã ghi giữ tên và số liệu cũ, sửa số phần dùng snapshot cũ.
    @Test
    void foodEditDoesNotChangeEntries() throws Exception {
        String token = newUser();
        String a = foodA();
        String created = body(add(token, entry(today(), "LUNCH", a, 1.5)).andExpect(status().isCreated()));
        String entryId = JsonPath.read(created, "$.meals.LUNCH[0].id");
        assertThat(count("select food_revision from meal_entries where id = ?::uuid", entryId)).isEqualTo(1);

        jdbc.update("""
            update foods set name = 'Món A đã sửa', kcal_per_serving = 999, protein_per_serving = 99,
                             revision = revision + 1 where id = ?::uuid
            """, a);

        getPlan(token, today()).andExpect(jsonPath("$.meals.LUNCH[0].foodName").value("Món A"))
            .andExpect(jsonPath("$.meals.LUNCH[0].kcal").value(300.0));
        update(token, entryId, Map.of("servings", 2)).andExpect(status().isOk())
            .andExpect(jsonPath("$.meals.LUNCH[0].foodName").value("Món A"))
            .andExpect(jsonPath("$.totals.kcal").value(400.0))
            .andExpect(jsonPath("$.totals.proteinG").value(20.0));

        // Mục thêm sau khi sửa lấy số liệu mới và revision mới.
        add(token, entry(today(), "DINNER", a, 1)).andExpect(status().isCreated())
            .andExpect(jsonPath("$.meals.DINNER[0].foodName").value("Món A đã sửa"))
            .andExpect(jsonPath("$.totals.kcal").value(1399.0));
        assertThat(count("select max(food_revision) from meal_entries where food_id = ?::uuid", a)).isEqualTo(2);
    }

    // M07, A4, NUT-BR06 — món bị ẩn: không thêm mới, mục đã ghi vẫn xem/sửa/xóa được.
    @Test
    void inactiveFoodBlocksNewEntriesOnly() throws Exception {
        String token = newUser();
        String a = foodA();
        String created = body(add(token, entry(today(), "LUNCH", a, 1)).andExpect(status().isCreated()));
        String entryId = JsonPath.read(created, "$.meals.LUNCH[0].id");
        jdbc.update("update foods set is_active = false where id = ?::uuid", a);

        add(token, entry(today(), "LUNCH", a, 1)).andExpect(status().isUnprocessableContent())
            .andExpect(jsonPath("$.code").value("FOOD_INACTIVE"));
        add(token, entry(today(), "LUNCH", UUID.randomUUID().toString(), 1)).andExpect(status().isNotFound());
        assertThat(entryCount(token)).isEqualTo(1);

        getPlan(token, today()).andExpect(jsonPath("$.meals.LUNCH[0].foodName").value("Món A"));
        update(token, entryId, Map.of("servings", 2)).andExpect(status().isOk())
            .andExpect(jsonPath("$.totals.kcal").value(400.0));
        remove(token, entryId).andExpect(status().isOk()).andExpect(jsonPath("$.entryCount").value(0));
    }

    // M08, A9 — B không đọc/sửa/xóa được mục của A; ngày và tài khoản không trộn dữ liệu.
    @Test
    void entriesAreIsolatedPerUser() throws Exception {
        String tokenA = newUser();
        String tokenB = newUser();
        String a = foodA();
        String created = body(add(tokenA, entry(today(), "LUNCH", a, 1)).andExpect(status().isCreated()));
        String entryId = JsonPath.read(created, "$.meals.LUNCH[0].id");

        getPlan(tokenB, today()).andExpect(jsonPath("$.entryCount").value(0));
        update(tokenB, entryId, Map.of("servings", 5)).andExpect(status().isNotFound())
            .andExpect(jsonPath("$.code").value("NOT_FOUND"));
        remove(tokenB, entryId).andExpect(status().isNotFound());
        getPlan(tokenA, today()).andExpect(jsonPath("$.meals.LUNCH[0].servings").value(1.0));
        getPlan(tokenA, today().minusDays(1)).andExpect(jsonPath("$.entryCount").value(0));
        assertThat(planCount(tokenB)).isZero();

        mvc.perform(get(PLANS)).andExpect(status().isUnauthorized());
        mvc.perform(post(ENTRIES).contentType(MediaType.APPLICATION_JSON)
            .content(JSON.writeValueAsString(entry(today(), "LUNCH", a, 1)))).andExpect(status().isUnauthorized());
    }

    // M09, A7, A8, NUT-BR09 — so với mục tiêu hiện tại; vượt thì remaining âm; đổi hồ sơ không đổi mục đã ghi.
    @Test
    void comparesWithCurrentTarget() throws Exception {
        String token = newUser();
        String a = foodA();
        LocalDate yesterday = today().minusDays(1);
        add(token, entry(yesterday, "DINNER", a, 1)).andExpect(status().isCreated())
            .andExpect(jsonPath("$.targets").doesNotExist());

        putProfile(token, "65");
        String plan = body(getPlan(token, yesterday).andExpect(status().isOk())
            .andExpect(jsonPath("$.targets.kcal").isNumber())
            .andExpect(jsonPath("$.targetsCalculatedAt").isNotEmpty()));
        double target = ((Number) JsonPath.read(plan, "$.targets.kcal")).doubleValue();
        double remaining = ((Number) JsonPath.read(plan, "$.remaining.kcal")).doubleValue();
        assertThat(remaining).isEqualTo(target - 200.0);

        add(token, entry(today(), "LUNCH", a, 20)).andExpect(status().isCreated())
            .andExpect(jsonPath("$.remaining.kcal").value(target - 4000.0));
        assertThat(target - 4000.0).isNegative();

        putProfile(token, "80");
        String after = body(getPlan(token, yesterday));
        assertThat(((Number) JsonPath.read(after, "$.targets.kcal")).doubleValue()).isGreaterThan(target);
        assertThat(((Number) JsonPath.read(after, "$.totals.kcal")).doubleValue()).isEqualTo(200.0);
    }

    // M10, BR-N07 — ngày theo múi giờ user; tối đa 7 ngày tới; ngày quá khứ ghi được.
    @Test
    void datesFollowUserTimezone() throws Exception {
        String ahead = newUser();
        String behind = newUser();
        jdbc.update("update users set timezone = 'Pacific/Kiritimati' where id = ?::uuid", userId(ahead));
        jdbc.update("update users set timezone = 'Pacific/Pago_Pago' where id = ?::uuid", userId(behind));
        // UTC+14 và UTC−11 cách nhau 25 giờ: luôn khác ngày.
        LocalDate todayAhead = LocalDate.now(ZoneId.of("Pacific/Kiritimati"));
        LocalDate todayBehind = LocalDate.now(ZoneId.of("Pacific/Pago_Pago"));
        assertThat(todayAhead).isAfter(todayBehind);

        getPlan(ahead, null).andExpect(jsonPath("$.date").value(todayAhead.toString()));
        getPlan(behind, null).andExpect(jsonPath("$.date").value(todayBehind.toString()));

        String a = foodA();
        LocalDate lastAhead = todayAhead.plusDays(7);
        add(ahead, entry(lastAhead, "LUNCH", a, 1)).andExpect(status().isCreated())
            .andExpect(jsonPath("$.date").value(lastAhead.toString()));
        add(ahead, entry(lastAhead.plusDays(1), "LUNCH", a, 1)).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.date").exists());
        // Cùng ngày đó là quá 7 ngày với user ở múi giờ chậm hơn.
        add(behind, entry(lastAhead, "LUNCH", a, 1)).andExpect(status().isBadRequest());
        add(behind, entry(todayBehind.minusDays(30), "LUNCH", a, 1)).andExpect(status().isCreated());
        assertThat(count("select count(*) from meal_plans where user_id = ?::uuid and plan_date = ?",
            userId(ahead), lastAhead)).isEqualTo(1);
    }
}
