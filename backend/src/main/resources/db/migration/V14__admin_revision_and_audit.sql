-- Ngày 14 (docs/31): admin sửa danh mục cần khóa lạc quan và dấu vết.

-- foods đã có revision từ V9; exercises thêm để admin sửa bài có cùng cơ chế 409.
ALTER TABLE exercises ADD COLUMN revision INTEGER NOT NULL DEFAULT 1;
ALTER TABLE exercises ADD CONSTRAINT exercises_revision_check CHECK (revision >= 1);
ALTER TABLE foods ADD CONSTRAINT foods_revision_check CHECK (revision >= 1);

-- Chỉ thêm, không sửa/xóa qua ứng dụng. Không lưu mật khẩu, token hay giá trị dữ liệu cá nhân:
-- changed_fields chỉ là tên trường.
CREATE TABLE admin_audit_logs (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id       UUID NOT NULL REFERENCES users (id),
    action         VARCHAR(30) NOT NULL,
    entity_type    VARCHAR(20) NOT NULL,
    entity_id      UUID NOT NULL,
    reason         VARCHAR(300),
    changed_fields VARCHAR(500),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT admin_audit_logs_action_check
        CHECK (action IN ('CREATE', 'UPDATE', 'ACTIVATE', 'DEACTIVATE', 'LOCK', 'UNLOCK')),
    CONSTRAINT admin_audit_logs_entity_type_check CHECK (entity_type IN ('FOOD', 'EXERCISE', 'USER'))
);

CREATE INDEX admin_audit_logs_entity_idx ON admin_audit_logs (entity_type, entity_id, created_at DESC);
CREATE INDEX admin_audit_logs_actor_idx ON admin_audit_logs (actor_id, created_at DESC);

-- Danh sách user cho admin: sắp theo ngày tạo mới nhất, id để ổn định.
CREATE INDEX users_created_idx ON users (created_at DESC, id);
