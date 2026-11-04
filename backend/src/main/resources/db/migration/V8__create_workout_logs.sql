-- Ghi nhận buổi tập (ngày 8). Bảng gốc: docs/03 §5, quy tắc: docs/04 BR-W04..W09,
-- thiết kế và phần khác plan ngày 8: docs/18-workout-log-design.md.
-- Log là dữ liệu thực tế đã chụp lại (tên buổi, tên bài, reps, mức tạ): sửa giáo án hay đổi tên
-- bài sau đó không làm đổi log (WO-BR04).

CREATE TABLE workout_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    -- WO-BR02: một lịch tối đa một log. Lớp bảo vệ cuối; service đã khóa dòng lịch trước.
    -- NULL dành cho tập tự do (ngoài MVP).
    schedule_id UUID REFERENCES workout_schedules(id),
    -- Lấy từ scheduled_date (ngày theo múi giờ user), không phải ngày ghi.
    workout_date DATE NOT NULL,
    workout_name_snapshot VARCHAR(100) NOT NULL,
    program_name_snapshot VARCHAR(100) NOT NULL,
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    note VARCHAR(1000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT workout_logs_schedule_key UNIQUE (schedule_id),
    CONSTRAINT workout_logs_time_check CHECK (ended_at IS NULL OR started_at IS NULL OR ended_at >= started_at)
);

-- Lịch sử: lọc theo user + ngày, sắp ngày giảm dần.
CREATE INDEX workout_logs_user_date_idx ON workout_logs (user_id, workout_date DESC, created_at DESC);

CREATE TABLE workout_log_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_log_id UUID NOT NULL REFERENCES workout_logs(id) ON DELETE CASCADE,
    -- RESTRICT: bài trong thư viện chỉ ẩn (is_active), không xóa khi đã có log.
    exercise_id UUID NOT NULL REFERENCES exercises(id),
    exercise_name_snapshot VARCHAR(150) NOT NULL,
    order_no SMALLINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT workout_log_exercises_order_key UNIQUE (workout_log_id, order_no),
    CONSTRAINT workout_log_exercises_exercise_key UNIQUE (workout_log_id, exercise_id),
    CONSTRAINT workout_log_exercises_order_check CHECK (order_no >= 1)
);

CREATE INDEX workout_log_exercises_exercise_idx ON workout_log_exercises (exercise_id);

CREATE TABLE workout_set_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    log_exercise_id UUID NOT NULL REFERENCES workout_log_exercises(id) ON DELETE CASCADE,
    set_no SMALLINT NOT NULL,
    reps SMALLINT NOT NULL,
    -- 0 = không dùng tạ ngoài (chống đẩy, plank theo lần...). Giới hạn kỹ thuật, không phải khuyến nghị.
    weight_kg NUMERIC(5, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT workout_set_logs_set_key UNIQUE (log_exercise_id, set_no),
    CONSTRAINT workout_set_logs_set_check CHECK (set_no >= 1),
    CONSTRAINT workout_set_logs_reps_check CHECK (reps BETWEEN 1 AND 1000),
    CONSTRAINT workout_set_logs_weight_check CHECK (weight_kg >= 0 AND weight_kg <= 999.99)
);
