package com.viegym.backend.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.viegym.backend.TestcontainersConfiguration;
import com.viegym.backend.auth.repository.UserRepository;
import jakarta.validation.Validator;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
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
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.json.JsonMapper;

/** AD01–AD09 của plan/huong-dan-ngay-14.md §5 theo docs/05 §13 và docs/31. */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class AdminIntegrationTests {
    private static final String PASSWORD = "Matkhau123";
    private static final ZoneId ZONE = ZoneId.of("Asia/Ho_Chi_Minh");
    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final String FOODS = "/api/v1/admin/foods";
    private static final String EXERCISES = "/api/v1/admin/exercises";
    private static final String USERS = "/api/v1/admin/users";
    // Seed V5.
    private static final String PUSH_UP = "485e3b1c-daf3-5a2c-9b07-7093d2b0987d";

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcTemplate jdbc;

    @Autowired
    UserRepository userRepository;

    @Autowired
    PasswordEncoder passwordEncoder;

    @Autowired
    Validator validator;

    @Autowired
    Clock clock;

    @Autowired
    TransactionTemplate tx;

    /** Catalog test khác đếm chính xác số món/bài seed: xóa bản ghi admin test tạo (mã ADM-/admin-). */
    @AfterEach
    void removeCreatedCatalog() {
        jdbc.update("delete from meal_entries where food_id in (select id from foods where code like 'ADM-%')");
        jdbc.update("delete from foods where code like 'ADM-%'");
        String adminDays = "select workout_day_id from workout_exercises where exercise_id in "
            + "(select id from exercises where code like 'admin-%')";
        jdbc.update("delete from workout_schedules where workout_day_id in (" + adminDays + ")");
        jdbc.update("delete from workout_days where id in (" + adminDays + ")");
        jdbc.update("delete from exercises where code like 'admin-%'");
    }

    // AD01 — USER gọi thẳng API admin: 403; chưa đăng nhập: 401. Không có DELETE.
    @Test
    void onlyAdminsReachAdminApi() throws Exception {
        Account user = newUser();
        for (String path : List.of(FOODS, EXERCISES, USERS, "/api/v1/admin/food-options")) {
            call(get(path), user.access, null).andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
            mvc.perform(get(path)).andExpect(status().isUnauthorized());
        }
        call(post(FOODS), user.access, food("Món lén", "200", "10", "30", "5", true)).andExpect(status().isForbidden());
        call(put(USERS + "/" + user.id + "/status"), user.access, Map.of("status", "LOCKED", "reason", "x"))
            .andExpect(status().isForbidden());
        // Field role trong đăng ký bị bỏ qua: không tự thành ADMIN.
        String email = "r" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\",\"fullName\":\"X\",\"role\":\"ADMIN\"}"
                    .formatted(email, PASSWORD)))
            .andExpect(status().isCreated());
        assertThat(jdbc.queryForObject("select role from users where email = ?", String.class, email)).isEqualTo("USER");

        Account admin = newAdmin();
        call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete(FOODS + "/" + UUID.randomUUID()),
            admin.access, null).andExpect(status().isMethodNotAllowed());
    }

    // AD02 — admin tạo món đủ nguồn → user tìm thấy món active; có audit CREATE.
    @Test
    void createdFoodIsVisibleToUsers() throws Exception {
        Account admin = newAdmin();
        Account user = newUser();
        String name = "Bún thử " + UUID.randomUUID().toString().substring(0, 6);
        String created = body(call(post(FOODS), admin.access, food(name, "400", "20", "60", "8.9", true))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.code").value(org.hamcrest.Matchers.startsWith("ADM-")))
            .andExpect(jsonPath("$.revision").value(1))
            .andExpect(jsonPath("$.active").value(true))
            .andExpect(jsonPath("$.category.code").value("BANH_DA_BUN_PHO")));
        String id = JsonPath.read(created, "$.id");

        call(get("/api/v1/foods?keyword=" + name), user.access, null).andExpect(status().isOk())
            .andExpect(jsonPath("$.items.length()").value(1))
            .andExpect(jsonPath("$.items[0].id").value(id));
        call(get("/api/v1/foods/" + id), user.access, null).andExpect(status().isOk())
            .andExpect(jsonPath("$.source").value("Tự đo tại bếp thử"));
        assertThat(audit("FOOD", id)).containsExactly("CREATE:null");
    }

    @Test
    void invalidFoodIsRejected() throws Exception {
        Account admin = newAdmin();
        Map<String, Object> noSource = food("Thiếu nguồn", "400", "20", "60", "8.9", true);
        noSource.put("source", " ");
        expectFieldError(call(post(FOODS), admin.access, noSource), "source");

        Map<String, Object> sizeOnly = food("Thiếu đơn vị", "400", "20", "60", "8.9", true);
        sizeOnly.put("servingSize", 300);
        expectFieldError(call(post(FOODS), admin.access, sizeOnly), "servingUnit");

        // 4×20 + 4×60 + 9×8,9 = 400,1 kcal; ghi 600 → lệch > 15% → không được hiển thị.
        expectFieldError(call(post(FOODS), admin.access, food("Lệch kcal", "600", "20", "60", "8.9", true)),
            "kcalPerServing");
        // Để ẩn (chờ rà) thì lưu được.
        call(post(FOODS), admin.access, food("Lệch kcal ẩn", "600", "20", "60", "8.9", false))
            .andExpect(status().isCreated()).andExpect(jsonPath("$.active").value(false));
        // Nước: 0 kcal, 0 đạm/bột/béo là hợp lệ.
        call(post(FOODS), admin.access, food("Nước lọc thử", "0", "0", "0", "0", true)).andExpect(status().isCreated());

        Map<String, Object> js = food("URL xấu", "400", "20", "60", "8.9", true);
        js.put("imageUrl", "javascript:alert(1)");
        expectFieldError(call(post(FOODS), admin.access, js), "imageUrl");

        Map<String, Object> withRevision = food("Có revision", "400", "20", "60", "8.9", true);
        withRevision.put("revision", 1);
        expectFieldError(call(post(FOODS), admin.access, withRevision), "revision");

        Map<String, Object> badCategory = food("Danh mục lạ", "400", "20", "60", "8.9", true);
        badCategory.put("categoryCode", "KHONG_CO");
        expectFieldError(call(post(FOODS), admin.access, badCategory), "categoryCode");

        expectFieldError(call(post(FOODS), admin.access, food("Âm", "400", "-1", "60", "8.9", true)),
            "proteinPerServing");
    }

    // AD03 — hai cửa sổ sửa cùng revision: request sau 409; lưu không đổi gì thì không tăng revision.
    @Test
    void staleRevisionConflicts() throws Exception {
        Account admin = newAdmin();
        String id = JsonPath.read(body(call(post(FOODS), admin.access,
            food("Phở thử " + UUID.randomUUID().toString().substring(0, 6), "400", "20", "60", "8.9", true))
            .andExpect(status().isCreated())), "$.id");

        Map<String, Object> unchanged = food(JsonPath.read(body(call(get(FOODS + "/" + id), admin.access, null)),
            "$.name"), "400", "20", "60", "8.9", true);
        unchanged.put("revision", 1);
        call(put(FOODS + "/" + id), admin.access, unchanged).andExpect(status().isOk())
            .andExpect(jsonPath("$.revision").value(1));

        Map<String, Object> first = new HashMap<>(unchanged);
        first.put("kcalPerServing", 410);
        Map<String, Object> second = new HashMap<>(unchanged);
        second.put("servingDescription", "1 tô lớn");
        call(put(FOODS + "/" + id), admin.access, first).andExpect(status().isOk())
            .andExpect(jsonPath("$.revision").value(2));
        call(put(FOODS + "/" + id), admin.access, second).andExpect(status().isConflict())
            .andExpect(jsonPath("$.code").value("VERSION_CONFLICT"))
            .andExpect(jsonPath("$.currentRevision").value(2));
        call(get(FOODS + "/" + id), admin.access, null)
            .andExpect(jsonPath("$.servingDescription").value("1 tô"));

        Map<String, Object> missing = new HashMap<>(unchanged);
        missing.remove("revision");
        expectFieldError(call(put(FOODS + "/" + id), admin.access, missing), "revision");
        call(put(FOODS + "/" + UUID.randomUUID()), admin.access, unchanged).andExpect(status().isNotFound());
        assertThat(audit("FOOD", id)).containsExactly("CREATE:null", "UPDATE:kcalPerServing");
    }

    @Test
    void concurrentEditsWithSameRevisionSucceedOnce() throws Exception {
        Account admin = newAdmin();
        String id = JsonPath.read(body(call(post(FOODS), admin.access,
            food("Song song " + UUID.randomUUID().toString().substring(0, 6), "400", "20", "60", "8.9", true))), "$.id");
        CountDownLatch start = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            List<Future<Integer>> results = List.of("1 bát", "1 đĩa").stream().map(label -> {
                Map<String, Object> body = food("Song song", "400", "20", "60", "8.9", true);
                body.put("servingDescription", label);
                body.put("revision", 1);
                Callable<Integer> c = () -> {
                    start.await();
                    return call(put(FOODS + "/" + id), admin.access, body).andReturn().getResponse().getStatus();
                };
                return pool.submit(c);
            }).toList();
            start.countDown();
            assertThat(List.of(results.get(0).get(), results.get(1).get())).containsExactlyInAnyOrder(200, 409);
        } finally {
            pool.shutdown();
        }
        assertThat(jdbc.queryForObject("select revision from foods where id = ?::uuid", Integer.class, id)).isEqualTo(2);
    }

    // AD04 — ẩn món đã có trong thực đơn: mất khỏi tìm kiếm, thực đơn cũ giữ đủ snapshot;
    // sửa số liệu không đổi snapshot (NUT-BR05).
    @Test
    void deactivatedFoodKeepsMealSnapshots() throws Exception {
        Account admin = newAdmin();
        Account user = newUser();
        String name = "Cơm thử " + UUID.randomUUID().toString().substring(0, 6);
        String id = JsonPath.read(body(call(post(FOODS), admin.access, food(name, "400", "20", "60", "8.9", true))),
            "$.id");
        LocalDate today = LocalDate.now(ZONE);
        call(post("/api/v1/meal-plans/entries"), user.access,
            Map.of("date", today.toString(), "mealType", "LUNCH", "foodId", id, "servings", 1.5))
            .andExpect(status().isCreated());

        Map<String, Object> edit = food(name, "500", "25", "75", "11.1", false);
        edit.put("revision", 1);
        call(put(FOODS + "/" + id), admin.access, edit).andExpect(status().isOk())
            .andExpect(jsonPath("$.active").value(false)).andExpect(jsonPath("$.revision").value(2));

        call(get("/api/v1/foods?keyword=" + name), user.access, null).andExpect(jsonPath("$.items.length()").value(0));
        call(get("/api/v1/foods/" + id), user.access, null).andExpect(status().isNotFound());
        call(get("/api/v1/meal-plans?date=" + today), user.access, null).andExpect(status().isOk())
            .andExpect(jsonPath("$.meals.LUNCH[0].foodName").value(name))
            .andExpect(jsonPath("$.meals.LUNCH[0].kcal").value(600.0));
        call(post("/api/v1/meal-plans/entries"), user.access,
            Map.of("date", today.toString(), "mealType", "DINNER", "foodId", id, "servings", 1))
            .andExpect(status().isUnprocessableContent()).andExpect(jsonPath("$.code").value("FOOD_INACTIVE"));
        // Admin vẫn thấy món ẩn.
        call(get(FOODS + "?active=false&keyword=" + name), admin.access, null)
            .andExpect(jsonPath("$.items.length()").value(1));
        assertThat(audit("FOOD", id)).last().asString().startsWith("UPDATE:").contains("active", "kcalPerServing");

        // Chỉ bật lại → ACTIVATE.
        Map<String, Object> reactivate = food(name, "500", "25", "75", "11.1", true);
        reactivate.put("revision", 2);
        call(put(FOODS + "/" + id), admin.access, reactivate).andExpect(status().isOk());
        assertThat(audit("FOOD", id)).last().isEqualTo("ACTIVATE:active");
    }

    // AD05 — ẩn bài đã có lịch: lịch cũ vẫn hiển thị, bài không thêm mới được.
    @Test
    void deactivatedExerciseKeepsSchedules() throws Exception {
        Account admin = newAdmin();
        Account user = newUser();
        String name = "Bài thử " + UUID.randomUUID().toString().substring(0, 6);
        String created = body(call(post(EXERCISES), admin.access, exercise(name, true))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.code").value(org.hamcrest.Matchers.startsWith("admin-")))
            .andExpect(jsonPath("$.thumbnailPreviewUrl").value(org.hamcrest.Matchers.endsWith(
                "/media/exercises/0025-EIeI8Vf.jpg"))));
        String id = JsonPath.read(created, "$.id");
        call(get("/api/v1/exercises?keyword=" + name), user.access, null).andExpect(jsonPath("$.items.length()").value(1));

        String program = body(call(post("/api/v1/workout-programs"), user.access, Map.of("name", "Thử", "days",
            List.of(Map.of("name", "A", "exercises", List.of(
                Map.of("exerciseId", PUSH_UP, "targetSets", 3, "targetReps", 10, "restSeconds", 60),
                Map.of("exerciseId", id, "targetSets", 3, "targetReps", 10, "restSeconds", 60))))))
            .andExpect(status().isCreated()));
        String dayId = JsonPath.read(program, "$.days[0].id");
        String schedule = JsonPath.read(body(call(post("/api/v1/workout-schedules"), user.access,
            Map.of("workoutDayId", dayId, "scheduledDate", LocalDate.now(ZONE).plusDays(1).toString()))
            .andExpect(status().isCreated())), "$.id");

        Map<String, Object> hide = exercise(name, false);
        hide.put("revision", 1);
        call(put(EXERCISES + "/" + id), admin.access, hide).andExpect(status().isOk())
            .andExpect(jsonPath("$.revision").value(2));

        call(get("/api/v1/exercises?keyword=" + name), user.access, null).andExpect(jsonPath("$.items.length()").value(0));
        call(get("/api/v1/workout-schedules/" + schedule), user.access, null).andExpect(status().isOk())
            .andExpect(jsonPath("$.exercises[1].exerciseName").value(name))
            .andExpect(jsonPath("$.exercises[1].exerciseActive").value(false));
        call(post("/api/v1/workout-schedules"), user.access,
            Map.of("workoutDayId", dayId, "scheduledDate", LocalDate.now(ZONE).plusDays(2).toString()))
            .andExpect(status().isUnprocessableContent()).andExpect(jsonPath("$.code").value("EXERCISE_INACTIVE"));
        assertThat(audit("EXERCISE", id)).containsExactly("CREATE:null", "DEACTIVATE:active");
    }

    @Test
    void invalidExerciseIsRejected() throws Exception {
        Account admin = newAdmin();
        String name = "Trùng " + UUID.randomUUID().toString().substring(0, 6);
        call(post(EXERCISES), admin.access, exercise(name, true)).andExpect(status().isCreated());
        call(post(EXERCISES), admin.access, exercise(name.toUpperCase(), true)).andExpect(status().isConflict())
            .andExpect(jsonPath("$.code").value("EXERCISE_NAME_TAKEN"))
            .andExpect(jsonPath("$.fieldErrors.name").exists());

        for (String bad : List.of("../application.yaml", "exercises/khong-co.jpg", "javascript:alert(1)",
            "exercises/../../application.yaml")) {
            Map<String, Object> body = exercise("Media " + UUID.randomUUID(), true);
            body.put("thumbnailUrl", bad);
            expectFieldError(call(post(EXERCISES), admin.access, body), "thumbnailUrl");
        }
        Map<String, Object> typeOnly = exercise("Thiếu media " + UUID.randomUUID(), true);
        typeOnly.put("mediaType", "GIF");
        expectFieldError(call(post(EXERCISES), admin.access, typeOnly), "mediaUrl");

        Map<String, Object> external = exercise("Ngoài " + UUID.randomUUID(), true);
        external.put("thumbnailUrl", "https://example.com/a.jpg");
        external.put("mediaType", "VIDEO");
        external.put("mediaUrl", "https://example.com/a.mp4");
        call(post(EXERCISES), admin.access, external).andExpect(status().isCreated())
            .andExpect(jsonPath("$.thumbnailPreviewUrl").value("https://example.com/a.jpg"));

        Map<String, Object> noMedia = exercise("Không ảnh " + UUID.randomUUID(), true);
        noMedia.remove("thumbnailUrl");
        call(post(EXERCISES), admin.access, noMedia).andExpect(status().isCreated())
            .andExpect(jsonPath("$.thumbnailPreviewUrl").doesNotExist());

        Map<String, Object> blank = exercise("Thiếu hướng dẫn " + UUID.randomUUID(), true);
        blank.put("instructions", "  ");
        expectFieldError(call(post(EXERCISES), admin.access, blank), "instructions");
        call(get(EXERCISES + "?muscleGroup=KHONG_CO"), admin.access, null).andExpect(status().isBadRequest());
    }

    // AD06–AD07 — khóa A đang đăng nhập: request kế tiếp thất bại, refresh/login bị chặn;
    // mở khóa: đăng nhập mới được, phiên cũ vẫn chết.
    @Test
    void lockRevokesSessionsAndUnlockNeedsNewLogin() throws Exception {
        Account admin = newAdmin();
        Account a = newUser();
        call(get("/api/v1/users/me"), a.access, null).andExpect(status().isOk());

        expectFieldError(call(put(USERS + "/" + a.id + "/status"), admin.access, Map.of("status", "LOCKED")), "reason");
        call(put(USERS + "/" + a.id + "/status"), admin.access, Map.of("status", "LOCKED", "reason", "Spam"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("LOCKED"))
            .andExpect(jsonPath("$.passwordHash").doesNotExist());

        call(get("/api/v1/users/me"), a.access, null).andExpect(status().isUnauthorized());
        refresh(a.refresh).andExpect(status().isUnauthorized());
        login(a.email).andExpect(status().isForbidden()).andExpect(jsonPath("$.code").value("ACCOUNT_LOCKED"));
        assertThat(count("select count(*) from auth_sessions where user_id = ? and revoked_at is null", a.id)).isZero();

        // Khóa lại lần nữa: no-op, không thêm audit.
        call(put(USERS + "/" + a.id + "/status"), admin.access, Map.of("status", "LOCKED", "reason", "Lại"))
            .andExpect(status().isOk());
        call(put(USERS + "/" + a.id + "/status"), admin.access, Map.of("status", "ACTIVE"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("ACTIVE"));

        call(get("/api/v1/users/me"), a.access, null).andExpect(status().isUnauthorized());
        refresh(a.refresh).andExpect(status().isUnauthorized());
        String fresh = JsonPath.read(body(login(a.email).andExpect(status().isOk())), "$.accessToken");
        call(get("/api/v1/users/me"), fresh, null).andExpect(status().isOk());

        assertThat(jdbc.queryForList("""
            select action || ':' || coalesce(reason, '-') || ':' || actor_id from admin_audit_logs
            where entity_type = 'USER' and entity_id = ? order by created_at""", String.class, a.id))
            .containsExactly("LOCK:Spam:" + admin.id, "UNLOCK:-:" + admin.id);
    }

    // AD09 — admin không tự khóa, không khóa admin khác; không có API đọc dữ liệu sức khỏe của user khác.
    @Test
    void adminCannotLockSelfOrOtherAdmins() throws Exception {
        Account admin = newAdmin();
        Account other = newAdmin();
        call(put(USERS + "/" + admin.id + "/status"), admin.access, Map.of("status", "LOCKED", "reason", "x"))
            .andExpect(status().isUnprocessableContent())
            .andExpect(jsonPath("$.code").value("CANNOT_CHANGE_OWN_STATUS"));
        call(put(USERS + "/" + other.id + "/status"), admin.access, Map.of("status", "LOCKED", "reason", "x"))
            .andExpect(status().isUnprocessableContent())
            .andExpect(jsonPath("$.code").value("ADMIN_ACCOUNT_PROTECTED"));
        call(put(USERS + "/" + UUID.randomUUID() + "/status"), admin.access, Map.of("status", "LOCKED", "reason", "x"))
            .andExpect(status().isNotFound());
        call(get(USERS + "/" + other.id), admin.access, null).andExpect(status().isNotFound());
        call(get("/api/v1/admin/users/" + other.id + "/health-profile"), admin.access, null)
            .andExpect(status().isNotFound());
        assertThat(count("select count(*) from users where id = ? and status = 'ACTIVE'", other.id)).isEqualTo(1);
    }

    @Test
    void userListIsPagedSearchableAndHidesSecrets() throws Exception {
        Account admin = newAdmin();
        String tag = UUID.randomUUID().toString().substring(0, 8);
        for (int i = 0; i < 3; i++) {
            register("list" + i + tag + "@example.com", "Người " + tag);
        }
        String page0 = body(call(get(USERS + "?keyword=" + tag.toUpperCase() + "&size=2"), admin.access, null)
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.totalItems").value(3))
            .andExpect(jsonPath("$.items.length()").value(2))
            .andExpect(jsonPath("$.hasNext").value(true))
            .andExpect(jsonPath("$.items[0].passwordHash").doesNotExist())
            .andExpect(jsonPath("$.items[0].role").value("USER")));
        String page1 = body(call(get(USERS + "?keyword=" + tag + "&size=2&page=1"), admin.access, null)
            .andExpect(jsonPath("$.items.length()").value(1)));
        List<String> ids = new java.util.ArrayList<>(JsonPath.<List<String>>read(page0, "$.items[*].id"));
        ids.addAll(JsonPath.read(page1, "$.items[*].id"));
        assertThat(ids).doesNotHaveDuplicates().hasSize(3);
        assertThat(body(call(get(USERS + "?keyword=" + tag), admin.access, null)))
            .doesNotContain("bcrypt").doesNotContain("password");

        call(get(USERS + "?keyword=" + tag + "&status=LOCKED"), admin.access, null)
            .andExpect(jsonPath("$.totalItems").value(0));
        call(get(USERS + "?size=101"), admin.access, null).andExpect(status().isBadRequest());
        call(get(USERS + "?status=XYZ"), admin.access, null).andExpect(status().isBadRequest());
        // % và _ là chữ thường, không phải wildcard.
        call(get(USERS + "?keyword=%25"), admin.access, null).andExpect(status().isOk())
            .andExpect(jsonPath("$.totalItems").value(0));
    }

    // AD08 — ký tự HTML được lưu và trả nguyên văn (frontend hiển thị dạng chữ).
    @Test
    void htmlInNamesIsStoredAsText() throws Exception {
        Account admin = newAdmin();
        String name = "<img src=x onerror=alert(1)> " + UUID.randomUUID().toString().substring(0, 6);
        call(post(FOODS), admin.access, food(name, "400", "20", "60", "8.9", true)).andExpect(status().isCreated())
            .andExpect(jsonPath("$.name").value(name));
    }

    // docs/31 §2: tạo admin từ biến môi trường; không nâng quyền email USER có sẵn; cấu hình sai thì bỏ qua.
    @Test
    void bootstrapCreatesAdminOnlyForNewEmail() throws Exception {
        String email = "boot" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
        bootstrap(" " + email.toUpperCase() + " ", "Quantri2026");
        assertThat(jdbc.queryForObject("select role from users where email = ?", String.class, email)).isEqualTo("ADMIN");
        String access = JsonPath.read(body(login(email, "Quantri2026").andExpect(status().isOk())), "$.accessToken");
        call(get(FOODS), access, null).andExpect(status().isOk());
        // Chạy lại: không tạo thêm, không đổi mật khẩu.
        bootstrap(email, "Khac123456");
        assertThat(count("select count(*) from users where email = ?", email)).isEqualTo(1);
        login(email, "Quantri2026").andExpect(status().isOk());

        Account user = newUser();
        bootstrap(user.email, "Quantri2026");
        assertThat(jdbc.queryForObject("select role from users where email = ?", String.class, user.email))
            .isEqualTo("USER");

        String weak = "weak" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
        bootstrap(weak, "ngan");
        assertThat(count("select count(*) from users where email = ?", weak)).isZero();
    }

    // ---------- Hỗ trợ ----------

    private record Account(String email, UUID id, String access, String refresh) {
    }

    private void bootstrap(String email, String password) {
        AdminBootstrap runner = new AdminBootstrap(userRepository, passwordEncoder, validator, clock, email,
            password, "Quản trị thử");
        tx.executeWithoutResult(s -> runner.run(null));
    }

    private Account newUser() throws Exception {
        String email = "a" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
        register(email, "Test");
        return loginAccount(email);
    }

    private Account newAdmin() throws Exception {
        String email = "adm" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
        register(email, "Admin");
        jdbc.update("update users set role = 'ADMIN' where email = ?", email);
        return loginAccount(email);
    }

    private void register(String email, String fullName) throws Exception {
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\",\"fullName\":\"%s\"}".formatted(email, PASSWORD, fullName)))
            .andExpect(status().isCreated());
    }

    private Account loginAccount(String email) throws Exception {
        String body = body(login(email).andExpect(status().isOk()));
        return new Account(email, UUID.fromString(JsonPath.read(body, "$.user.id")), JsonPath.read(body, "$.accessToken"),
            JsonPath.read(body, "$.refreshToken"));
    }

    private ResultActions login(String email) throws Exception {
        return login(email, PASSWORD);
    }

    private ResultActions login(String email, String password) throws Exception {
        return mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
            .content("{\"email\":\"%s\",\"password\":\"%s\"}".formatted(email, password)));
    }

    private ResultActions refresh(String refreshToken) throws Exception {
        return mvc.perform(post("/api/v1/auth/refresh").contentType(MediaType.APPLICATION_JSON)
            .content("{\"refreshToken\":\"%s\"}".formatted(refreshToken)));
    }

    private ResultActions call(MockHttpServletRequestBuilder request, String token, Object body) throws Exception {
        request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token);
        if (body != null) {
            request.contentType(MediaType.APPLICATION_JSON).content(JSON.writeValueAsString(body));
        }
        return mvc.perform(request);
    }

    private static String body(ResultActions result) throws Exception {
        return result.andReturn().getResponse().getContentAsString();
    }

    private static void expectFieldError(ResultActions result, String field) throws Exception {
        result.andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
            .andExpect(jsonPath("$.fieldErrors." + field).exists());
    }

    private int count(String sql, Object... args) {
        return jdbc.queryForObject(sql, Integer.class, args);
    }

    private List<String> audit(String type, String id) {
        return jdbc.queryForList("""
            select action || ':' || coalesce(changed_fields, 'null') from admin_audit_logs
            where entity_type = ? and entity_id = ?::uuid order by created_at""", String.class, type, id);
    }

    private static Map<String, Object> food(String name, String kcal, String protein, String carbs, String fat,
                                            boolean active) {
        Map<String, Object> body = new HashMap<>();
        body.put("name", name);
        body.put("categoryCode", "BANH_DA_BUN_PHO");
        body.put("region", "HAN");
        body.put("servingDescription", "1 tô");
        body.put("kcalPerServing", new java.math.BigDecimal(kcal));
        body.put("proteinPerServing", new java.math.BigDecimal(protein));
        body.put("carbsPerServing", new java.math.BigDecimal(carbs));
        body.put("fatPerServing", new java.math.BigDecimal(fat));
        body.put("dataQuality", "ESTIMATED");
        body.put("source", "Tự đo tại bếp thử");
        body.put("active", active);
        return body;
    }

    private static Map<String, Object> exercise(String name, boolean active) {
        Map<String, Object> body = new HashMap<>();
        body.put("name", name);
        body.put("muscleGroup", "CHEST");
        body.put("equipment", "NONE");
        body.put("difficulty", "BEGINNER");
        body.put("instructions", "Bước 1\nBước 2");
        body.put("commonMistakes", "Lỗi 1");
        body.put("thumbnailUrl", "exercises/0025-EIeI8Vf.jpg");
        body.put("active", active);
        return body;
    }
}
