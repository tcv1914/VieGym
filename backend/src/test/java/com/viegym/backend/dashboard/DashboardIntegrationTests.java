package com.viegym.backend.dashboard;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.viegym.backend.TestcontainersConfiguration;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
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

/** D01–D09 trong plan/huong-dan-ngay-11.md §6, theo contract docs/05 §11 và docs/25. */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class DashboardIntegrationTests {
    private static final String DASHBOARD = "/api/v1/dashboard";
    private static final String PASSWORD = "Matkhau123";
    private static final ZoneId ZONE = ZoneId.of("Asia/Ho_Chi_Minh");
    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final String PUSH_UP = "485e3b1c-daf3-5a2c-9b07-7093d2b0987d";
    private static final String GOBLET_SQUAT = "2e724aa8-9b90-521e-afcd-f91c25632d60";

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

    // ---------- helpers ----------

    private static LocalDate today() {
        return LocalDate.now(ZONE);
    }

    private String fixtureFood(String name, String kcal, String protein, String carbs, String fat) {
        String code = "TEST-" + UUID.randomUUID().toString().substring(0, 8);
        String id = jdbc.queryForObject("""
            insert into foods (code, name, name_search, category_id, serving_description, kcal_per_serving,
                               protein_per_serving, carbs_per_serving, fat_per_serving, data_quality, source)
            values (?, ?, ?, (select id from food_categories order by sort_order limit 1), '1 phần test',
                    ?::numeric, ?::numeric, ?::numeric, ?::numeric, 'SOURCED', 'Fixture test ngày 11')
            returning id::text
            """, String.class, code, name, name.toLowerCase(), kcal, protein, carbs, fat);
        fixtureFoods.add(id);
        return id;
    }

    private String newUser() throws Exception {
        String email = "d" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
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

    private ResultActions dashboard(String token, LocalDate date) throws Exception {
        return call(get(DASHBOARD + (date == null ? "" : "?date=" + date)), token, null);
    }

    private static String body(ResultActions result) throws Exception {
        return result.andReturn().getResponse().getContentAsString();
    }

    private String userId(String token) throws Exception {
        return JsonPath.read(body(call(get("/api/v1/users/me"), token, null).andExpect(status().isOk())), "$.id");
    }

    private void addEntry(String token, LocalDate date, String mealType, String foodId, double servings)
        throws Exception {
        call(post("/api/v1/meal-plans/entries"), token,
            Map.of("date", date.toString(), "mealType", mealType, "foodId", foodId, "servings", servings))
            .andExpect(status().isCreated());
    }

    private void putProfile(String token) throws Exception {
        String profile = """
            {"sex":"MALE","dateOfBirth":"%s","heightCm":170,"weightKg":65,
             "activityLevel":"MODERATE","goal":"GAIN_MUSCLE"}
            """.formatted(today().minusYears(22));
        call(put("/api/v1/health-profile/me"), token, profile).andExpect(status().isOk());
    }

    /** Giáo án 1 buổi "Buổi A" (Goblet Squat, Chống đẩy); trả id buổi. */
    private String workoutDay(String token) throws Exception {
        Map<String, Object> program = Map.of("name", "Dashboard", "days", List.of(Map.of("name", "Buổi A",
            "exercises", List.of(
                Map.of("exerciseId", GOBLET_SQUAT, "targetSets", 3, "targetReps", 10, "restSeconds", 90),
                Map.of("exerciseId", PUSH_UP, "targetSets", 3, "targetReps", 12, "restSeconds", 60)))));
        String created = body(call(post("/api/v1/workout-programs"), token, program).andExpect(status().isCreated()));
        return JsonPath.read(created, "$.days[0].id");
    }

    /** Tạo lịch hôm nay qua API rồi dời sang {@code date} (API không cho tạo lịch quá khứ). */
    private String schedule(String token, String dayId, LocalDate date, String status) throws Exception {
        String created = body(call(post("/api/v1/workout-schedules"), token,
            Map.of("workoutDayId", dayId, "scheduledDate", today().toString())).andExpect(status().isCreated()));
        String id = JsonPath.read(created, "$.id");
        jdbc.update("update workout_schedules set scheduled_date = ?, status = ? where id = ?::uuid", date, status, id);
        return id;
    }

    private static Map<String, Object> set(int reps, double kg) {
        return Map.of("reps", reps, "weightKg", kg);
    }

    /** Ghi buổi thật (2 bài × 3 hiệp) cho lịch hôm nay → lịch COMPLETED. */
    private String logWorkout(String token, String scheduleId) throws Exception {
        Map<String, Object> log = new HashMap<>();
        log.put("scheduleId", scheduleId);
        log.put("exercises", List.of(
            Map.of("exerciseId", GOBLET_SQUAT, "sets", List.of(set(10, 20), set(10, 20), set(8, 22.5))),
            Map.of("exerciseId", PUSH_UP, "sets", List.of(set(12, 0), set(10, 0), set(10, 0)))));
        Instant start = Instant.now().minus(1, ChronoUnit.HOURS).truncatedTo(ChronoUnit.SECONDS);
        log.put("startedAt", start.toString());
        log.put("endedAt", start.plus(45, ChronoUnit.MINUTES).toString());
        return JsonPath.read(body(call(post("/api/v1/workout-logs"), token, log).andExpect(status().isCreated())),
            "$.id");
    }

    // ---------- tests ----------

    // D01, D04, D05 — user mới: mọi khối có mặt, null/0/rỗng đúng nghĩa, không mục tiêu 0 giả, không chia 0.
    @Test
    void newUserGetsEmptyButCompleteShape() throws Exception {
        String token = newUser();
        LocalDate monday = today().with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
        dashboard(token, null).andExpect(status().isOk())
            .andExpect(jsonPath("$.date").value(today().toString()))
            .andExpect(jsonPath("$.timezone").value("Asia/Ho_Chi_Minh"))
            .andExpect(jsonPath("$.generatedAt").isNotEmpty())
            .andExpect(jsonPath("$.health.hasProfile").value(false))
            .andExpect(jsonPath("$.health.weightKg").doesNotExist())
            .andExpect(jsonPath("$.health.bmi").doesNotExist())
            .andExpect(jsonPath("$.health.latestWeightLog").doesNotExist())
            .andExpect(jsonPath("$.nutrition.entryCount").value(0))
            .andExpect(jsonPath("$.nutrition.totals.kcal").value(0.0))
            .andExpect(jsonPath("$.nutrition.targets").doesNotExist())
            .andExpect(jsonPath("$.nutrition.remaining").doesNotExist())
            .andExpect(jsonPath("$.training.today", hasSize(0)))
            .andExpect(jsonPath("$.training.next").doesNotExist())
            .andExpect(jsonPath("$.training.week.from").value(monday.toString()))
            .andExpect(jsonPath("$.training.week.to").value(monday.plusDays(6).toString()))
            .andExpect(jsonPath("$.training.week.scheduled").value(0))
            .andExpect(jsonPath("$.training.week.completed").value(0))
            .andExpect(jsonPath("$.training.week.cancelled").value(0));
        // GET không tạo dữ liệu.
        assertThat(jdbc.queryForObject("select count(*) from meal_plans where user_id = ?::uuid", Integer.class,
            userId(token))).isZero();
    }

    // D02 — fixture ngày 10 (A×1,5 + B×2 = 500/25/75/10); có hồ sơ → health + mục tiêu + còn lại.
    @Test
    void nutritionMatchesMealPlanFixture() throws Exception {
        String token = newUser();
        putProfile(token);
        String a = fixtureFood("Món A", "200", "10", "30", "4");
        String b = fixtureFood("Món B", "100", "5", "15", "2");
        addEntry(token, today(), "LUNCH", a, 1.5);
        addEntry(token, today(), "DINNER", b, 2);

        String mealPlan = body(call(get("/api/v1/meal-plans?date=" + today()), token, null));
        String target = JsonPath.read(mealPlan, "$.targets.kcal").toString();
        String remaining = JsonPath.read(mealPlan, "$.remaining.kcal").toString();

        dashboard(token, today()).andExpect(status().isOk())
            .andExpect(jsonPath("$.nutrition.entryCount").value(2))
            .andExpect(jsonPath("$.nutrition.totals.kcal").value(500.0))
            .andExpect(jsonPath("$.nutrition.totals.proteinG").value(25.0))
            .andExpect(jsonPath("$.nutrition.totals.carbsG").value(75.0))
            .andExpect(jsonPath("$.nutrition.totals.fatG").value(10.0))
            .andExpect(jsonPath("$.nutrition.targets.kcal").value(Double.parseDouble(target)))
            .andExpect(jsonPath("$.nutrition.remaining.kcal").value(Double.parseDouble(remaining)))
            .andExpect(jsonPath("$.nutrition.targetsCalculatedAt").isNotEmpty())
            .andExpect(jsonPath("$.health.hasProfile").value(true))
            .andExpect(jsonPath("$.health.weightKg").value(65.0))
            .andExpect(jsonPath("$.health.heightCm").value(170.0))
            .andExpect(jsonPath("$.health.bmi").value(22.49))
            .andExpect(jsonPath("$.health.goal").value("GAIN_MUSCLE"));

        // Ngày khác không lẫn số của hôm nay.
        dashboard(token, today().minusDays(1))
            .andExpect(jsonPath("$.nutrition.entryCount").value(0))
            .andExpect(jsonPath("$.nutrition.totals.kcal").value(0.0));
    }

    // D03 — tuần có 3 lịch (2 COMPLETED, 1 SCHEDULED) + 1 CANCELLED → 2/3, không 2/4.
    @Test
    void weeklyProgressExcludesCancelled() throws Exception {
        String token = newUser();
        String day = workoutDay(token);
        LocalDate monday = LocalDate.of(2026, 11, 2);
        schedule(token, day, monday, "COMPLETED");
        schedule(token, day, monday.plusDays(2), "COMPLETED");
        schedule(token, day, monday.plusDays(4), "SCHEDULED");
        schedule(token, day, monday.plusDays(4), "CANCELLED");

        dashboard(token, monday.plusDays(4)).andExpect(status().isOk())
            .andExpect(jsonPath("$.training.week.from").value("2026-11-02"))
            .andExpect(jsonPath("$.training.week.to").value("2026-11-08"))
            .andExpect(jsonPath("$.training.week.scheduled").value(3))
            .andExpect(jsonPath("$.training.week.completed").value(2))
            .andExpect(jsonPath("$.training.week.cancelled").value(1))
            .andExpect(jsonPath("$.training.today", hasSize(2)))
            .andExpect(jsonPath("$.training.today[0].name").value("Buổi A"))
            .andExpect(jsonPath("$.training.today[0].programName").value("Dashboard"));
    }

    // D06 — thêm món / hoàn thành buổi → lần đọc sau phản ánh ngay; workoutLogId để mở kết quả; next đổi.
    @Test
    void reflectsWritesImmediately() throws Exception {
        String token = newUser();
        String food = fixtureFood("Món A", "200", "10", "30", "4");
        String day = workoutDay(token);
        String scheduleId = schedule(token, day, today(), "SCHEDULED");

        dashboard(token, null)
            .andExpect(jsonPath("$.training.today[0].scheduleId").value(scheduleId))
            .andExpect(jsonPath("$.training.today[0].status").value("SCHEDULED"))
            .andExpect(jsonPath("$.training.today[0].workoutLogId").doesNotExist())
            .andExpect(jsonPath("$.training.next.scheduleId").value(scheduleId))
            .andExpect(jsonPath("$.training.week.completed").value(0));

        addEntry(token, today(), "LUNCH", food, 1);
        String logId = logWorkout(token, scheduleId);

        dashboard(token, null)
            .andExpect(jsonPath("$.nutrition.totals.kcal").value(200.0))
            .andExpect(jsonPath("$.training.today[0].status").value("COMPLETED"))
            .andExpect(jsonPath("$.training.today[0].workoutLogId").value(logId))
            .andExpect(jsonPath("$.training.next").doesNotExist())
            .andExpect(jsonPath("$.training.week.scheduled").value(1))
            .andExpect(jsonPath("$.training.week.completed").value(1));
    }

    // next theo hôm nay thực, không theo ngày đang xem; lịch xa hơn 30 ngày không tính.
    @Test
    void nextIsRelativeToRealToday() throws Exception {
        String token = newUser();
        String day = workoutDay(token);
        schedule(token, day, today().minusDays(3), "SCHEDULED");
        String soon = schedule(token, day, today().plusDays(5), "SCHEDULED");
        schedule(token, day, today().plusDays(2), "CANCELLED");

        dashboard(token, today().minusDays(10))
            .andExpect(jsonPath("$.training.next.scheduleId").value(soon))
            .andExpect(jsonPath("$.training.next.scheduledDate").value(today().plusDays(5).toString()));

        jdbc.update("update workout_schedules set scheduled_date = ? where id = ?::uuid", today().plusDays(30), soon);
        dashboard(token, null).andExpect(jsonPath("$.training.next").doesNotExist());
    }

    // D07 — A/B: B không thấy dữ liệu A; không có tham số userId.
    @Test
    void usersSeeOnlyTheirOwnData() throws Exception {
        String a = newUser();
        String b = newUser();
        putProfile(a);
        addEntry(a, today(), "LUNCH", fixtureFood("Món A", "200", "10", "30", "4"), 1);
        schedule(a, workoutDay(a), today(), "SCHEDULED");

        dashboard(b, null).andExpect(status().isOk())
            .andExpect(jsonPath("$.health.hasProfile").value(false))
            .andExpect(jsonPath("$.nutrition.entryCount").value(0))
            .andExpect(jsonPath("$.training.today", hasSize(0)))
            .andExpect(jsonPath("$.training.next").doesNotExist());
        call(get(DASHBOARD + "?userId=" + userId(a)), b, null)
            .andExpect(jsonPath("$.nutrition.entryCount").value(0));
        mvc.perform(get(DASHBOARD)).andExpect(status().isUnauthorized());
    }

    // D08 — ranh giới tuần (CN thuộc tuần trước, T2 mở tuần mới) và "hôm nay" theo múi giờ user.
    @Test
    void weekBoundaryAndUserTimezone() throws Exception {
        String token = newUser();
        String day = workoutDay(token);
        LocalDate sunday = LocalDate.of(2026, 11, 8);
        schedule(token, day, sunday, "COMPLETED");
        schedule(token, day, sunday.plusDays(1), "SCHEDULED");

        dashboard(token, sunday)
            .andExpect(jsonPath("$.training.week.from").value("2026-11-02"))
            .andExpect(jsonPath("$.training.week.scheduled").value(1))
            .andExpect(jsonPath("$.training.week.completed").value(1));
        dashboard(token, sunday.plusDays(1))
            .andExpect(jsonPath("$.training.week.from").value("2026-11-09"))
            .andExpect(jsonPath("$.training.week.scheduled").value(1))
            .andExpect(jsonPath("$.training.week.completed").value(0));

        // UTC+14 và UTC−11 luôn khác ngày: mặc định phải theo múi giờ của user, không theo máy chủ.
        for (String zone : List.of("Pacific/Kiritimati", "Pacific/Pago_Pago")) {
            jdbc.update("update users set timezone = ? where id = ?::uuid", zone, userId(token));
            dashboard(token, null)
                .andExpect(jsonPath("$.timezone").value(zone))
                .andExpect(jsonPath("$.date").value(LocalDate.now(ZoneId.of(zone)).toString()));
        }
    }

    // D09 — nhiều món + nhiều bài/hiệp cùng ngày: tổng không bị nhân.
    @Test
    void manyEntriesAndSetsAreNotMultiplied() throws Exception {
        String token = newUser();
        String a = fixtureFood("Món A", "200", "10", "30", "4");
        String b = fixtureFood("Món B", "100", "5", "15", "2");
        addEntry(token, today(), "BREAKFAST", a, 1);
        addEntry(token, today(), "LUNCH", a, 1);
        addEntry(token, today(), "DINNER", b, 1);
        String day = workoutDay(token);
        logWorkout(token, schedule(token, day, today(), "SCHEDULED"));
        logWorkout(token, schedule(token, day, today(), "SCHEDULED"));

        dashboard(token, null)
            .andExpect(jsonPath("$.nutrition.entryCount").value(3))
            .andExpect(jsonPath("$.nutrition.totals.kcal").value(500.0))
            .andExpect(jsonPath("$.nutrition.totals.proteinG").value(25.0))
            .andExpect(jsonPath("$.training.today", hasSize(2)))
            .andExpect(jsonPath("$.training.week.scheduled").value(2))
            .andExpect(jsonPath("$.training.week.completed").value(2));
    }

    @Test
    void rejectsInvalidDate() throws Exception {
        String token = newUser();
        dashboard(token, LocalDate.of(1999, 12, 31)).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        call(get(DASHBOARD + "?date=abc"), token, null).andExpect(status().isBadRequest());
    }
}
