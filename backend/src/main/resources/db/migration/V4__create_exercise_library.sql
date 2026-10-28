-- Thư viện bài tập (ngày 6). Thiết kế: docs/13-exercise-library-design.md, bảng gốc docs/03 §5.
-- Nhóm cơ/thiết bị là enum chuỗi theo docs/03 (một nhóm chính, một thiết bị chính/bài), không bảng danh mục.

CREATE TABLE exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Mã ổn định cho seed/import về sau; không đổi khi sửa tên.
    code VARCHAR(100) NOT NULL,
    name VARCHAR(150) NOT NULL,
    -- Tên bỏ dấu, chữ thường, gộp khoảng trắng; backend tính bằng SearchText.normalize.
    name_search VARCHAR(150) NOT NULL,
    muscle_group VARCHAR(20) NOT NULL,
    equipment VARCHAR(20) NOT NULL,
    difficulty VARCHAR(12) NOT NULL,
    -- Mỗi dòng một bước / một lỗi.
    instructions TEXT NOT NULL,
    common_mistakes TEXT NOT NULL,
    -- URL tuyệt đối hoặc key tương đối dưới /media/ (backend ghép host khi trả API).
    thumbnail_url VARCHAR(500),
    media_type VARCHAR(10),
    media_url VARCHAR(500),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    content_source VARCHAR(500),
    media_license VARCHAR(500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT exercises_code_key UNIQUE (code),
    CONSTRAINT exercises_muscle_group_check CHECK (muscle_group IN
        ('CHEST', 'BACK', 'SHOULDERS', 'ARMS', 'LEGS', 'GLUTES', 'CORE', 'FULL_BODY', 'CARDIO')),
    CONSTRAINT exercises_equipment_check CHECK (equipment IN
        ('NONE', 'DUMBBELL', 'BARBELL', 'MACHINE', 'CABLE', 'BAND', 'OTHER')),
    CONSTRAINT exercises_difficulty_check CHECK (difficulty IN ('BEGINNER', 'INTERMEDIATE', 'ADVANCED')),
    CONSTRAINT exercises_media_type_check CHECK (media_type IN ('IMAGE', 'GIF', 'VIDEO')),
    CONSTRAINT exercises_media_pair_check CHECK ((media_url IS NULL) = (media_type IS NULL))
);

CREATE UNIQUE INDEX exercises_name_lower_key ON exercises (lower(name));
CREATE INDEX exercises_filter_idx ON exercises (is_active, muscle_group, equipment, difficulty);
-- Tìm kiếm dùng LIKE '%...%' trên name_search: index B-tree không giúp được, chấp nhận cho vài chục bài.
