package com.viegym.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.after;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.viegym.backend.TestcontainersConfiguration;
import com.viegym.backend.auth.reset.ResetCodeMailer;
import java.time.Duration;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.ThreadLocalRandom;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/**
 * P01–P04 của plan/huong-dan-ngay-13.md §6 theo docs ngày 2 (BR-A06: mã 6 chữ số). Email thay bằng
 * {@link ResetCodeMailer} giả; mỗi test dùng IP riêng để giới hạn theo IP không ảnh hưởng nhau.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class PasswordResetIntegrationTests {
    private static final String PASSWORD = "Matkhau123";
    private static final String NEW_PASSWORD = "Matkhau456";

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcTemplate jdbc;

    @MockitoBean
    ResetCodeMailer mailer;

    // P01 — cùng 204, body rỗng; chỉ email có thật mới được gửi mã.
    @Test
    void forgotPasswordAnswersTheSameForUnknownEmail() throws Exception {
        String ip = newIp();
        Account a = newAccount();
        String unknown = "khongco" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";

        forgot("  " + a.email.toUpperCase() + " ", ip).andExpect(status().isNoContent())
            .andExpect(content().string(""));
        forgot(unknown, ip).andExpect(status().isNoContent()).andExpect(content().string(""));

        verify(mailer, timeout(5000)).send(eq(a.email), anyString(), eq(Duration.ofMinutes(15)));
        verify(mailer, after(300).never()).send(eq(unknown), anyString(), any());
        assertThat(jdbc.queryForObject("select extract(epoch from expires_at - created_at)::int "
            + "from password_reset_tokens where user_id = ?", Integer.class, a.id)).isEqualTo(15 * 60);
    }

    // P04 — mật khẩu cũ sai, mới đúng, phiên cũ (access + refresh) bị từ chối; không tự đăng nhập.
    @Test
    void successfulResetChangesPasswordAndRevokesSessions() throws Exception {
        String ip = newIp();
        Account a = newAccount();
        String code = requestCode(a, ip);
        assertThat(code).matches("\\d{6}");
        String hash = jdbc.queryForObject("select token_hash from password_reset_tokens where user_id = ?",
            String.class, a.id);
        assertThat(hash).hasSize(64).doesNotContain(code);

        reset(a.email, code, NEW_PASSWORD, ip).andExpect(status().isNoContent())
            .andExpect(content().string(""));

        login(a.email, PASSWORD).andExpect(status().isUnauthorized());
        login(a.email, NEW_PASSWORD).andExpect(status().isOk());
        mvc.perform(get("/api/v1/users/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + a.access))
            .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"%s\"}".formatted(a.refresh)))
            .andExpect(status().isUnauthorized());
        // Dùng lại mã đã dùng.
        reset(a.email, code, "Matkhau789", ip).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.code").value("INVALID_RESET_CODE"));
        login(a.email, NEW_PASSWORD).andExpect(status().isOk());
    }

    // P02 — sai mã, sai 5 lần, hết hạn, mã cũ sau khi có mã mới, email lạ: cùng một lỗi, mật khẩu giữ nguyên.
    @Test
    void wrongCodeFiveTimesInvalidatesTheCode() throws Exception {
        String ip = newIp();
        Account a = newAccount();
        String code = requestCode(a, ip);
        String wrong = code.equals("000000") ? "111111" : "000000";

        for (int i = 1; i <= 5; i++) {
            reset(a.email, wrong, NEW_PASSWORD, ip).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_RESET_CODE"));
        }
        var row = jdbc.queryForMap("select attempt_count, used_at from password_reset_tokens where user_id = ?", a.id);
        assertThat(((Number) row.get("attempt_count")).intValue()).isEqualTo(5);
        assertThat(row.get("used_at")).isNotNull();
        // Mã đúng sau khi bị vô hiệu: cùng lỗi, không lộ là "đã khóa".
        reset(a.email, code, NEW_PASSWORD, ip).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.code").value("INVALID_RESET_CODE"));
        login(a.email, PASSWORD).andExpect(status().isOk());
    }

    @Test
    void expiredCodeIsRejected() throws Exception {
        String ip = newIp();
        Account a = newAccount();
        String code = requestCode(a, ip);
        jdbc.update("update password_reset_tokens set expires_at = now() - interval '1 second' where user_id = ?",
            a.id);
        reset(a.email, code, NEW_PASSWORD, ip).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.code").value("INVALID_RESET_CODE"));
        login(a.email, PASSWORD).andExpect(status().isOk());
    }

    @Test
    void newCodeInvalidatesPreviousOne() throws Exception {
        String ip = newIp();
        Account a = newAccount();
        ArgumentCaptor<String> codes = ArgumentCaptor.forClass(String.class);
        forgot(a.email, ip).andExpect(status().isNoContent());
        verify(mailer, timeout(5000).times(1)).send(eq(a.email), codes.capture(), any());
        forgot(a.email, ip).andExpect(status().isNoContent());
        verify(mailer, timeout(5000).times(2)).send(eq(a.email), codes.capture(), any());
        String first = codes.getAllValues().get(0);
        String second = codes.getAllValues().get(codes.getAllValues().size() - 1);
        assertThat(jdbc.queryForObject("select count(*) from password_reset_tokens where user_id = ? and used_at is null",
            Integer.class, a.id)).isEqualTo(1);

        if (!first.equals(second)) {
            reset(a.email, first, NEW_PASSWORD, ip).andExpect(status().isBadRequest());
        }
        reset(a.email, second, NEW_PASSWORD, ip).andExpect(status().isNoContent());
    }

    @Test
    void unknownEmailOnResetIsInvalidCode() throws Exception {
        reset("khongco@example.com", "123456", NEW_PASSWORD, newIp()).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.code").value("INVALID_RESET_CODE"));
    }

    // P03 — hai request cùng mã chạy đồng thời: đúng một thành công.
    @Test
    void concurrentResetsWithSameCodeSucceedOnce() throws Exception {
        String ip = newIp();
        Account a = newAccount();
        String code = requestCode(a, ip);
        CountDownLatch start = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            List<Callable<Integer>> calls = List.of("Matkhau111", "Matkhau222").stream()
                .<Callable<Integer>>map(pw -> () -> {
                    start.await();
                    return reset(a.email, code, pw, ip).andReturn().getResponse().getStatus();
                })
                .toList();
            List<Future<Integer>> results = calls.stream().map(pool::submit).toList();
            start.countDown();
            assertThat(List.of(results.get(0).get(), results.get(1).get())).containsExactlyInAnyOrder(204, 400);
        } finally {
            pool.shutdown();
        }
        int ok = 0;
        for (String pw : List.of("Matkhau111", "Matkhau222")) {
            if (login(a.email, pw).andReturn().getResponse().getStatus() == 200) {
                ok++;
            }
        }
        assertThat(ok).isEqualTo(1);
    }

    // docs/05 §2: 3 yêu cầu/email/giờ — lần thứ 4 vẫn 204 nhưng không tạo mã, không gửi.
    @Test
    void forgotIsLimitedPerEmailSilently() throws Exception {
        Account a = newAccount();
        for (int i = 0; i < 4; i++) {
            forgot(a.email, newIp()).andExpect(status().isNoContent());
        }
        verify(mailer, timeout(5000).times(3)).send(eq(a.email), anyString(), any());
        verify(mailer, after(300).times(3)).send(eq(a.email), anyString(), any());
        assertThat(jdbc.queryForObject("select count(*) from password_reset_tokens where user_id = ?",
            Integer.class, a.id)).isEqualTo(3);
    }

    // BR-A06: /reset-password 10 yêu cầu/IP/15 phút → 429 + Retry-After.
    @Test
    void resetIsLimitedPerIp() throws Exception {
        String ip = newIp();
        for (int i = 0; i < 10; i++) {
            reset("khongco@example.com", "123456", NEW_PASSWORD, ip).andExpect(status().isBadRequest());
        }
        reset("khongco@example.com", "123456", NEW_PASSWORD, ip).andExpect(status().isTooManyRequests())
            .andExpect(jsonPath("$.code").value("RATE_LIMITED"))
            .andExpect(header().exists(HttpHeaders.RETRY_AFTER));
        reset("khongco@example.com", "123456", NEW_PASSWORD, newIp()).andExpect(status().isBadRequest());
    }

    @Test
    void invalidInputIsValidationError() throws Exception {
        String ip = newIp();
        Account a = newAccount();
        reset(a.email, "12ab56", NEW_PASSWORD, ip).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.code").exists());
        reset(a.email, "123456", "matkhau", ip).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.newPassword").exists());
        reset(a.email, "123456", "ê".repeat(37) + "1", ip).andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.fieldErrors.newPassword").exists());
        forgot("", ip).andExpect(status().isBadRequest()).andExpect(jsonPath("$.fieldErrors.email").exists());
        verify(mailer, never()).send(anyString(), anyString(), any());
    }

    private record Account(String email, UUID id, String access, String refresh) {
    }

    private String requestCode(Account a, String ip) throws Exception {
        forgot(a.email, ip).andExpect(status().isNoContent());
        ArgumentCaptor<String> code = ArgumentCaptor.forClass(String.class);
        verify(mailer, timeout(5000)).send(eq(a.email), code.capture(), any());
        return code.getValue();
    }

    private static String newIp() {
        var r = ThreadLocalRandom.current();
        return "10.%d.%d.%d".formatted(r.nextInt(256), r.nextInt(256), r.nextInt(1, 255));
    }

    private Account newAccount() throws Exception {
        String email = "p" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\",\"fullName\":\"Test\"}".formatted(email, PASSWORD)))
            .andExpect(status().isCreated());
        String body = login(email, PASSWORD).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return new Account(email, UUID.fromString(JsonPath.read(body, "$.user.id")),
            JsonPath.read(body, "$.accessToken"), JsonPath.read(body, "$.refreshToken"));
    }

    private ResultActions login(String email, String password) throws Exception {
        return mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
            .content("{\"email\":\"%s\",\"password\":\"%s\"}".formatted(email, password)));
    }

    private ResultActions forgot(String email, String ip) throws Exception {
        return mvc.perform(post("/api/v1/auth/forgot-password").with(r -> {
            r.setRemoteAddr(ip);
            return r;
        }).contentType(MediaType.APPLICATION_JSON).content("{\"email\":\"%s\"}".formatted(email)));
    }

    private ResultActions reset(String email, String code, String password, String ip) throws Exception {
        return mvc.perform(post("/api/v1/auth/reset-password").with(r -> {
            r.setRemoteAddr(ip);
            return r;
        }).contentType(MediaType.APPLICATION_JSON).content("""
            {"email":"%s","code":"%s","newPassword":"%s"}
            """.formatted(email, code, password)));
    }
}
