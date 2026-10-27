package com.viegym.backend.health;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.viegym.backend.TestcontainersConfiguration;
import com.viegym.backend.health.repository.NutritionTargetRepository;
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
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/** Các tình huống H01–H13 trong plan/huong-dan-ngay-5.md §8, chạy trên PostgreSQL thật (Testcontainers). */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class HealthProfileIntegrationTests {
    private static final String PASSWORD = "Matkhau123";
    private static final ZoneId USER_ZONE = ZoneId.of("Asia/Ho_Chi_Minh");

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcTemplate jdbc;

    @MockitoSpyBean
    NutritionTargetRepository targetRepository;

    // H07
    @Test
    void getWithoutProfileIsProfileRequired() throws Exception {
        Account a = newAccount();
        getProfile(a.access).andExpect(status().isNotFound())
            .andExpect(jsonPath("$.code").value("HEALTH_PROFILE_REQUIRED"));
        me(a.access).andExpect(jsonPath("$.hasHealthProfile").value(false));
    }

    // H01, H08 — ca demo docs/04 §3.7; ngày sinh tính lùi 22 năm để tuổi luôn là 22.
    @Test
    void putCalculatesAndGetReturnsSavedTargets() throws Exception {
        Account a = newAccount();
        putProfile(a.access, demoProfile())
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.profile.sex").value("MALE"))
            .andExpect(jsonPath("$.profile.age").value(22))
            .andExpect(jsonPath("$.targets.bmi").value(22.49))
            .andExpect(jsonPath("$.targets.targetKcal").value(2791.6))
            .andExpect(jsonPath("$.targets.formulaVersion").value("MSJ-v1"));

        String saved = getProfile(a.access).andExpect(status().isOk())
            .andExpect(jsonPath("$.profile.heightCm").value(170.0))
            .andExpect(jsonPath("$.targets.bmrKcal").value(1607.5))
            .andExpect(jsonPath("$.targets.tdeeKcal").value(2491.6))
            .andExpect(jsonPath("$.targets.targetKcal").value(2791.6))
            .andExpect(jsonPath("$.targets.proteinG").value(117.0))
            .andExpect(jsonPath("$.targets.carbsG").value(406.4))
            .andExpect(jsonPath("$.targets.fatG").value(77.5))
            .andExpect(jsonPath("$.targets.kcalFloorApplied").value(false))
            .andReturn().getResponse().getContentAsString();
        assertThat(saved).doesNotContain("userId");

        me(a.access).andExpect(jsonPath("$.hasHealthProfile").value(true));
        loginRequest(a.email).andExpect(jsonPath("$.user.hasHealthProfile").value(true));
    }

    // H05 — mỗi request sai đều 400 và không đổi hồ sơ đã lưu.
    @Test
    void invalidValuesAreRejectedWithoutChangingSavedProfile() throws Exception {
        Account a = newAccount();
        putProfile(a.access, demoProfile()).andExpect(status().isOk());
        LocalDate today = LocalDate.now(USER_ZONE);

        record Case(String field, String json) {
        }
        List<Case> cases = List.of(
            new Case("dateOfBirth", profile(today.plusDays(1), "170", "65")),
            new Case("dateOfBirth", profile(today.minusYears(18).plusDays(1), "170", "65")),
            new Case("dateOfBirth", profile(today.minusYears(81), "170", "65")),
            new Case("heightCm", profile(today.minusYears(22), "0", "65")),
            new Case("heightCm", profile(today.minusYears(22), "170.25", "65")),
            new Case("weightKg", profile(today.minusYears(22), "170", "-5")),
            new Case("weightKg", profile(today.minusYears(22), "170", "300.1")),
            new Case("goal", demoProfile().replace("\"goal\":\"GAIN_MUSCLE\",", "")));
        for (Case c : cases) {
            putProfile(a.access, c.json).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.fieldErrors." + c.field).exists());
        }

        getProfile(a.access).andExpect(jsonPath("$.profile.weightKg").value(65.0))
            .andExpect(jsonPath("$.targets.targetKcal").value(2791.6));
    }

    @Test
    void ageBoundariesAreAccepted() throws Exception {
        Account a = newAccount();
        LocalDate today = LocalDate.now(USER_ZONE);
        putProfile(a.access, profile(today.minusYears(18), "170", "65"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.profile.age").value(18));
        putProfile(a.access, profile(today.minusYears(81).plusDays(1), "170", "65"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.profile.age").value(80));
    }

    // H06
    @Test
    void unknownEnumOrBadDateReturnsFieldError() throws Exception {
        Account a = newAccount();
        putProfile(a.access, demoProfile().replace("\"MALE\"", "\"OTHER\""))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
            .andExpect(jsonPath("$.fieldErrors.sex").exists());
        // Tên mức vận động của plan ngày 5 không phải tên đã chốt ở docs/04 §3.3.
        putProfile(a.access, demoProfile().replace("\"MODERATE\"", "\"HIGH\""))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.activityLevel").exists());
        putProfile(a.access, demoProfile().replaceFirst("\\d{4}-\\d{2}-\\d{2}", "2004-13-40"))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.dateOfBirth").exists());
        getProfile(a.access).andExpect(status().isNotFound());
    }

    // H09
    @Test
    void concurrentFirstPutsCreateOneProfile() throws Exception {
        Account a = newAccount();
        LocalDate dob = LocalDate.now(USER_ZONE).minusYears(30);
        CountDownLatch start = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            Callable<Integer> lighter = () -> {
                start.await();
                return putProfile(a.access, profile(dob, "170", "60")).andReturn().getResponse().getStatus();
            };
            Callable<Integer> heavier = () -> {
                start.await();
                return putProfile(a.access, profile(dob, "170", "70")).andReturn().getResponse().getStatus();
            };
            Future<Integer> first = pool.submit(lighter);
            Future<Integer> second = pool.submit(heavier);
            start.countDown();
            assertThat(List.of(first.get(), second.get())).containsOnly(200);
        } finally {
            pool.shutdownNow();
        }
        assertThat(countRows("health_profiles", a.id)).isEqualTo(1);
        assertThat(countRows("nutrition_targets", a.id)).isEqualTo(1);
    }

    // H10
    @Test
    void requiresValidSession() throws Exception {
        mvc.perform(get("/api/v1/health-profile/me")).andExpect(status().isUnauthorized());
        Account a = newAccount();
        mvc.perform(post("/api/v1/auth/logout").contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"%s\"}".formatted(a.refresh)))
            .andExpect(status().isNoContent());
        getProfile(a.access).andExpect(status().isUnauthorized());
        putProfile(a.access, demoProfile()).andExpect(status().isUnauthorized());
    }

    // H11, H12 — client gửi userId/kết quả tự chọn: bị bỏ qua, chỉ hồ sơ của chủ token đổi.
    @Test
    void usersOnlySeeAndChangeTheirOwnProfile() throws Exception {
        Account a = newAccount();
        Account b = newAccount();
        putProfile(a.access, demoProfile()).andExpect(status().isOk());
        getProfile(b.access).andExpect(status().isNotFound());

        String forged = profile(LocalDate.now(USER_ZONE).minusYears(22), "170", "80").replaceFirst("\\{", """
            {"userId":"%s","bmi":1,"targetKcal":9999,"targets":{"targetKcal":9999},
            """.formatted(a.id));
        putProfile(b.access, forged)
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.profile.weightKg").value(80.0))
            .andExpect(jsonPath("$.targets.bmi").value(27.68));

        getProfile(a.access).andExpect(jsonPath("$.profile.weightKg").value(65.0))
            .andExpect(jsonPath("$.targets.targetKcal").value(2791.6));
        assertThat(countRows("health_profiles", a.id)).isEqualTo(1);
        assertThat(countRows("health_profiles", b.id)).isEqualTo(1);
    }

    // H13 — lỗi khi ghi mục tiêu thì hồ sơ cũng không được lưu.
    @Test
    void failureWhileSavingTargetRollsBackProfile() throws Exception {
        Account a = newAccount();
        doThrow(new IllegalStateException("lỗi giả lập")).when(targetRepository).save(any());
        putProfile(a.access, demoProfile()).andExpect(status().isInternalServerError());
        assertThat(countRows("health_profiles", a.id)).isZero();
        assertThat(countRows("nutrition_targets", a.id)).isZero();
    }

    private record Account(String email, UUID id, String access, String refresh) {
    }

    private Account newAccount() throws Exception {
        String email = "h" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\",\"fullName\":\"Test\"}".formatted(email, PASSWORD)))
            .andExpect(status().isCreated());
        String body = loginRequest(email).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return new Account(email, UUID.fromString(JsonPath.read(body, "$.user.id")),
            JsonPath.read(body, "$.accessToken"), JsonPath.read(body, "$.refreshToken"));
    }

    private static String demoProfile() {
        return profile(LocalDate.now(USER_ZONE).minusYears(22), "170", "65");
    }

    private static String profile(LocalDate dateOfBirth, String heightCm, String weightKg) {
        return """
            {"sex":"MALE","dateOfBirth":"%s","heightCm":%s,"weightKg":%s,
             "activityLevel":"MODERATE","goal":"GAIN_MUSCLE","note":"field lạ bị bỏ qua"}
            """.formatted(dateOfBirth, heightCm, weightKg);
    }

    private int countRows(String table, UUID userId) {
        return jdbc.queryForObject("select count(*) from " + table + " where user_id = ?", Integer.class, userId);
    }

    private ResultActions loginRequest(String email) throws Exception {
        return mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
            .content("{\"email\":\"%s\",\"password\":\"%s\"}".formatted(email, PASSWORD)));
    }

    private ResultActions me(String access) throws Exception {
        return mvc.perform(get("/api/v1/users/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + access));
    }

    private ResultActions getProfile(String access) throws Exception {
        return mvc.perform(get("/api/v1/health-profile/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + access));
    }

    private ResultActions putProfile(String access, String json) throws Exception {
        return mvc.perform(put("/api/v1/health-profile/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + access)
            .contentType(MediaType.APPLICATION_JSON).content(json));
    }
}
