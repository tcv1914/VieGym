package com.viegym.backend.admin.audit;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * Dấu vết thao tác admin (docs/31 §4). Chỉ thêm; ghi cùng giao dịch với thay đổi. {@code changedFields}
 * là tên trường, không có giá trị, nên không chứa mật khẩu/token/dữ liệu cá nhân.
 */
@Entity
@Table(name = "admin_audit_logs")
public class AuditLog {
    public enum Action { CREATE, UPDATE, ACTIVATE, DEACTIVATE, LOCK, UNLOCK }

    public enum EntityType { FOOD, EXERCISE, USER }

    @Id
    private UUID id;

    @Column(name = "actor_id", nullable = false, updatable = false)
    private UUID actorId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, updatable = false, length = 30)
    private Action action;

    @Enumerated(EnumType.STRING)
    @Column(name = "entity_type", nullable = false, updatable = false, length = 20)
    private EntityType entityType;

    @Column(name = "entity_id", nullable = false, updatable = false)
    private UUID entityId;

    @Column(updatable = false, length = 300)
    private String reason;

    @Column(name = "changed_fields", updatable = false, length = 500)
    private String changedFields;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected AuditLog() {
    }

    public AuditLog(UUID actorId, Action action, EntityType entityType, UUID entityId, String reason,
                    String changedFields, Instant createdAt) {
        this.id = UUID.randomUUID();
        this.actorId = actorId;
        this.action = action;
        this.entityType = entityType;
        this.entityId = entityId;
        this.reason = reason;
        this.changedFields = changedFields;
        this.createdAt = createdAt;
    }
}
