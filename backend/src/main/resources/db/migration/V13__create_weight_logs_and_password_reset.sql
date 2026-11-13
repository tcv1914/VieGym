-- Ngày 13: nhật ký cân nặng (UC08) và mã đặt lại mật khẩu (UC11).
-- Thiết kế: docs/29-weight-reset-design.md; quy tắc: docs/04 BR-WL01..02, BR-A06..07.

CREATE TABLE weight_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    -- Ngày đo theo users.timezone (BR-G04); "không ở tương lai" kiểm ở service vì phụ thuộc múi giờ.
    log_date DATE NOT NULL,
    weight_kg NUMERIC(4,1) NOT NULL,
    note VARCHAR(500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- BR-WL01: một bản ghi/user/ngày; POST cùng ngày ghi đè. Index của UNIQUE phục vụ luôn đọc theo user + khoảng ngày.
    CONSTRAINT weight_logs_user_date_key UNIQUE (user_id, log_date),
    CONSTRAINT weight_logs_weight_check CHECK (weight_kg BETWEEN 30.0 AND 300.0)
);

-- Không nhập lịch sử từ health_profiles.weight_kg: hồ sơ không lưu ngày đo, không bịa ngày (docs/29 §1).

CREATE TABLE password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    -- SHA-256 (hex) của "userId:mã". Không UNIQUE: mã 6 chữ số có thể trùng giữa các lần/user.
    token_hash CHAR(64) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    -- NULL = còn dùng được. Đặt khi: đặt lại thành công, có mã mới, hoặc sai lần thứ 5 (BR-A06).
    used_at TIMESTAMPTZ,
    attempt_count SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT password_reset_tokens_attempt_check CHECK (attempt_count BETWEEN 0 AND 5)
);

CREATE INDEX idx_password_reset_tokens_user ON password_reset_tokens(user_id, created_at DESC);
