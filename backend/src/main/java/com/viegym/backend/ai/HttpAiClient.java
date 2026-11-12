package com.viegym.backend.ai;

import java.net.http.HttpClient;
import java.net.http.HttpTimeoutException;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;

/**
 * POST {serviceUrl}/internal/chat với header X-Internal-Key. Gọi ngoài giao dịch DB (BR-AI05).
 * Log chỉ có requestId, thời lượng, kết quả — không ghi câu hỏi, context hay câu trả lời.
 */
@Component
public class HttpAiClient implements AiClient {
    private static final Logger log = LoggerFactory.getLogger(HttpAiClient.class);
    static final String KEY_HEADER = "X-Internal-Key";

    private final AiProperties properties;
    private final RestClient restClient;

    public HttpAiClient(AiProperties properties) {
        this.properties = properties;
        // HTTP/1.1: mặc định JDK thử nâng cấp h2c, uvicorn từ chối ("Unsupported upgrade request").
        HttpClient http = HttpClient.newBuilder().version(HttpClient.Version.HTTP_1_1)
            .connectTimeout(properties.connectTimeout()).build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(http);
        factory.setReadTimeout(properties.timeout());
        this.restClient = RestClient.builder().requestFactory(factory).baseUrl(properties.serviceUrl().toString()).build();
    }

    private record ServiceReply(String content, String model, Integer promptTokens, Integer completionTokens) {
    }

    @Override
    public Reply chat(Call call) {
        String key = properties.internalKey();
        if (key == null || key.isBlank()) {
            log.warn("AI request {}: thiếu AI_INTERNAL_KEY, không gọi ai-service", call.requestId());
            throw new AiCallException(AiCallException.UPSTREAM);
        }
        long started = System.nanoTime();
        String outcome = "OK";
        try {
            ServiceReply reply = restClient.post().uri("/internal/chat")
                .contentType(MediaType.APPLICATION_JSON)
                .header(KEY_HEADER, key)
                .body(Map.of("requestId", call.requestId(), "systemPrompt", call.systemPrompt(),
                    "context", call.context(), "history", call.history(), "message", call.message()))
                .retrieve()
                .body(ServiceReply.class);
            // BR-AI08: rỗng/không hợp lệ → không lưu tin ASSISTANT.
            if (reply == null || reply.content() == null || reply.content().isBlank()) {
                throw new AiCallException(AiCallException.EMPTY);
            }
            return new Reply(reply.content().strip(), reply.model(), reply.promptTokens(), reply.completionTokens());
        } catch (AiCallException e) {
            outcome = e.getCode();
            throw e;
        } catch (RestClientResponseException e) {
            String body = e.getResponseBodyAsString();
            String code = e.getStatusCode().value() == 504 || body.contains(AiCallException.TIMEOUT)
                ? AiCallException.TIMEOUT
                : body.contains(AiCallException.EMPTY) ? AiCallException.EMPTY : AiCallException.UPSTREAM;
            outcome = code + " (HTTP " + e.getStatusCode().value() + ")";
            throw new AiCallException(code);
        } catch (ResourceAccessException e) {
            String code = hasTimeoutCause(e) ? AiCallException.TIMEOUT : AiCallException.UPSTREAM;
            outcome = code + " (" + e.getClass().getSimpleName() + ")";
            throw new AiCallException(code);
        } catch (RestClientException e) {
            outcome = AiCallException.UPSTREAM + " (" + e.getClass().getSimpleName() + ")";
            throw new AiCallException(AiCallException.UPSTREAM);
        } finally {
            log.info("AI request {} → {} trong {} ms", call.requestId(), outcome,
                (System.nanoTime() - started) / 1_000_000);
        }
    }

    private static boolean hasTimeoutCause(Throwable e) {
        for (Throwable t = e; t != null; t = t.getCause()) {
            if (t instanceof HttpTimeoutException || t instanceof java.net.SocketTimeoutException) {
                return true;
            }
        }
        return false;
    }
}
