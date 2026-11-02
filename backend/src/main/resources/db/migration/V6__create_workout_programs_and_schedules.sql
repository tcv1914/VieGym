-- Giáo án và lịch tập (ngày 7). Bảng gốc: docs/03 §5, quy tắc: docs/04 §4 (BR-W01..W07),
-- thiết kế và phần khác plan ngày 7: docs/16-workout-program-schedule-design.md.

CREATE TABLE workout_programs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- NULL = giáo án mẫu (seed/admin). Chọn mẫu là sao chép thành bản của user (BR-W02).
    user_id UUID REFERENCES users(id),
    name VARCHAR(100) NOT NULL,
    description VARCHAR(1000),
    is_template BOOLEAN NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT FALSE,
    source_template_id UUID REFERENCES workout_programs(id),
    -- Khóa lạc quan: PUT phải gửi version đang sửa; lệch → 409 (docs/16 §3).
    version INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT workout_programs_template_owner_check CHECK (is_template = (user_id IS NULL)),
    CONSTRAINT workout_programs_template_active_check CHECK (NOT (is_template AND is_active))
);

-- BR-W01: tối đa một giáo án đang hoạt động mỗi user.
CREATE UNIQUE INDEX workout_programs_one_active_key ON workout_programs (user_id) WHERE is_active;
CREATE INDEX workout_programs_user_idx ON workout_programs (user_id);

CREATE TABLE workout_days (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    program_id UUID NOT NULL REFERENCES workout_programs(id) ON DELETE CASCADE,
    day_order SMALLINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    -- Buổi bị gỡ khỏi giáo án nhưng còn lịch tham chiếu (BR-W07): giữ nguyên cùng các bài của nó.
    archived_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT workout_days_order_check CHECK (day_order >= 1)
);

-- Không DEFERRABLE được (partial index): đổi thứ tự phải dời tạm +100 rồi đánh lại (docs/03 §5).
CREATE UNIQUE INDEX workout_days_order_key ON workout_days (program_id, day_order) WHERE archived_at IS NULL;

CREATE TABLE workout_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_day_id UUID NOT NULL REFERENCES workout_days(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES exercises(id),
    order_no SMALLINT NOT NULL,
    target_sets SMALLINT NOT NULL,
    target_reps SMALLINT NOT NULL,
    rest_seconds SMALLINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT workout_exercises_order_key UNIQUE (workout_day_id, order_no),
    -- Một bài không lặp trong cùng buổi (docs/16 §2).
    CONSTRAINT workout_exercises_exercise_key UNIQUE (workout_day_id, exercise_id),
    CONSTRAINT workout_exercises_order_check CHECK (order_no >= 1),
    CONSTRAINT workout_exercises_sets_check CHECK (target_sets BETWEEN 1 AND 10),
    CONSTRAINT workout_exercises_reps_check CHECK (target_reps BETWEEN 1 AND 100),
    CONSTRAINT workout_exercises_rest_check CHECK (rest_seconds BETWEEN 0 AND 600)
);

CREATE TABLE workout_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    -- RESTRICT: buổi còn lịch tham chiếu thì archive, không xóa (BR-W07).
    workout_day_id UUID NOT NULL REFERENCES workout_days(id),
    -- Ngày theo múi giờ của user (BR-G04), giờ địa phương tùy chọn.
    scheduled_date DATE NOT NULL,
    start_time TIME,
    status VARCHAR(10) NOT NULL DEFAULT 'SCHEDULED',
    note VARCHAR(500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT workout_schedules_status_check CHECK (status IN ('SCHEDULED', 'COMPLETED', 'CANCELLED'))
);

CREATE INDEX workout_schedules_user_date_idx ON workout_schedules (user_id, scheduled_date);
CREATE INDEX workout_schedules_day_idx ON workout_schedules (workout_day_id);
