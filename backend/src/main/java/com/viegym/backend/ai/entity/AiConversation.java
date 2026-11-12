package com.viegym.backend.ai.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** Hội thoại AI Coach của một user (docs/03 §7). */
@Entity
@Table(name = "ai_conversations")
public class AiConversation {
    /** docs/03: tiêu đề mặc định = 60 ký tự đầu của câu hỏi đầu tiên. */
    public static final int TITLE_LENGTH = 60;

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(nullable = false, length = 150)
    private String title;

    @Column(name = "last_message_at", nullable = false)
    private Instant lastMessageAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected AiConversation() {
    }

    public AiConversation(UUID userId, String firstQuestion, Instant now) {
        this.userId = userId;
        this.title = titleOf(firstQuestion);
        this.lastMessageAt = now;
        this.createdAt = now;
        this.updatedAt = now;
    }

    /** Một dòng, cắt theo code point để không làm vỡ ký tự ngoài BMP (emoji). */
    public static String titleOf(String question) {
        String oneLine = question.strip().replaceAll("\\s+", " ");
        if (oneLine.codePointCount(0, oneLine.length()) <= TITLE_LENGTH) {
            return oneLine;
        }
        return oneLine.substring(0, oneLine.offsetByCodePoints(0, TITLE_LENGTH)).strip() + "…";
    }

    public void touch(Instant now) {
        this.lastMessageAt = now;
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public String getTitle() {
        return title;
    }

    public Instant getLastMessageAt() {
        return lastMessageAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
