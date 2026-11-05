-- Thực đơn theo ngày (ngày 10). Bảng gốc: docs/03 §6, quy tắc: docs/04 BR-N02..N07,
-- thiết kế và phần khác plan ngày 10: docs/23-meal-planner-design.md.
-- Mục món lưu snapshot dinh dưỡng một khẩu phần lúc thêm: admin sửa/ẩn món sau đó không làm
-- đổi thực đơn đã ghi (NUT-BR05, NUT-BR06).

CREATE TABLE meal_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    -- Ngày theo múi giờ user (users.timezone), không theo giờ máy chủ.
    plan_date DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- NUT-BR01: một thực đơn/user/ngày. Service đã khóa hàng users trước khi tạo.
    CONSTRAINT meal_plans_user_date_key UNIQUE (user_id, plan_date)
);

CREATE TABLE meal_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meal_plan_id UUID NOT NULL REFERENCES meal_plans(id) ON DELETE CASCADE,
    -- RESTRICT: món chỉ ẩn (is_active), không xóa khi đã có trong thực đơn.
    food_id UUID NOT NULL REFERENCES foods(id),
    -- foods.revision lúc thêm: biết snapshot lấy từ phiên bản số liệu nào.
    food_revision INTEGER NOT NULL,
    meal_type VARCHAR(10) NOT NULL,
    -- BR-N02: > 0, ≤ 20, tối đa 2 chữ số lẻ.
    servings NUMERIC(5, 2) NOT NULL,
    food_name_snapshot VARCHAR(150) NOT NULL,
    -- NULL khi nguồn không ghi khối lượng phần (docs/20 §2); mô tả luôn có.
    serving_size_snapshot NUMERIC(7, 2),
    serving_unit_snapshot VARCHAR(20),
    serving_description_snapshot VARCHAR(100) NOT NULL,
    -- Dinh dưỡng của MỘT khẩu phần, không phải tổng sau khi nhân servings.
    kcal_per_serving_snapshot NUMERIC(7, 2) NOT NULL,
    protein_per_serving_snapshot NUMERIC(6, 2) NOT NULL,
    carbs_per_serving_snapshot NUMERIC(6, 2) NOT NULL,
    fat_per_serving_snapshot NUMERIC(6, 2) NOT NULL,
    data_quality_snapshot VARCHAR(10) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT meal_entries_meal_type_check CHECK (meal_type IN ('BREAKFAST', 'LUNCH', 'DINNER', 'SNACK')),
    CONSTRAINT meal_entries_servings_check CHECK (servings > 0 AND servings <= 20),
    CONSTRAINT meal_entries_serving_check CHECK (
        (serving_size_snapshot IS NULL AND serving_unit_snapshot IS NULL)
        OR (serving_size_snapshot > 0 AND serving_unit_snapshot IS NOT NULL)),
    CONSTRAINT meal_entries_kcal_check CHECK (kcal_per_serving_snapshot >= 0),
    CONSTRAINT meal_entries_protein_check CHECK (protein_per_serving_snapshot >= 0),
    CONSTRAINT meal_entries_carbs_check CHECK (carbs_per_serving_snapshot >= 0),
    CONSTRAINT meal_entries_fat_check CHECK (fat_per_serving_snapshot >= 0),
    CONSTRAINT meal_entries_quality_check CHECK (data_quality_snapshot IN ('SOURCED', 'ESTIMATED', 'DEMO'))
);

CREATE INDEX meal_entries_plan_idx ON meal_entries (meal_plan_id, created_at, id);
CREATE INDEX meal_entries_food_idx ON meal_entries (food_id);
