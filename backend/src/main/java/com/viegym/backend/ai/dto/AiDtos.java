package com.viegym.backend.ai.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.viegym.backend.ai.entity.AiChatRequest;
import com.viegym.backend.ai.entity.AiMessage;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

/** Request/response của /ai (docs/05 §12, docs/27). */
public final class AiDtos {
    private AiDtos() {
    }

    /**
     * Chỉ câu hỏi và định danh; không nhận hồ sơ, thực đơn, userId hay system prompt (BR-AI02).
     * Trường lạ bị bỏ qua. Độ dài 1–2.000 sau trim kiểm tra ở service.
     */
    public record ChatRequest(
        @NotNull(message = "Thiếu mã yêu cầu")
        UUID clientRequestId,

        UUID conversationId,

        @NotNull(message = "Vui lòng nhập câu hỏi")
        @Size(max = 10_000, message = "Câu hỏi tối đa 2.000 ký tự")
        String message) {
    }

    public record ConversationRef(UUID id, String title) {
    }

    public record MessageItem(UUID id, AiMessage.Role role, String content, Instant createdAt) {
        public static MessageItem of(AiMessage m) {
            return new MessageItem(m.getId(), m.getRole(), m.getContent(), m.getCreatedAt());
        }
    }

    public record ChatResult(UUID requestId, UUID clientRequestId, AiChatRequest.Status status,
                             ConversationRef conversation, MessageItem userMessage, MessageItem assistantMessage) {
    }

    public record ConversationItem(UUID id, String title, Instant lastMessageAt, Instant createdAt) {
    }

    /**
     * Tin nhắn trong lịch sử. {@code requestStatus}/{@code clientRequestId}/{@code errorCode} chỉ có ở
     * tin USER, để app hiện "Thử lại" cho câu hỏi FAILED (docs/05 §12).
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record HistoryItem(UUID id, AiMessage.Role role, String content, Instant createdAt,
                              AiChatRequest.Status requestStatus, UUID clientRequestId, String errorCode) {
    }
}
