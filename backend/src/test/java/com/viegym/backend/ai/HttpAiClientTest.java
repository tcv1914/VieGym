package com.viegym.backend.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.sun.net.httpserver.HttpServer;
import com.viegym.backend.ai.AiClient.AiCallException;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Ánh xạ phản hồi ai-service → mã lỗi ổn định (docs/27 §4), dùng HTTP server cục bộ giả. */
class HttpAiClientTest {
    private HttpServer server;
    private final AtomicReference<String> receivedKey = new AtomicReference<>();
    private final AtomicReference<String> receivedBody = new AtomicReference<>();
    private final AtomicReference<String> receivedUpgrade = new AtomicReference<>("not-called");
    private volatile int status = 200;
    private volatile String responseBody = "{}";
    private volatile long delayMs = 0;

    @BeforeEach
    void start() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/internal/chat", exchange -> {
            receivedKey.set(exchange.getRequestHeaders().getFirst("X-Internal-Key"));
            receivedUpgrade.set(exchange.getRequestHeaders().getFirst("Upgrade"));
            receivedBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            try {
                Thread.sleep(delayMs);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            byte[] bytes = responseBody.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(status, bytes.length);
            exchange.getResponseBody().write(bytes);
            exchange.close();
        });
        server.start();
    }

    @AfterEach
    void stop() {
        server.stop(0);
    }

    private HttpAiClient client(String key) {
        return new HttpAiClient(new AiProperties(true,
            URI.create("http://127.0.0.1:" + server.getAddress().getPort()), key, Duration.ofSeconds(1),
            Duration.ofMillis(500), 5, 50, 10));
    }

    private static AiClient.Call call() {
        AiContext ctx = new AiContext(LocalDate.of(2026, 11, 9), "Asia/Ho_Chi_Minh", "Thứ Hai",
            AiContext.Profile.MISSING, null, new AiContext.MealPlan(0, List.of(), null, null), List.of(), List.of());
        return new AiClient.Call(UUID.randomUUID(), "system", ctx,
            List.of(new AiClient.HistoryMessage("USER", "trước")), "Xin chào");
    }

    @Test
    void successSendsKeyAndContract() {
        responseBody = "{\"content\":\"  Chào bạn  \",\"model\":\"m\",\"promptTokens\":10,\"completionTokens\":2}";
        AiClient.Reply reply = client("secret").chat(call());
        assertThat(reply.content()).isEqualTo("Chào bạn");
        assertThat(reply.model()).isEqualTo("m");
        assertThat(receivedKey.get()).isEqualTo("secret");
        // uvicorn từ chối yêu cầu nâng cấp h2c → phải là HTTP/1.1 thuần.
        assertThat(receivedUpgrade.get()).isNull();
        assertThat(receivedBody.get()).contains("\"systemPrompt\":\"system\"").contains("\"message\":\"Xin chào\"")
            .contains("\"status\":\"MISSING\"").contains("\"history\":[{\"role\":\"USER\"");
    }

    @Test
    void emptyContentIsEmptyResponse() {
        responseBody = "{\"content\":\"   \",\"model\":\"m\"}";
        assertThatThrownBy(() -> client("k").chat(call())).isInstanceOf(AiCallException.class)
            .extracting("code").isEqualTo(AiCallException.EMPTY);
    }

    @Test
    void gatewayTimeoutIsTimeout() {
        status = 504;
        responseBody = "{\"code\":\"AI_TIMEOUT\"}";
        assertThatThrownBy(() -> client("k").chat(call())).extracting("code").isEqualTo(AiCallException.TIMEOUT);
    }

    @Test
    void upstreamErrorsAreSanitized() {
        status = 502;
        responseBody = "{\"code\":\"AI_UPSTREAM_ERROR\",\"detail\":\"provider said: key=abc\"}";
        assertThatThrownBy(() -> client("k").chat(call())).isInstanceOf(AiCallException.class)
            .hasMessage(AiCallException.UPSTREAM);
        status = 401;
        assertThatThrownBy(() -> client("k").chat(call())).extracting("code").isEqualTo(AiCallException.UPSTREAM);
    }

    @Test
    void slowServiceTimesOut() {
        delayMs = 1500;
        responseBody = "{\"content\":\"muộn\"}";
        assertThatThrownBy(() -> client("k").chat(call())).extracting("code").isEqualTo(AiCallException.TIMEOUT);
    }

    @Test
    void unreachableServiceIsUpstream() {
        HttpAiClient c = client("k");
        server.stop(0);
        assertThatThrownBy(() -> c.chat(call())).extracting("code").isEqualTo(AiCallException.UPSTREAM);
    }

    @Test
    void missingKeyDoesNotCall() {
        assertThatThrownBy(() -> client(" ").chat(call())).extracting("code").isEqualTo(AiCallException.UPSTREAM);
        assertThat(receivedBody.get()).isNull();
    }
}
