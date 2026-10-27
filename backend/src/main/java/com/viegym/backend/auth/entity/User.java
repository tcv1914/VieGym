package com.viegym.backend.auth.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "users")
public class User {
    public static final String DEFAULT_TIMEZONE = "Asia/Ho_Chi_Minh";

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, length = 254)
    private String email;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(name = "full_name", nullable = false, length = 100)
    private String fullName;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private UserRole role;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private UserStatus status;

    @Column(nullable = false, length = 50)
    private String timezone;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected User() {
    }

    /** Tài khoản mới luôn là USER + ACTIVE; client không chọn được role/status. */
    public User(String email, String passwordHash, String fullName, Instant now) {
        this.email = email;
        this.passwordHash = passwordHash;
        this.fullName = fullName;
        this.role = UserRole.USER;
        this.status = UserStatus.ACTIVE;
        this.timezone = DEFAULT_TIMEZONE;
        this.createdAt = now;
        this.updatedAt = now;
    }

    // DEFAULT của cột không tự đổi khi UPDATE.
    @PreUpdate
    void touch() {
        updatedAt = Instant.now();
    }

    public boolean isLocked() {
        return status == UserStatus.LOCKED;
    }

    public UUID getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public String getFullName() {
        return fullName;
    }

    public UserRole getRole() {
        return role;
    }

    public UserStatus getStatus() {
        return status;
    }

    public String getTimezone() {
        return timezone;
    }
}
