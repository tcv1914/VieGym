-- Tài khoản và phiên đăng nhập (ngày 4). Thiết kế: docs/09-auth-design.md.

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Ứng dụng trim + lowercase trước khi ghi (BR-A01); UNIQUE chặn cả hai đăng ký đồng thời.
    email VARCHAR(254) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    role VARCHAR(10) NOT NULL DEFAULT 'USER',
    status VARCHAR(10) NOT NULL DEFAULT 'ACTIVE',
    timezone VARCHAR(50) NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT users_email_key UNIQUE (email),
    CONSTRAINT users_full_name_check CHECK (btrim(full_name) <> ''),
    CONSTRAINT users_role_check CHECK (role IN ('USER', 'ADMIN')),
    CONSTRAINT users_status_check CHECK (status IN ('ACTIVE', 'LOCKED'))
);

-- Một lần đăng nhập trên một thiết bị. JWT mang sid; mọi request riêng tư kiểm tra phiên này.
CREATE TABLE auth_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Hạn tuyệt đối; refresh không kéo dài quá mốc này.
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ
);

CREATE INDEX idx_auth_sessions_user ON auth_sessions(user_id);

CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES auth_sessions(id),
    -- SHA-256 (hex) của token ngẫu nhiên; không lưu token gốc.
    token_hash CHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    -- Đã đổi lấy token mới (xoay vòng). Giữ lại để nhận diện việc dùng lại token cũ.
    consumed_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    CONSTRAINT refresh_tokens_token_hash_key UNIQUE (token_hash)
);

CREATE INDEX idx_refresh_tokens_session ON refresh_tokens(session_id);
