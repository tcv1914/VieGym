package com.viegym.backend.common;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.viegym.backend.TestcontainersConfiguration;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/**
 * T-D01 (ngày 16): "hôm nay" theo users.timezone (BR-G04) ở ranh giới nửa đêm, với đồng hồ cố định thay cho
 * đồng hồ thật — các test khác tính "hôm nay" theo giờ máy nên không chạm được giây 23:59:59.
 * Tại 00:00:00 giờ VN, ngày UTC vẫn là hôm trước: kết quả khác nhau giữa hai mốc chứng minh backend dùng
 * múi giờ user chứ không dùng UTC hay giờ JVM.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Import({TestcontainersConfiguration.class, UserDayBoundaryIntegrationTests.FixedClockConfig.class})
class UserDayBoundaryIntegrationTests {
    private static final ZoneId VN = ZoneId.of("Asia/Ho_Chi_Minh");

    @Autowired
    MockMvc mvc;

    @Autowired
    MutableClock clock;

    @AfterEach
    void systemTime() {
        clock.set(null);
    }

    @Test
    void todayFollowsUserTimezoneAcrossMidnight() throws Exception {
        // Mốc sau thời điểm thật để access token (hạn 15 phút, kiểm bằng giờ hệ thống) còn hiệu lực.
        LocalDate day = LocalDate.now(VN).plusDays(1);
        Instant lastSecond = day.plusDays(1).atStartOfDay(VN).toInstant().minusSeconds(1);
        Instant midnight = lastSecond.plusSeconds(1);
        LocalDate next = day.plusDays(1);
        // Ở cả hai mốc, ngày UTC đều là `day`.
        assert LocalDate.ofInstant(midnight, ZoneOffset.UTC).equals(day);

        clock.set(lastSecond);
        String token = newUser();
        String workoutDay = workoutDay(token);

        mealPlan(token).andExpect(status().isOk()).andExpect(jsonPath("$.date").value(day.toString()));
        dashboard(token).andExpect(jsonPath("$.date").value(day.toString()));
        weight(token, next).andExpect(status().isBadRequest()).andExpect(jsonPath("$.fieldErrors.logDate").exists());
        weight(token, day).andExpect(status().isCreated());
        schedule(token, workoutDay, day).andExpect(status().isCreated());

        clock.set(midnight);
        mealPlan(token).andExpect(jsonPath("$.date").value(next.toString()));
        dashboard(token).andExpect(jsonPath("$.date").value(next.toString()));
        weight(token, next).andExpect(status().isCreated());
        // Ngày `day` đã qua theo giờ VN dù UTC vẫn đang là `day`.
        schedule(token, workoutDay, day).andExpect(status().isBadRequest());
        schedule(token, workoutDay, next).andExpect(status().isCreated());
    }

    private String newUser() throws Exception {
        String email = "tz" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"Matkhau123\",\"fullName\":\"TZ\"}".formatted(email)))
            .andExpect(status().isCreated());
        String body = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"Matkhau123\"}".formatted(email)))
            .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return JsonPath.read(body, "$.accessToken");
    }

    private String workoutDay(String token) throws Exception {
        String templates = mvc.perform(get("/api/v1/workout-programs").param("scope", "templates")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
            .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        String templateId = JsonPath.read(templates, "$.items[0].id");
        String program = mvc.perform(post("/api/v1/workout-programs").header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"templateId\":\"%s\",\"activate\":true}".formatted(templateId)))
            .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        return JsonPath.read(program, "$.days[0].id");
    }

    private ResultActions mealPlan(String token) throws Exception {
        return mvc.perform(get("/api/v1/meal-plans").header(HttpHeaders.AUTHORIZATION, "Bearer " + token));
    }

    private ResultActions dashboard(String token) throws Exception {
        return mvc.perform(get("/api/v1/dashboard").header(HttpHeaders.AUTHORIZATION, "Bearer " + token));
    }

    private ResultActions weight(String token, LocalDate date) throws Exception {
        return mvc.perform(post("/api/v1/weight-logs").header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON).content("{\"logDate\":\"%s\",\"weightKg\":65}".formatted(date)));
    }

    private ResultActions schedule(String token, String dayId, LocalDate date) throws Exception {
        return mvc.perform(post("/api/v1/workout-schedules").header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"workoutDayId\":\"%s\",\"scheduledDate\":\"%s\"}".formatted(dayId, date)));
    }

    /** Đồng hồ hệ thống, hoặc một thời điểm cố định khi đã `set`. */
    static class MutableClock extends Clock {
        private volatile Instant fixed;

        void set(Instant instant) {
            fixed = instant;
        }

        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            MutableClock parent = this;
            return new Clock() {
                @Override
                public ZoneId getZone() {
                    return zone;
                }

                @Override
                public Clock withZone(ZoneId z) {
                    return parent.withZone(z);
                }

                @Override
                public Instant instant() {
                    return parent.instant();
                }
            };
        }

        @Override
        public Instant instant() {
            Instant f = fixed;
            return f != null ? f : Instant.now();
        }
    }

    @TestConfiguration
    static class FixedClockConfig {
        @Bean
        @Primary
        MutableClock testClock() {
            return new MutableClock();
        }
    }
}
