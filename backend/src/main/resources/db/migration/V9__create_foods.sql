-- Thư viện món ăn (ngày 9). Bảng gốc: docs/03 §6; chính sách dữ liệu: docs/20-food-data-policy.md.
-- Dữ liệu seed ở V10 (sinh từ data/viendinhduong_mon_an.json).

CREATE TABLE food_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Mã ổn định dùng làm tham số lọc (?category=...).
    code VARCHAR(80) NOT NULL,
    name VARCHAR(150) NOT NULL,
    sort_order SMALLINT NOT NULL,
    CONSTRAINT food_categories_code_key UNIQUE (code)
);

CREATE TABLE foods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Mã của nguồn (vd. VPF-000272) — khóa nhập lại, không đổi.
    code VARCHAR(30) NOT NULL,
    -- Không UNIQUE theo tên (khác docs/03 ngày 2): nguồn có cùng món đo ở vùng/quán khác nhau,
    -- mỗi bản ghi là một phần ăn khác nhau; phân biệt bằng vùng + mã.
    name VARCHAR(150) NOT NULL,
    name_en VARCHAR(200),
    -- Bỏ dấu, chữ thường; cùng quy tắc SearchText.normalize.
    name_search VARCHAR(150) NOT NULL,
    category_id UUID NOT NULL REFERENCES food_categories(id),
    -- Vùng đo của nguồn: VPF toàn quốc, HAN Hà Nội, HAP Hải Phòng, SFF miền Bắc.
    region VARCHAR(3),
    -- Khẩu phần chuẩn. Nguồn chỉ công bố "1 phần" không kèm khối lượng → size/unit NULL,
    -- không suy đoán gram. Mọi số dinh dưỡng là của đúng khẩu phần này.
    serving_size NUMERIC(7, 2),
    serving_unit VARCHAR(20),
    serving_description VARCHAR(100) NOT NULL,
    kcal_per_serving NUMERIC(7, 2) NOT NULL,
    protein_per_serving NUMERIC(6, 2) NOT NULL,
    carbs_per_serving NUMERIC(6, 2) NOT NULL,
    fat_per_serving NUMERIC(6, 2) NOT NULL,
    data_quality VARCHAR(10) NOT NULL,
    source VARCHAR(200) NOT NULL,
    source_url VARCHAR(500),
    -- URL tuyệt đối tới ảnh nguồn (app tải trực tiếp; ảnh thuộc bản quyền nguồn).
    image_url VARCHAR(500),
    -- Lý do ẩn/cần rà (vd. năng lượng lệch so với 4P+4C+9F).
    review_note VARCHAR(300),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    -- Tăng khi số liệu đổi; thực đơn ngày 10 chụp snapshot nên không bị ảnh hưởng.
    revision INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT foods_code_key UNIQUE (code),
    CONSTRAINT foods_region_check CHECK (region IN ('VPF', 'HAN', 'HAP', 'SFF')),
    CONSTRAINT foods_serving_check CHECK (
        (serving_size IS NULL AND serving_unit IS NULL)
        OR (serving_size > 0 AND serving_unit IN ('g', 'ml'))),
    CONSTRAINT foods_kcal_check CHECK (kcal_per_serving >= 0),
    CONSTRAINT foods_protein_check CHECK (protein_per_serving >= 0),
    CONSTRAINT foods_carbs_check CHECK (carbs_per_serving >= 0),
    CONSTRAINT foods_fat_check CHECK (fat_per_serving >= 0),
    CONSTRAINT foods_quality_check CHECK (data_quality IN ('SOURCED', 'ESTIMATED', 'DEMO'))
);

CREATE INDEX foods_category_idx ON foods (category_id);
CREATE INDEX foods_active_name_idx ON foods (name_search, id) WHERE is_active;
