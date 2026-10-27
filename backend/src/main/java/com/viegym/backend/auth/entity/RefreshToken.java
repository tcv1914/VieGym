package com.viegym.backend.auth.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "refresh_tokens")
public class RefreshToken {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "session_id", nullable = false, updatable = false)
    private AuthSession session;

    // Cột CHAR(64); khai báo CHAR để ddl-auto: validate không đòi VARCHAR.
    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(name = "token_hash", nullable = false, updatable = false, length = 64)
    private String tokenHash;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "expires_at", nullable = false, updatable = false)
    private Instant expiresAt;

    @Column(name = "consumed_at")
    private Instant consumedAt;

    @Column(name = "revoked_at")
    private Instant revokedAt;

    protected RefreshToken() {
    }

    public RefreshToken(AuthSession session, String tokenHash, Instant now, Instant expiresAt) {
        this.session = session;
        this.tokenHash = tokenHash;
        this.createdAt = now;
        this.expiresAt = expiresAt;
    }

    public boolean isConsumed() {
        return consumedAt != null;
    }

    public boolean isUsable(Instant now) {
        return consumedAt == null && revokedAt == null && now.isBefore(expiresAt);
    }

    public void consume(Instant now) {
        consumedAt = now;
    }

    public AuthSession getSession() {
        return session;
    }
}
