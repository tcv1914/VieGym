package com.viegym.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.gen.RSAKeyGenerator;
import com.nimbusds.jose.jwk.source.ImmutableJWKSet;
import com.viegym.backend.TestcontainersConfiguration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
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
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/** Các tình huống AUTH-xx trong plan/huong-dan-ngay-4.md §9, chạy trên PostgreSQL thật (Testcontainers). */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class AuthFlowIntegrationTests {
    private static final String PASSWORD = "Matkhau123";

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcTemplate jdbc;

    @Autowired
    JwtEncoder jwtEncoder;

    // AUTH-01, AUTH-04
    @Test
    void registerCreatesUserAndIgnoresClientRole() throws Exception {
        String email = uniqueEmail();
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON).content("""
                {"email":"%s","password":"%s","fullName":"  Minh  ","role":"ADMIN","status":"LOCKED"}
                """.formatted(email, PASSWORD)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.email").value(email))
            .andExpect(jsonPath("$.fullName").value("Minh"))
            .andExpect(jsonPath("$.role").value("USER"))
            .andExpect(jsonPath("$.passwordHash").doesNotExist());

        var row = jdbc.queryForMap("select role, status, password_hash from users where email = ?", email);
        assertThat(row.get("role")).isEqualTo("USER");
        assertThat(row.get("status")).isEqualTo("ACTIVE");
        assertThat((String) row.get("password_hash")).startsWith("{bcrypt}").doesNotContain(PASSWORD);
    }

    // AUTH-02
    @Test
    void duplicateEmailIgnoringCaseIsConflict() throws Exception {
        String email = uniqueEmail();
        register(email);
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON).content("""
                {"email":"  %s ","password":"%s","fullName":"Minh"}
                """.formatted(email.toUpperCase(), PASSWORD)))
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.code").value("EMAIL_ALREADY_EXISTS"));
    }

    // AUTH-03
    @Test
    void invalidRegisterReturnsFieldErrors() throws Exception {
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON).content("""
                {"email":"khong-phai-email","password":"ngan","fullName":" "}
                """))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
            .andExpect(jsonPath("$.fieldErrors.email").exists())
            .andExpect(jsonPath("$.fieldErrors.password").exists())
            .andExpect(jsonPath("$.fieldErrors.fullName").exists());
    }

    // AUTH-05, AUTH-09
    @Test
    void loginReturnsTokensAndMeReturnsOnlyOwner() throws Exception {
        String emailA = uniqueEmail();
        String emailB = uniqueEmail();
        register(emailA);
        register(emailB);
        String accessA = JsonPath.read(login(emailA.toUpperCase()), "$.accessToken");
        String accessB = JsonPath.read(login(emailB), "$.accessToken");

        me(accessA).andExpect(status().isOk()).andExpect(jsonPath("$.email").value(emailA));
        me(accessB).andExpect(status().isOk()).andExpect(jsonPath("$.email").value(emailB));
    }

    @Test
    void loginResponseIsNotCached() throws Exception {
        String email = uniqueEmail();
        register(email);
        loginRequest(email, PASSWORD)
            .andExpect(status().isOk())
            .andExpect(header().string(HttpHeaders.CACHE_CONTROL, org.hamcrest.Matchers.containsString("no-store")))
            .andExpect(jsonPath("$.tokenType").value("Bearer"))
            .andExpect(jsonPath("$.accessTokenExpiresIn").value(900));
    }

    // AUTH-06
    @Test
    void wrongPasswordAndUnknownEmailGiveSameError() throws Exception {
        String email = uniqueEmail();
        register(email);
        loginRequest(email, "SaiMatkhau999")
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"))
            .andExpect(jsonPath("$.accessToken").doesNotExist());
        loginRequest(uniqueEmail(), PASSWORD)
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
    }

    // BR-A09 (ngày 17, BUG-01): 5 lần sai/email → 429 + Retry-After, kể cả khi lần sau đúng mật khẩu.
    // Email không tồn tại cũng bị chặn y hệt, nên giới hạn không giúp dò tài khoản.
    @Test
    void repeatedWrongPasswordsAreRateLimitedPerEmail() throws Exception {
        String email = uniqueEmail();
        String unknown = uniqueEmail();
        register(email);
        for (int i = 0; i < 5; i++) {
            loginRequest(email, "SaiMatkhau999").andExpect(status().isUnauthorized());
            loginRequest(unknown, "SaiMatkhau999").andExpect(status().isUnauthorized());
        }
        for (String target : new String[] {email, unknown}) {
            loginRequest(target, PASSWORD)
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("RATE_LIMITED"))
                .andExpect(jsonPath("$.accessToken").doesNotExist())
                .andExpect(header().exists(HttpHeaders.RETRY_AFTER));
        }
        // Tài khoản khác vẫn đăng nhập được; đúng mật khẩu sau 4 lần sai xóa bộ đếm.
        String other = uniqueEmail();
        register(other);
        for (int i = 0; i < 4; i++) {
            loginRequest(other, "SaiMatkhau999").andExpect(status().isUnauthorized());
        }
        login(other);
        for (int i = 0; i < 4; i++) {
            loginRequest(other, "SaiMatkhau999").andExpect(status().isUnauthorized());
        }
        login(other);
    }

    // Public endpoint không bị chặn vì app gửi kèm access token cũ/hỏng.
    @Test
    void staleBearerHeaderDoesNotBlockLogin() throws Exception {
        String email = uniqueEmail();
        register(email);
        mvc.perform(post("/api/v1/auth/login").header(HttpHeaders.AUTHORIZATION, "Bearer rac")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\"}".formatted(email, PASSWORD)))
            .andExpect(status().isOk());
    }

    // AUTH-07
    @Test
    void meWithoutTokenIsUnauthorized() throws Exception {
        mvc.perform(get("/api/v1/users/me"))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    // AUTH-08
    @Test
    void forgedExpiredOrForeignTokensAreRejected() throws Exception {
        String email = uniqueEmail();
        register(email);
        String body = login(email);
        UUID userId = UUID.fromString(JsonPath.read(body, "$.user.id"));
        String access = JsonPath.read(body, "$.accessToken");
        String sid = com.nimbusds.jwt.SignedJWT.parse(access).getJWTClaimsSet().getStringClaim("sid");
        Instant now = Instant.now();

        me("khong-phai-jwt").andExpect(status().isUnauthorized());
        // Chữ ký bằng khóa khác.
        RSAKey otherKey = new RSAKeyGenerator(2048).generate();
        JwtEncoder foreign = new NimbusJwtEncoder(new ImmutableJWKSet<>(new JWKSet(otherKey)));
        me(sign(foreign, claims(userId, sid, now).build())).andExpect(status().isUnauthorized());
        // Đúng khóa nhưng sai issuer / audience / đã hết hạn / sid lạ.
        me(sign(jwtEncoder, claims(userId, sid, now).issuer("ke-gia-mao").build())).andExpect(status().isUnauthorized());
        me(sign(jwtEncoder, claims(userId, sid, now).audience(List.of("app-khac")).build()))
            .andExpect(status().isUnauthorized());
        me(sign(jwtEncoder, claims(userId, sid, now.minus(1, ChronoUnit.HOURS)).build()))
            .andExpect(status().isUnauthorized());
        me(sign(jwtEncoder, claims(userId, UUID.randomUUID().toString(), now).build()))
            .andExpect(status().isUnauthorized());
        // Đối chứng: cùng cách ký với claims đúng thì được chấp nhận.
        me(sign(jwtEncoder, claims(userId, sid, now).build())).andExpect(status().isOk());
    }

    // AUTH-10
    @Test
    void userCannotCallAdminApi() throws Exception {
        String email = uniqueEmail();
        register(email);
        String access = JsonPath.read(login(email), "$.accessToken");
        mvc.perform(get("/api/v1/admin/users").header(HttpHeaders.AUTHORIZATION, "Bearer " + access))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    // AUTH-11, AUTH-12 (+ BR-A04: dùng lại token cũ thu hồi mọi phiên)
    @Test
    void refreshRotatesAndReuseRevokesSessions() throws Exception {
        String email = uniqueEmail();
        register(email);
        String first = login(email);
        String oldRefresh = JsonPath.read(first, "$.refreshToken");

        String second = refreshRequest(oldRefresh).andExpect(status().isOk())
            .andReturn().getResponse().getContentAsString();
        String newRefresh = JsonPath.read(second, "$.refreshToken");
        String newAccess = JsonPath.read(second, "$.accessToken");
        assertThat(newRefresh).isNotEqualTo(oldRefresh);
        me(newAccess).andExpect(status().isOk());

        refreshRequest(oldRefresh).andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code").value("INVALID_REFRESH_TOKEN"));
        refreshRequest(newRefresh).andExpect(status().isUnauthorized());
        me(newAccess).andExpect(status().isUnauthorized());
    }

    // AUTH-13
    @Test
    void concurrentRefreshWithSameTokenSucceedsOnce() throws Exception {
        String email = uniqueEmail();
        register(email);
        String refresh = JsonPath.read(login(email), "$.refreshToken");

        int threads = 5;
        CountDownLatch start = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        try {
            Callable<Integer> call = () -> {
                start.await();
                return refreshRequest(refresh).andReturn().getResponse().getStatus();
            };
            List<Future<Integer>> results = java.util.stream.IntStream.range(0, threads)
                .mapToObj(i -> pool.submit(call)).toList();
            start.countDown();
            long ok = 0;
            for (Future<Integer> result : results) {
                int code = result.get();
                assertThat(code).isIn(200, 401);
                if (code == 200) {
                    ok++;
                }
            }
            assertThat(ok).isEqualTo(1);
        } finally {
            pool.shutdownNow();
        }
    }

    // AUTH-14
    @Test
    void logoutRevokesOnlyCurrentSession() throws Exception {
        String email = uniqueEmail();
        register(email);
        String phone = login(email);
        String tablet = login(email);
        String refresh = JsonPath.read(phone, "$.refreshToken");
        String access = JsonPath.read(phone, "$.accessToken");

        logoutRequest(refresh).andExpect(status().isNoContent());
        refreshRequest(refresh).andExpect(status().isUnauthorized());
        me(access).andExpect(status().isUnauthorized());
        // Idempotent.
        logoutRequest(refresh).andExpect(status().isNoContent());
        logoutRequest("token-khong-ton-tai").andExpect(status().isNoContent());
        // Phiên khác của cùng tài khoản vẫn dùng được.
        me(JsonPath.read(tablet, "$.accessToken")).andExpect(status().isOk());
        refreshRequest(JsonPath.read(tablet, "$.refreshToken")).andExpect(status().isOk());
    }

    // AUTH-15
    @Test
    void lockedAccountIsBlockedEverywhere() throws Exception {
        String email = uniqueEmail();
        register(email);
        String body = login(email);
        jdbc.update("update users set status = 'LOCKED' where email = ?", email);

        me(JsonPath.read(body, "$.accessToken")).andExpect(status().isForbidden())
            .andExpect(jsonPath("$.code").value("ACCOUNT_LOCKED"));
        refreshRequest(JsonPath.read(body, "$.refreshToken")).andExpect(status().isForbidden())
            .andExpect(jsonPath("$.code").value("ACCOUNT_LOCKED"));
        loginRequest(email, PASSWORD).andExpect(status().isForbidden())
            .andExpect(jsonPath("$.code").value("ACCOUNT_LOCKED"));
        // Sai mật khẩu vẫn chỉ thấy lỗi chung, không lộ trạng thái khóa.
        loginRequest(email, "SaiMatkhau999").andExpect(status().isUnauthorized());
    }

    private static String uniqueEmail() {
        return "u" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
    }

    private void register(String email) throws Exception {
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\",\"fullName\":\"Test\"}".formatted(email, PASSWORD)))
            .andExpect(status().isCreated());
    }

    private String login(String email) throws Exception {
        return loginRequest(email, PASSWORD).andExpect(status().isOk())
            .andReturn().getResponse().getContentAsString();
    }

    private ResultActions loginRequest(String email, String password) throws Exception {
        return mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
            .content("{\"email\":\"%s\",\"password\":\"%s\"}".formatted(email, password)));
    }

    private ResultActions refreshRequest(String refreshToken) throws Exception {
        return mvc.perform(post("/api/v1/auth/refresh").contentType(MediaType.APPLICATION_JSON)
            .content("{\"refreshToken\":\"%s\"}".formatted(refreshToken)));
    }

    private ResultActions logoutRequest(String refreshToken) throws Exception {
        return mvc.perform(post("/api/v1/auth/logout").contentType(MediaType.APPLICATION_JSON)
            .content("{\"refreshToken\":\"%s\"}".formatted(refreshToken)));
    }

    private ResultActions me(String accessToken) throws Exception {
        return mvc.perform(get("/api/v1/users/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken));
    }

    private static JwtClaimsSet.Builder claims(UUID userId, String sid, Instant issuedAt) {
        return JwtClaimsSet.builder()
            .issuer("viegym-backend")
            .audience(List.of("viegym-mobile"))
            .subject(userId.toString())
            .claim("sid", sid)
            .issuedAt(issuedAt)
            .expiresAt(issuedAt.plus(15, ChronoUnit.MINUTES));
    }

    private static String sign(JwtEncoder encoder, JwtClaimsSet claims) {
        JwsHeader header = JwsHeader.with(SignatureAlgorithm.RS256).type("JWT").build();
        return encoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
    }
}
