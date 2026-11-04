package com.viegym.backend.food;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.viegym.backend.TestcontainersConfiguration;
import com.viegym.backend.exercise.SearchText;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
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
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/** F01–F08 trong plan/huong-dan-ngay-9.md §6, trên PostgreSQL thật với seed V10. */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class FoodLibraryIntegrationTests {
    private static final String PASSWORD = "Matkhau123";
    private static final int IMPORTED = 928;
    private static final int ACTIVE = 912;
    /** Kẹo sô cô la: kcal nguồn lệch 1834% so với 4P+4C+9F → ẩn chờ rà. */
    private static final String FLAGGED_CODE = "VPF-000341";
    private static final Path SOURCE = Path.of("..", "data", "viendinhduong_mon_an.json");

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcTemplate jdbc;

    private String access;

    @BeforeEach
    void setUp() throws Exception {
        String email = "f" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\",\"fullName\":\"F\"}".formatted(email, PASSWORD)))
            .andExpect(status().isCreated());
        String body = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\"}".formatted(email, PASSWORD)))
            .andReturn().getResponse().getContentAsString();
        access = JsonPath.read(body, "$.accessToken");
    }

    private ResultActions getJson(String path) throws Exception {
        return mvc.perform(get(path).header(HttpHeaders.AUTHORIZATION, "Bearer " + access));
    }

    private static String body(ResultActions r) throws Exception {
        return r.andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);
    }

    private int count(String sql, Object... args) {
        return jdbc.queryForObject(sql, Integer.class, args);
    }

    private static BigDecimal amount(JsonNode record, String key) {
        for (JsonNode c : record.get("nutritional_components")) {
            if (key.equals(c.get("key").asString())) {
                JsonNode a = c.get("amount");
                return a.isNumber() ? a.decimalValue() : null;
            }
        }
        return null;
    }

    // F01, F07 — đối chiếu TOÀN BỘ món đã nhập với file nguồn; món thiếu chỉ số không được nhập.
    @Test
    void importedFoodsMatchSourceFile() throws Exception {
        JsonNode source = JsonMapper.builder().build().readTree(Files.readString(SOURCE));
        Map<String, Map<String, Object>> db = new HashMap<>();
        jdbc.queryForList("select * from foods").forEach(r -> db.put((String) r.get("code"), r));
        assertThat(db).hasSize(IMPORTED);

        int compared = 0;
        int missing = 0;
        for (JsonNode r : source.get("data")) {
            String code = r.get("code").asString();
            BigDecimal kcal = amount(r, "nang-luong");
            BigDecimal protein = amount(r, "chat-dam");
            BigDecimal carbs = amount(r, "chat-bot-duong");
            BigDecimal fat = amount(r, "chat-beo");
            Map<String, Object> row = db.get(code);
            if (kcal == null || protein == null || carbs == null || fat == null) {
                missing++;
                assertThat(row).as("món thiếu chỉ số %s không được nhập", code).isNull();
                continue;
            }
            assertThat(row).as("món đủ chỉ số %s phải được nhập", code).isNotNull();
            assertThat(row.get("name")).isEqualTo(r.get("name_vi").asString().strip());
            assertThat((BigDecimal) row.get("kcal_per_serving")).isEqualByComparingTo(kcal);
            assertThat((BigDecimal) row.get("protein_per_serving")).isEqualByComparingTo(protein);
            assertThat((BigDecimal) row.get("carbs_per_serving")).isEqualByComparingTo(carbs);
            assertThat((BigDecimal) row.get("fat_per_serving")).isEqualByComparingTo(fat);
            assertThat(row.get("serving_size")).isNull();
            assertThat(row.get("data_quality")).isEqualTo("SOURCED");
            assertThat((String) row.get("source")).contains(code);
            assertThat((String) row.get("image_url")).startsWith("https://viendinhduong.vn/storage/");
            compared++;
        }
        assertThat(compared).isEqualTo(IMPORTED);
        assertThat(missing).isEqualTo(96);
        assertThat(count("select count(*) from foods where is_active")).isEqualTo(ACTIVE);
        assertThat(count("select count(*) from foods where not is_active and review_note is null")).isZero();
    }

    // F02 — name_search sinh bởi script Node khớp SearchText (Java) cho mọi dòng.
    @Test
    void searchNamesMatchJavaNormalizer() {
        List<Map<String, Object>> rows = jdbc.queryForList("select code, name, name_search from foods");
        for (Map<String, Object> r : rows) {
            assertThat(r.get("name_search")).as((String) r.get("code"))
                .isEqualTo(SearchText.normalize((String) r.get("name")));
        }
    }

    // F02 — có dấu, không dấu, hoa thường, khoảng trắng thừa cho cùng kết quả.
    @Test
    void keywordIgnoresAccentsAndCase() throws Exception {
        String accented = body(getJson("/api/v1/foods?keyword=phở bò&size=100").andExpect(status().isOk()));
        String plain = body(getJson("/api/v1/foods?keyword=pho bo&size=100"));
        String messy = body(getJson("/api/v1/foods?keyword=  PHỞ   Bò &size=100"));
        List<String> ids = JsonPath.read(accented, "$.items[*].id");
        assertThat(ids).isNotEmpty();
        assertThat(JsonPath.<List<String>>read(plain, "$.items[*].id")).isEqualTo(ids);
        assertThat(JsonPath.<List<String>>read(messy, "$.items[*].id")).isEqualTo(ids);
        assertThat(JsonPath.<List<String>>read(accented, "$.items[*].name"))
            .allMatch(n -> SearchText.normalize(n).contains("pho bo"));
        // Ký tự LIKE trong keyword được so như chữ thường.
        getJson("/api/v1/foods?keyword=%25").andExpect(status().isOk()).andExpect(jsonPath("$.totalItems").value(0));
        getJson("/api/v1/foods?keyword=_").andExpect(jsonPath("$.totalItems").value(0));
        getJson("/api/v1/foods?keyword=khongcomonnay").andExpect(status().isOk())
            .andExpect(jsonPath("$.items").isEmpty());
    }

    // F03 — lọc + phân trang: ghép các trang đủ, không trùng, đúng thứ tự, đúng bộ lọc.
    @Test
    void filterAndPaginationAreComplete() throws Exception {
        int expected = count("select count(*) from foods f join food_categories c on c.id = f.category_id "
            + "where f.is_active and c.code = 'BANH_DA_BUN_PHO'");
        List<String> ids = new ArrayList<>();
        List<String> names = new ArrayList<>();
        int page = 0;
        boolean hasNext = true;
        while (hasNext) {
            String b = body(getJson("/api/v1/foods?category=BANH_DA_BUN_PHO&size=7&page=" + page)
                .andExpect(status().isOk()));
            ids.addAll(JsonPath.read(b, "$.items[*].id"));
            names.addAll(JsonPath.<List<String>>read(b, "$.items[*].name"));
            assertThat(JsonPath.<List<String>>read(b, "$.items[*].category.code")).containsOnly("BANH_DA_BUN_PHO");
            hasNext = JsonPath.read(b, "$.hasNext");
            page++;
        }
        assertThat(ids).hasSize(expected).doesNotHaveDuplicates();
        // Thứ tự theo collation của DB (name_search, id) — giống hệt khi ghép các trang.
        List<String> dbOrder = jdbc.queryForList("select f.id::text from foods f join food_categories c "
            + "on c.id = f.category_id where f.is_active and c.code = 'BANH_DA_BUN_PHO' "
            + "order by f.name_search, f.id", String.class);
        assertThat(ids).isEqualTo(dbOrder);
        assertThat(names).hasSize(expected);

        String han = body(getJson("/api/v1/foods?region=HAN&size=100"));
        assertThat(JsonPath.<List<String>>read(han, "$.items[*].region.code")).containsOnly("HAN");
        assertThat(JsonPath.<Integer>read(han, "$.totalItems"))
            .isEqualTo(count("select count(*) from foods where is_active and region = 'HAN'"));
        getJson("/api/v1/foods?size=1").andExpect(jsonPath("$.totalItems").value(ACTIVE));
    }

    // F04 — món ẩn (chờ rà) không có trong tìm kiếm, chi tiết trả 404; ID lạ 404.
    @Test
    void inactiveFoodIsHidden() throws Exception {
        UUID id = jdbc.queryForObject("select id from foods where code = ?", UUID.class, FLAGGED_CODE);
        getJson("/api/v1/foods/" + id).andExpect(status().isNotFound())
            .andExpect(jsonPath("$.code").value("NOT_FOUND"));
        String b = body(getJson("/api/v1/foods?keyword=keo so co la&size=100"));
        assertThat(JsonPath.<List<String>>read(b, "$.items[*].id")).doesNotContain(id.toString());
        getJson("/api/v1/foods/" + UUID.randomUUID()).andExpect(status().isNotFound());
        getJson("/api/v1/foods/khong-phai-uuid").andExpect(status().isBadRequest());
    }

    // Chi tiết và danh mục.
    @Test
    void detailAndFilters() throws Exception {
        UUID id = jdbc.queryForObject("select id from foods where code = 'VPF-000272'", UUID.class);
        getJson("/api/v1/foods/" + id).andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Phở bò tái 24h"))
            .andExpect(jsonPath("$.kcalPerServing").value(314))
            .andExpect(jsonPath("$.servingDescription").value("1 phần ăn theo nguồn"))
            .andExpect(jsonPath("$.servingSize").isEmpty())
            .andExpect(jsonPath("$.region.name").value("Toàn quốc"))
            .andExpect(jsonPath("$.dataQuality").value("SOURCED"))
            .andExpect(jsonPath("$.source").value(org.hamcrest.Matchers.containsString("VPF-000272")))
            .andExpect(jsonPath("$.imageUrl").value(org.hamcrest.Matchers.startsWith("https://viendinhduong.vn/")))
            .andExpect(jsonPath("$.revision").value(1));

        String filters = body(getJson("/api/v1/food-filters").andExpect(status().isOk()));
        assertThat(JsonPath.<List<String>>read(filters, "$.categories[*].code")).hasSize(19)
            .startsWith("COM_CAC_LOAI");
        assertThat(JsonPath.<List<String>>read(filters, "$.regions[*].code"))
            .containsExactly("VPF", "HAN", "HAP", "SFF");
    }

    // F05 — thiếu/sai JWT → 401.
    @Test
    void requiresAuthentication() throws Exception {
        mvc.perform(get("/api/v1/foods")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/food-filters")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/foods").header(HttpHeaders.AUTHORIZATION, "Bearer sai"))
            .andExpect(status().isUnauthorized());
    }

    @Test
    void invalidQueriesAreRejected() throws Exception {
        getJson("/api/v1/foods?size=0").andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.size").isNotEmpty());
        getJson("/api/v1/foods?size=101").andExpect(status().isBadRequest());
        getJson("/api/v1/foods?page=-1").andExpect(status().isBadRequest());
        getJson("/api/v1/foods?page=abc").andExpect(status().isBadRequest());
        getJson("/api/v1/foods?category=KHONG_CO").andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.category").isNotEmpty());
        getJson("/api/v1/foods?region=han").andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.region").isNotEmpty());
        getJson("/api/v1/foods?keyword=" + "a".repeat(101)).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.keyword").isNotEmpty());
    }

    // F06 — chạy lại seed: không nhân đôi, revision giữ nguyên; số liệu bị đổi thì được khôi phục và tăng revision.
    @Test
    void reimportIsIdempotent() throws Exception {
        String seed = new ClassPathResource("db/migration/V10__seed_foods.sql").getContentAsString(StandardCharsets.UTF_8);
        jdbc.execute(seed);
        assertThat(count("select count(*) from foods")).isEqualTo(IMPORTED);
        assertThat(count("select count(*) from food_categories")).isEqualTo(19);
        Set<Integer> revisions = new HashSet<>(jdbc.queryForList(
            "select revision from foods where code <> 'VPF-000271'", Integer.class));
        assertThat(revisions).containsOnly(1);

        jdbc.update("update foods set kcal_per_serving = 1 where code = 'VPF-000271'");
        jdbc.execute(seed);
        Map<String, Object> row = jdbc.queryForMap(
            "select kcal_per_serving, revision from foods where code = 'VPF-000271'");
        assertThat((BigDecimal) row.get("kcal_per_serving")).isEqualByComparingTo("483");
        assertThat((Integer) row.get("revision")).isGreaterThanOrEqualTo(2);
        assertThat(count("select count(*) from foods")).isEqualTo(IMPORTED);
    }
}
