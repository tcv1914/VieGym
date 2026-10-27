-- Hồ sơ sức khỏe và mục tiêu dinh dưỡng (ngày 5). Quy tắc: docs/04-business-rules.md §3,
-- cách tính: docs/11-health-calculation-rules.md.

CREATE TABLE health_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    -- Giới tính dùng cho hệ số Mifflin-St Jeor, không phải thông tin hiển thị.
    sex VARCHAR(6) NOT NULL,
    date_of_birth DATE NOT NULL,
    height_cm NUMERIC(4,1) NOT NULL,
    -- Cân nặng dùng tính mục tiêu hiện tại; nhật ký cân nặng là bảng riêng (ngày 13, BR-H02).
    weight_kg NUMERIC(4,1) NOT NULL,
    activity_level VARCHAR(12) NOT NULL,
    goal VARCHAR(12) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT health_profiles_user_key UNIQUE (user_id),
    CONSTRAINT health_profiles_sex_check CHECK (sex IN ('MALE', 'FEMALE')),
    CONSTRAINT health_profiles_height_check CHECK (height_cm BETWEEN 100 AND 250),
    CONSTRAINT health_profiles_weight_check CHECK (weight_kg BETWEEN 30 AND 300),
    CONSTRAINT health_profiles_activity_check
        CHECK (activity_level IN ('SEDENTARY', 'LIGHT', 'MODERATE', 'ACTIVE', 'VERY_ACTIVE')),
    CONSTRAINT health_profiles_goal_check CHECK (goal IN ('LOSE_WEIGHT', 'MAINTAIN', 'GAIN_MUSCLE'))
);

-- Chỉ giữ mục tiêu hiện tại (BR-H03); ghi lại cùng giao dịch với hồ sơ (BR-H01).
CREATE TABLE nutrition_targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    bmi NUMERIC(5,2) NOT NULL,
    bmr_kcal NUMERIC(6,1) NOT NULL,
    tdee_kcal NUMERIC(6,1) NOT NULL,
    target_kcal NUMERIC(6,1) NOT NULL,
    protein_g NUMERIC(5,1) NOT NULL,
    carbs_g NUMERIC(5,1) NOT NULL,
    fat_g NUMERIC(5,1) NOT NULL,
    -- Mục tiêu bị nâng lên ngưỡng dưới (docs/04 §3.4); lưu lại vì GET không tính lại.
    kcal_floor_applied BOOLEAN NOT NULL,
    formula_version VARCHAR(20) NOT NULL,
    calculated_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT nutrition_targets_user_key UNIQUE (user_id),
    CONSTRAINT nutrition_targets_positive_check
        CHECK (bmi > 0 AND bmr_kcal > 0 AND tdee_kcal > 0 AND target_kcal > 0),
    CONSTRAINT nutrition_targets_macro_check CHECK (protein_g >= 0 AND carbs_g >= 0 AND fat_g >= 0)
);
