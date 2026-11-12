package com.viegym.backend.ai.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

/** Một lần bấm "Gửi" (docs/03 §7): trạng thái xử lý, tách khỏi tin nhắn để chống gửi lặp. */
@Entity
@Table(name = "ai_chat_requests")
public class AiChatRequest {
    public enum Status { PROCESSING, SUCCEEDED, FAILED }

    /** BR-AI07: PROCESSING quá 2 phút (vd. server khởi động lại) coi là FAILED / AI_TIMEOUT. */
    public static final Duration STALE_AFTER = Duration.ofMinutes(2);

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "client_request_id", nullable = false, updatable = false)
    private UUID clientRequestId;

    @Column(name = "conversation_id", nullable = false, updatable = false)
    private UUID conversationId;

    @Column(name = "user_message_id", nullable = false, updatable = false)
    private UUID userMessageId;

    @Column(name = "assistant_message_id")
    private UUID assistantMessageId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private Status status;

    @Column(name = "error_code", length = 50)
    private String errorCode;

    @Column(name = "attempt_count", nullable = false)
    private short attemptCount;

    @Column(length = 100)
    private String model;

    @Column(name = "prompt_tokens")
    private Integer promptTokens;

    @Column(name = "completion_tokens")
    private Integer completionTokens;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "completed_at")
    private Instant completedAt;

    protected AiChatRequest() {
    }

    public AiChatRequest(UUID userId, UUID clientRequestId, UUID conversationId, UUID userMessageId, Instant now) {
        this.userId = userId;
        this.clientRequestId = clientRequestId;
        this.conversationId = conversationId;
        this.userMessageId = userMessageId;
        this.status = Status.PROCESSING;
        this.attemptCount = 1;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public boolean isStale(Instant now) {
        return status == Status.PROCESSING && updatedAt.plus(STALE_AFTER).isBefore(now);
    }

    /** Thử lại câu hỏi FAILED trên cùng tin nhắn (BR-AI06). */
    public void retry(Instant now) {
        this.status = Status.PROCESSING;
        this.errorCode = null;
        this.attemptCount++;
        this.updatedAt = now;
        this.completedAt = null;
    }

    public void succeed(UUID assistantMessageId, String model, Integer promptTokens, Integer completionTokens,
                        Instant now) {
        this.status = Status.SUCCEEDED;
        this.assistantMessageId = assistantMessageId;
        this.errorCode = null;
        this.model = model;
        this.promptTokens = promptTokens;
        this.completionTokens = completionTokens;
        this.updatedAt = now;
        this.completedAt = now;
    }

    public void fail(String errorCode, Instant now) {
        this.status = Status.FAILED;
        this.errorCode = errorCode;
        this.updatedAt = now;
        this.completedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public UUID getClientRequestId() {
        return clientRequestId;
    }

    public UUID getConversationId() {
        return conversationId;
    }

    public UUID getUserMessageId() {
        return userMessageId;
    }

    public UUID getAssistantMessageId() {
        return assistantMessageId;
    }

    public Status getStatus() {
        return status;
    }

    public String getErrorCode() {
        return errorCode;
    }

    public int getAttemptCount() {
        return attemptCount;
    }
}
