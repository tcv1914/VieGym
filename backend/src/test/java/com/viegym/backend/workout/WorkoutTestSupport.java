package com.viegym.backend.workout;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.viegym.backend.TestcontainersConfiguration;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.UUID;
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

/** Tài khoản, request và body mẫu dùng chung cho test giáo án và lịch tập. */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
abstract class WorkoutTestSupport {
    static final String PASSWORD = "Matkhau123";
    static final ZoneId ZONE = ZoneId.of("Asia/Ho_Chi_Minh");

    // ID cố định của seed V5 / V7.
    static final String PUSH_UP = "485e3b1c-daf3-5a2c-9b07-7093d2b0987d";
    static final String GOBLET_SQUAT = "2e724aa8-9b90-521e-afcd-f91c25632d60";
    static final String LAT_PULLDOWN = "8519ef28-d71f-5825-a3c1-430b9b1db93f";
    static final String GLUTE_BRIDGE = "8601567e-e57b-5e7d-8b53-60ec81901628";
    static final String DEAD_BUG = "4efb03fe-2cb8-5e67-8764-437eb6e44852";
    static final String FULL_BODY_TEMPLATE = "7e000000-0000-4000-8000-000000000001";
    static final String UPPER_LOWER_TEMPLATE = "7e000000-0000-4000-8000-000000000002";

    static final JsonMapper JSON = JsonMapper.builder().build();

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcTemplate jdbc;

    static LocalDate today() {
        return LocalDate.now(ZONE);
    }

    static Map<String, Object> exercise(String id, int sets, int reps, int rest) {
        return Map.of("exerciseId", id, "targetSets", sets, "targetReps", reps, "restSeconds", rest);
    }

    static Map<String, Object> day(String name, Map<?, ?>... exercises) {
        return Map.of("name", name, "exercises", List.of(exercises));
    }

    /** Giáo án 2 buổi × 2 bài. */
    static Map<String, Object> twoDayProgram(String name) {
        return Map.of("name", name, "days", List.of(
            day("Buổi A", exercise(GOBLET_SQUAT, 3, 10, 90), exercise(PUSH_UP, 3, 12, 60)),
            day("Buổi B", exercise(LAT_PULLDOWN, 4, 8, 120), exercise(GLUTE_BRIDGE, 2, 15, 45))));
    }

    String newUser() throws Exception {
        String email = "w" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\",\"fullName\":\"Test\"}".formatted(email, PASSWORD)))
            .andExpect(status().isCreated());
        String body = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\"}".formatted(email, PASSWORD)))
            .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return JsonPath.read(body, "$.accessToken");
    }

    ResultActions call(MockHttpServletRequestBuilder request, String token, Object body) throws Exception {
        request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token);
        if (body != null) {
            request.contentType(MediaType.APPLICATION_JSON)
                .content(body instanceof String s ? s : JSON.writeValueAsString(body));
        }
        return mvc.perform(request);
    }

    ResultActions getJson(String token, String path) throws Exception {
        return call(get(path), token, null);
    }

    ResultActions postJson(String token, String path, Object body) throws Exception {
        return call(post(path), token, body);
    }

    ResultActions putJson(String token, String path, Object body) throws Exception {
        return call(put(path), token, body);
    }

    static String body(ResultActions result) throws Exception {
        return result.andReturn().getResponse().getContentAsString();
    }

    /** Tạo giáo án, trả body 201. */
    String createProgram(String token, Object request) throws Exception {
        return body(postJson(token, "/api/v1/workout-programs", request).andExpect(status().isCreated()));
    }

    String createSchedule(String token, String dayId, LocalDate date, String time) throws Exception {
        Map<String, Object> request = new java.util.HashMap<>(Map.of("workoutDayId", dayId,
            "scheduledDate", date.toString()));
        if (time != null) {
            request.put("startTime", time);
        }
        return body(postJson(token, "/api/v1/workout-schedules", request).andExpect(status().isCreated()));
    }

    int count(String sql, Object... args) {
        return jdbc.queryForObject(sql, Integer.class, args);
    }
}
