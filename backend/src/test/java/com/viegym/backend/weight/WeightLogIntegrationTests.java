package com.viegym.backend.weight;

import static org.assertj.core.api.Assertions.assertThat;
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
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
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

/** W01–W04 của plan/huong-dan-ngay-13.md §6 theo quy tắc docs ngày 2 (BR-WL01..02, BR-H02). */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class WeightLogIntegrationTests {
    private static final String PASSWORD = "Matkhau123";
    private static final ZoneId USER_ZONE = ZoneId.of("Asia/Ho_Chi_Minh");

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcTemplate jdbc;

    // W01 — fixture plan: ngày 1 = 70, ngày 3 = 69,5, ngày 7 = 69,8; trả tăng dần theo ngày.
    @Test
    void fixtureIsListedAscendingByDate() throws Exception {
        Account a = newAccount();
        LocalDate today = today();
        save(a, today, "69.8", null).andExpect(status().isCreated());
        save(a, today.minusDays(6), "70", null).andExpect(status().isCreated())
            .andExpect(jsonPath("$.weightKg").value(70.0));
        save(a, today.minusDays(4), "69.5", "Sau khi ngủ dậy").andExpect(status().isCreated())
            .andExpect(jsonPath("$.note").value("Sau khi ngủ dậy"));

        list(a, null, null).andExpect(status().isOk())
            .andExpect(jsonPath("$.items.length()").value(3))
            .andExpect(jsonPath("$.items[0].logDate").value(today.minusDays(6).toString()))
            .andExpect(jsonPath("$.items[0].weightKg").value(70.0))
            .andExpect(jsonPath("$.items[1].weightKg").value(69.5))
            .andExpect(jsonPath("$.items[2].logDate").value(today.toString()))
            .andExpect(jsonPath("$.items[2].weightKg").value(69.8))
            .andExpect(jsonPath("$.items[0].userId").doesNotExist());
    }

    // BR-WL01 — cùng ngày thì ghi đè (200, cùng id), kể cả ghi chú.
    @Test
    void sameDateUpdatesExistingLog() throws Exception {
        Account a = newAccount();
        LocalDate day = today().minusDays(2);
        String id = JsonPath.read(save(a, day, "65", "cũ").andExpect(status().isCreated())
            .andReturn().getResponse().getContentAsString(), "$.id");
        save(a, day, "64.6", null).andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(id))
            .andExpect(jsonPath("$.weightKg").value(64.6))
            .andExpect(jsonPath("$.note").doesNotExist());
        assertThat(jdbc.queryForObject("select count(*) from weight_logs where user_id = ?", Integer.class, a.id))
            .isEqualTo(1);
    }

    @Test
    void concurrentSameDateSavesKeepOneRow() throws Exception {
        Account a = newAccount();
        LocalDate day = today();
        CountDownLatch start = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            Callable<Integer> call = () -> {
                start.await();
                return save(a, day, "66", null).andReturn().getResponse().getStatus();
            };
            List<Future<Integer>> results = List.of(pool.submit(call), pool.submit(call));
            start.countDown();
            assertThat(List.of(results.get(0).get(), results.get(1).get())).containsExactlyInAnyOrder(201, 200);
        } finally {
            pool.shutdown();
        }
        assertThat(jdbc.queryForObject("select count(*) from weight_logs where user_id = ?", Integer.class, a.id))
            .isEqualTo(1);
    }

    // BR-WL02 + khoảng hợp lệ docs/03.
    @Test
    void invalidInputIsRejected() throws Exception {
        Account a = newAccount();
        LocalDate today = today();
        save(a, today.plusDays(1), "65", null).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.logDate").exists());
        for (String weight : List.of("29.9", "300.1", "64.65", "0")) {
            save(a, today, weight, null).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fieldErrors.weightKg").exists());
        }
        save(a, today, "65", "x".repeat(501)).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.note").exists());
        mvc.perform(post("/api/v1/weight-logs").header(HttpHeaders.AUTHORIZATION, "Bearer " + a.access)
                .contentType(MediaType.APPLICATION_JSON).content("{\"weightKg\":65}"))
            .andExpect(status().isBadRequest()).andExpect(jsonPath("$.fieldErrors.logDate").exists());
        save(a, today, "30", null).andExpect(status().isCreated());
        save(a, today.minusDays(1), "300", null).andExpect(status().isCreated());
    }

    @Test
    void rangeIsValidatedAndDefaultsToNinetyDays() throws Exception {
        Account a = newAccount();
        LocalDate today = today();
        save(a, today.minusDays(89), "70", null).andExpect(status().isCreated());
        save(a, today.minusDays(90), "71", null).andExpect(status().isCreated());

        list(a, null, null).andExpect(jsonPath("$.items.length()").value(1))
            .andExpect(jsonPath("$.items[0].weightKg").value(70.0));
        list(a, today.minusDays(365).toString(), today.toString()).andExpect(status().isOk())
            .andExpect(jsonPath("$.items.length()").value(2));
        list(a, today.minusDays(366).toString(), today.toString()).andExpect(status().isBadRequest());
        list(a, today.toString(), today.minusDays(1).toString()).andExpect(status().isBadRequest());
        list(a, "2026-13-01", null).andExpect(status().isBadRequest());
    }

    // W04 — B không xem/xóa được bản ghi của A; không có endpoint nhận userId.
    @Test
    void otherUsersLogsAreInvisible() throws Exception {
        Account a = newAccount();
        Account b = newAccount();
        String id = JsonPath.read(save(a, today(), "65", null).andReturn().getResponse().getContentAsString(), "$.id");

        list(b, null, null).andExpect(jsonPath("$.items.length()").value(0));
        mvc.perform(delete("/api/v1/weight-logs/" + id).header(HttpHeaders.AUTHORIZATION, "Bearer " + b.access))
            .andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("NOT_FOUND"));
        // userId lạ trong body bị bỏ qua: vẫn ghi cho B.
        mvc.perform(post("/api/v1/weight-logs").header(HttpHeaders.AUTHORIZATION, "Bearer " + b.access)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"userId\":\"%s\",\"logDate\":\"%s\",\"weightKg\":80}".formatted(a.id, today())))
            .andExpect(status().isCreated());
        list(a, null, null).andExpect(jsonPath("$.items.length()").value(1))
            .andExpect(jsonPath("$.items[0].weightKg").value(65.0));
        mvc.perform(get("/api/v1/weight-logs")).andExpect(status().isUnauthorized());
    }

    @Test
    void deleteRemovesOwnLog() throws Exception {
        Account a = newAccount();
        String id = JsonPath.read(save(a, today(), "65", null).andReturn().getResponse().getContentAsString(), "$.id");
        deleteLog(a, id).andExpect(status().isNoContent());
        deleteLog(a, id).andExpect(status().isNotFound());
        deleteLog(a, "not-a-uuid").andExpect(status().isBadRequest());
        list(a, null, null).andExpect(jsonPath("$.items.length()").value(0));
    }

    // W02/W03 theo BR-H02: ghi/xóa cân nặng không đổi hồ sơ hay mục tiêu; dashboard thấy bản ghi mới nhất.
    @Test
    void logsDoNotChangeProfileAndDashboardShowsLatest() throws Exception {
        Account a = newAccount();
        LocalDate today = today();
        mvc.perform(put("/api/v1/health-profile/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + a.access)
                .contentType(MediaType.APPLICATION_JSON).content("""
                    {"sex":"MALE","dateOfBirth":"%s","heightCm":170,"weightKg":65,
                     "activityLevel":"MODERATE","goal":"GAIN_MUSCLE"}
                    """.formatted(today.minusYears(22))))
            .andExpect(status().isOk());
        dashboard(a).andExpect(jsonPath("$.health.latestWeightLog").doesNotExist());

        String latestId = JsonPath.read(save(a, today, "63", null).andReturn().getResponse().getContentAsString(),
            "$.id");
        // Sửa một ngày cũ sau đó: "mới nhất" vẫn theo ngày đo, không theo thời điểm ghi.
        save(a, today.minusDays(3), "64", null).andExpect(status().isCreated());
        dashboard(a).andExpect(jsonPath("$.health.weightKg").value(65.0))
            .andExpect(jsonPath("$.health.latestWeightLog.logDate").value(today.toString()))
            .andExpect(jsonPath("$.health.latestWeightLog.weightKg").value(63.0));
        mvc.perform(get("/api/v1/health-profile/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + a.access))
            .andExpect(jsonPath("$.profile.weightKg").value(65.0))
            .andExpect(jsonPath("$.targets.targetKcal").value(2791.6));

        deleteLog(a, latestId).andExpect(status().isNoContent());
        dashboard(a).andExpect(jsonPath("$.health.latestWeightLog.weightKg").value(64.0))
            .andExpect(jsonPath("$.health.weightKg").value(65.0));
    }

    private record Account(String email, UUID id, String access) {
    }

    private static LocalDate today() {
        return LocalDate.now(USER_ZONE);
    }

    private Account newAccount() throws Exception {
        String email = "w" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\",\"fullName\":\"Test\"}".formatted(email, PASSWORD)))
            .andExpect(status().isCreated());
        String body = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\"}".formatted(email, PASSWORD)))
            .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return new Account(email, UUID.fromString(JsonPath.read(body, "$.user.id")), JsonPath.read(body, "$.accessToken"));
    }

    private ResultActions save(Account a, LocalDate date, String weight, String note) throws Exception {
        String noteJson = note == null ? "" : ",\"note\":\"%s\"".formatted(note);
        return mvc.perform(post("/api/v1/weight-logs").header(HttpHeaders.AUTHORIZATION, "Bearer " + a.access)
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"logDate\":\"%s\",\"weightKg\":%s%s}".formatted(date, weight, noteJson)));
    }

    private ResultActions list(Account a, String from, String to) throws Exception {
        var request = get("/api/v1/weight-logs").header(HttpHeaders.AUTHORIZATION, "Bearer " + a.access);
        if (from != null) {
            request.param("from", from);
        }
        if (to != null) {
            request.param("to", to);
        }
        return mvc.perform(request);
    }

    private ResultActions deleteLog(Account a, String id) throws Exception {
        return mvc.perform(delete("/api/v1/weight-logs/" + id).header(HttpHeaders.AUTHORIZATION, "Bearer " + a.access));
    }

    private ResultActions dashboard(Account a) throws Exception {
        return mvc.perform(get("/api/v1/dashboard").header(HttpHeaders.AUTHORIZATION, "Bearer " + a.access));
    }
}
