-- AI Coach (ngày 12). Bảng gốc: docs/03 §7, quy tắc: docs/04 BR-AI01..10,
-- thiết kế và phần khác plan ngày 12: docs/27-ai-coach-design.md.
-- Chỉ lưu câu hỏi và câu trả lời hiển thị cho user; không lưu system prompt hay context.

CREATE TABLE ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(150) NOT NULL,
    last_message_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ai_conversations_user_last_idx ON ai_conversations (user_id, last_message_at DESC, id);

CREATE TABLE ai_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
    role VARCHAR(10) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ai_messages_role_check CHECK (role IN ('USER', 'ASSISTANT')),
    -- BR-AI04: câu hỏi ≤ 2.000 ký tự; câu trả lời bị ai-service giới hạn token, chặn thêm ở đây.
    CONSTRAINT ai_messages_content_check CHECK (
        char_length(content) BETWEEN 1 AND (CASE WHEN role = 'USER' THEN 2000 ELSE 20000 END))
);

CREATE INDEX ai_messages_conversation_idx ON ai_messages (conversation_id, created_at, id);

CREATE TABLE ai_chat_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    client_request_id UUID NOT NULL,
    conversation_id UUID NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
    user_message_id UUID NOT NULL REFERENCES ai_messages(id) ON DELETE CASCADE,
    assistant_message_id UUID REFERENCES ai_messages(id) ON DELETE SET NULL,
    status VARCHAR(10) NOT NULL,
    error_code VARCHAR(50),
    attempt_count SMALLINT NOT NULL DEFAULT 1,
    model VARCHAR(100),
    prompt_tokens INTEGER,
    completion_tokens INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    -- BR-AI06: gửi lặp cùng clientRequestId không tạo câu hỏi mới.
    CONSTRAINT ai_chat_requests_client_key UNIQUE (user_id, client_request_id),
    CONSTRAINT ai_chat_requests_user_message_key UNIQUE (user_message_id),
    CONSTRAINT ai_chat_requests_status_check CHECK (status IN ('PROCESSING', 'SUCCEEDED', 'FAILED')),
    CONSTRAINT ai_chat_requests_attempt_check CHECK (attempt_count >= 1)
);

-- Đếm giới hạn tần suất (BR-AI04) theo user và thời điểm.
CREATE INDEX ai_chat_requests_user_created_idx ON ai_chat_requests (user_id, created_at);
CREATE INDEX ai_chat_requests_user_updated_idx ON ai_chat_requests (user_id, updated_at);
-- Tìm request đang chạy trong một hội thoại.
CREATE INDEX ai_chat_requests_conversation_status_idx ON ai_chat_requests (conversation_id, status);
