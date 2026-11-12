package com.viegym.backend.ai;

import java.util.List;
import java.util.UUID;

/** Cổng gọi ai-service (docs/05 §12 "Hợp đồng nội bộ"). Test thay bằng bản giả. */
public interface AiClient {
    Reply chat(Call call);

    record HistoryMessage(String role, String content) {
    }

    record Call(UUID requestId, String systemPrompt, AiContext context, List<HistoryMessage> history,
                String message) {
    }

    record Reply(String content, String model, Integer promptTokens, Integer completionTokens) {
    }

    /** Lỗi đã làm sạch: chỉ mã, không kèm nội dung từ nhà cung cấp. */
    class AiCallException extends RuntimeException {
        public static final String TIMEOUT = "AI_TIMEOUT";
        public static final String UPSTREAM = "AI_UPSTREAM_ERROR";
        public static final String EMPTY = "AI_EMPTY_RESPONSE";

        private final String code;

        public AiCallException(String code) {
            super(code);
            this.code = code;
        }

        public String getCode() {
            return code;
        }
    }
}
