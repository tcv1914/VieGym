package com.viegym.backend.exercise;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.viegym.backend.TestcontainersConfiguration;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
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

/** Các tình huống EX01–EX11, EX16 trong plan/huong-dan-ngay-6.md §8, trên PostgreSQL thật. */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class ExerciseLibraryIntegrationTests {
    private static final String PASSWORD = "Matkhau123";
    private static final int SEEDED_ACTIVE = 32;
    // Bài ẩn khớp mọi bộ lọc của bài "Đẩy ngực với tạ đơn": lộ ra ở đâu là test bắt được.
    private static final UUID INACTIVE_ID = UUID.fromString("00000000-0000-0000-0000-0000000e0699");
    private static final String PUSH_UP_ID = "485e3b1c-daf3-5a2c-9b07-7093d2b0987d";

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcTemplate jdbc;

    private String access;

    @BeforeEach
    void setUp() throws Exception {
        jdbc.update("""
            insert into exercises (id, code, name, name_search, muscle_group, equipment, difficulty,
                                   instructions, common_mistakes, is_active)
            values (?, 'test-inactive', 'Đẩy ngực ẩn (kiểm thử)', 'day nguc an (kiem thu)', 'CHEST', 'DUMBBELL',
                    'BEGINNER', 'Bước', 'Lỗi', false)
            on conflict (code) do nothing
            """, INACTIVE_ID);
        access = newAccess();
    }

    // EX01, EX06 — đi hết các trang: đủ bài active, không trùng, không lẫn bài ẩn.
    @Test
    void pagesCoverAllActiveExercisesWithoutDuplicates() throws Exception {
        List<String> ids = new ArrayList<>();
        for (int page = 0; page < 4; page++) {
            String body = list(Map.of("page", page, "size", 10)).andExpect(status().isOk())
                .andExpect(jsonPath("$.page").value(page))
                .andExpect(jsonPath("$.size").value(10))
                .andExpect(jsonPath("$.totalItems").value(SEEDED_ACTIVE))
                .andExpect(jsonPath("$.totalPages").value(4))
                .andExpect(jsonPath("$.hasNext").value(page < 3))
                .andReturn().getResponse().getContentAsString();
            ids.addAll(JsonPath.read(body, "$.items[*].id"));
        }
        assertThat(ids).hasSize(SEEDED_ACTIVE).doesNotHaveDuplicates().doesNotContain(INACTIVE_ID.toString());

        list(Map.of("page", 4, "size", 10)).andExpect(status().isOk())
            .andExpect(jsonPath("$.items").isEmpty())
            .andExpect(jsonPath("$.hasNext").value(false));

        list(Map.of()).andExpect(jsonPath("$.size").value(20))
            .andExpect(jsonPath("$.items.length()").value(20))
            .andExpect(jsonPath("$.items[0].thumbnailUrl").exists())
            .andExpect(jsonPath("$.items[0].instructions").doesNotExist());
    }

    // EX02
    @Test
    void keywordIgnoresMarksCaseAndSpaces() throws Exception {
        Set<String> expected = Set.of("Đẩy ngực với tạ đòn (Barbell Bench Press)",
            "Đẩy ngực với tạ đơn (Dumbbell Bench Press)",
            "Đẩy ngực dốc lên với tạ đơn (Incline Dumbbell Press)");
        for (String keyword : List.of("Đẩy ngực", "day nguc", "  DAY   NGUC  ", "ĐẨY NGỰC")) {
            assertThat(names(Map.of("keyword", keyword))).as(keyword).isEqualTo(expected);
        }
        assertThat(names(Map.of("keyword", "bench press"))).hasSize(2);
        // Keyword chỉ có khoảng trắng = không tìm theo tên.
        list(Map.of("keyword", "   ")).andExpect(jsonPath("$.totalItems").value(SEEDED_ACTIVE));
    }

    // EX03, EX04, EX05
    @Test
    void filtersCombineWithAnd() throws Exception {
        list(Map.of("muscleGroup", "CHEST")).andExpect(jsonPath("$.totalItems").value(4))
            .andExpect(jsonPath("$.items[*].muscleGroup", everyItemIs("CHEST")));
        list(Map.of("equipment", "MACHINE")).andExpect(jsonPath("$.totalItems").value(2));
        list(Map.of("difficulty", "ADVANCED")).andExpect(jsonPath("$.totalItems").value(2));

        assertThat(names(Map.of("muscleGroup", "CHEST", "equipment", "DUMBBELL", "difficulty", "BEGINNER")))
            .containsExactly("Đẩy ngực với tạ đơn (Dumbbell Bench Press)");
        assertThat(names(Map.of("keyword", "tạ đơn", "muscleGroup", "SHOULDERS"))).hasSize(3);

        // Kết hợp hợp lệ nhưng không có bài: 200 rỗng, không phải lỗi.
        list(Map.of("muscleGroup", "CHEST", "equipment", "MACHINE")).andExpect(status().isOk())
            .andExpect(jsonPath("$.items").isEmpty())
            .andExpect(jsonPath("$.totalItems").value(0))
            .andExpect(jsonPath("$.totalPages").value(0));
        // Tham số rỗng coi như không lọc.
        list(Map.of("muscleGroup", "")).andExpect(jsonPath("$.totalItems").value(SEEDED_ACTIVE));
    }

    // EX07
    @Test
    void invalidQueryIsRejected() throws Exception {
        record Case(String param, Object value) {
        }
        List<Case> cases = List.of(new Case("page", -1), new Case("page", "abc"), new Case("size", 0),
            new Case("size", 101), new Case("muscleGroup", "FOO"), new Case("muscleGroup", "chest"),
            new Case("equipment", "BODYWEIGHT"), new Case("difficulty", "EASY"),
            new Case("keyword", "a".repeat(101)));
        for (Case c : cases) {
            list(Map.of(c.param, c.value)).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.fieldErrors." + c.param).exists());
        }
        list(Map.of("size", 100)).andExpect(status().isOk());
    }

    // EX08 — media là key tương đối, API ghép thành URL theo host của request; file tải được không cần token.
    @Test
    void detailHasInstructionsAndReachableMedia() throws Exception {
        String body = detail(PUSH_UP_ID).andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Hít đất (Push-up)"))
            .andExpect(jsonPath("$.muscleGroup").value("CHEST"))
            .andExpect(jsonPath("$.equipment").value("NONE"))
            .andExpect(jsonPath("$.mediaType").value("GIF"))
            .andExpect(jsonPath("$.mediaUrl").value("http://localhost/media/exercises/0662-I4hDWkc.gif"))
            .andExpect(jsonPath("$.thumbnailUrl").value("http://localhost/media/exercises/0662-I4hDWkc.jpg"))
            .andExpect(jsonPath("$.mediaLicense").value(org.hamcrest.Matchers.containsString("Gym visual")))
            .andReturn().getResponse().getContentAsString();
        String instructions = JsonPath.read(body, "$.instructions");
        assertThat(instructions.split("\n")).hasSize(4);
        assertThat(JsonPath.<String>read(body, "$.commonMistakes").split("\n")).hasSize(3);

        mvc.perform(get("/media/exercises/0662-I4hDWkc.gif")).andExpect(status().isOk())
            .andExpect(content().contentType("image/gif"));
        mvc.perform(get("/media/exercises/khong-co.gif")).andExpect(status().isNotFound());

        String plankId = jdbc.queryForObject("select id::text from exercises where code = 'plank'", String.class);
        detail(plankId).andExpect(status().isOk())
            .andExpect(jsonPath("$.mediaUrl").doesNotExist())
            .andExpect(jsonPath("$.mediaType").doesNotExist())
            .andExpect(jsonPath("$.thumbnailUrl").doesNotExist());
    }

    // EX09
    @Test
    void inactiveUnknownAndMalformedIds() throws Exception {
        detail(INACTIVE_ID.toString()).andExpect(status().isNotFound())
            .andExpect(jsonPath("$.code").value("NOT_FOUND"));
        detail(UUID.randomUUID().toString()).andExpect(status().isNotFound());
        detail("abc").andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.id").exists());
    }

    // EX10
    @Test
    void requiresActiveSession() throws Exception {
        mvc.perform(get("/api/v1/exercises")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/exercises/" + PUSH_UP_ID)).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/exercise-filters")).andExpect(status().isUnauthorized());

        String email = "x" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
        String token = newAccess(email);
        jdbc.update("update users set status = 'LOCKED' where email = ?", email);
        mvc.perform(get("/api/v1/exercises").header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.code").value("ACCOUNT_LOCKED"));

        String login = login(newEmail()).andReturn().getResponse().getContentAsString();
        mvc.perform(post("/api/v1/auth/logout").contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"%s\"}".formatted(JsonPath.<String>read(login, "$.refreshToken"))))
            .andExpect(status().isNoContent());
        mvc.perform(get("/api/v1/exercises")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + JsonPath.read(login, "$.accessToken")))
            .andExpect(status().isUnauthorized());
    }

    // EX11 — ký tự đặc biệt được tìm như chữ thường, không thành wildcard hay lỗi SQL.
    @Test
    void specialCharactersAreLiteral() throws Exception {
        for (String keyword : List.of("%", "_", "\\", "'", "' or '1'='1", "%nguc")) {
            list(Map.of("keyword", keyword)).andExpect(status().isOk())
                .andExpect(jsonPath("$.totalItems").value(0));
        }
        // "push-up" có dấu gạch: vẫn khớp đúng chữ.
        assertThat(names(Map.of("keyword", "push-up")))
            .containsExactlyInAnyOrder("Hít đất (Push-up)", "Hít đất tay hẹp (Close-grip Push-up)");
    }

    // EX16 — seed giữ ID/code ổn định, name_search khớp hàm chuẩn hóa của backend.
    @Test
    void seedIsConsistent() {
        List<Map<String, Object>> rows = jdbc.queryForList(
            "select code, name, name_search from exercises where code not like 'test-%'");
        assertThat(rows).hasSize(SEEDED_ACTIVE);
        assertThat(rows).allSatisfy(row ->
            assertThat(row.get("name_search")).as((String) row.get("code"))
                .isEqualTo(SearchText.normalize((String) row.get("name"))));
        assertThat(jdbc.queryForObject("select id::text from exercises where code = 'push-up'", String.class))
            .isEqualTo(PUSH_UP_ID);
        assertThat(jdbc.queryForObject("select count(*) from exercises where media_url is not null", Integer.class))
            .isEqualTo(29);
    }

    @Test
    void filtersEndpointListsCodesAndLabels() throws Exception {
        mvc.perform(get("/api/v1/exercise-filters").header(HttpHeaders.AUTHORIZATION, "Bearer " + access))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.muscleGroups.length()").value(9))
            .andExpect(jsonPath("$.muscleGroups[0].code").value("CHEST"))
            .andExpect(jsonPath("$.muscleGroups[0].name").value("Ngực"))
            .andExpect(jsonPath("$.equipment.length()").value(7))
            .andExpect(jsonPath("$.difficulties[*].code").value(
                org.hamcrest.Matchers.contains("BEGINNER", "INTERMEDIATE", "ADVANCED")));
    }

    private static org.hamcrest.Matcher<Iterable<? extends String>> everyItemIs(String value) {
        return org.hamcrest.Matchers.everyItem(org.hamcrest.Matchers.is(value));
    }

    private Set<String> names(Map<String, Object> params) throws Exception {
        String body = list(params).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return new HashSet<>(JsonPath.<List<String>>read(body, "$.items[*].name"));
    }

    private ResultActions list(Map<String, ?> params) throws Exception {
        var request = get("/api/v1/exercises").header(HttpHeaders.AUTHORIZATION, "Bearer " + access);
        params.forEach((k, v) -> request.queryParam(k, String.valueOf(v)));
        return mvc.perform(request);
    }

    private ResultActions detail(String id) throws Exception {
        return mvc.perform(get("/api/v1/exercises/" + id).header(HttpHeaders.AUTHORIZATION, "Bearer " + access));
    }

    private static String newEmail() {
        return "e" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
    }

    private String newAccess() throws Exception {
        return newAccess(newEmail());
    }

    private String newAccess(String email) throws Exception {
        String body = login(email).andReturn().getResponse().getContentAsString();
        return JsonPath.read(body, "$.accessToken");
    }

    /** Đăng ký rồi đăng nhập tài khoản mới. */
    private ResultActions login(String email) throws Exception {
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\",\"fullName\":\"Test\"}".formatted(email, PASSWORD)))
            .andExpect(status().isCreated());
        return mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\"}".formatted(email, PASSWORD)))
            .andExpect(status().isOk());
    }
}
