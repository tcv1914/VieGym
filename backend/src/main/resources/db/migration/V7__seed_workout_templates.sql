-- Hai giáo án mẫu (ngày 7). Dữ liệu MINH HỌA cho đồ án, không phải khuyến nghị luyện tập cá nhân;
-- số sets/reps/nghỉ chưa được huấn luyện viên rà. Nguồn và lý do chọn bài: docs/16 §5.
-- Bài tham chiếu theo code của V5 (subquery NOT NULL: thiếu bài là migration lỗi, không âm thầm bỏ qua).
-- ID cố định để test và tài liệu tham chiếu được; sửa về sau bằng migration mới.

INSERT INTO workout_programs (id, user_id, name, description, is_template, is_active)
VALUES
    ('7e000000-0000-4000-8000-000000000001', NULL, 'Full Body cơ bản — 3 buổi',
     'Ba buổi toàn thân luân phiên A/B/C, tạ đơn và bài không dụng cụ. Dữ liệu minh họa đồ án, chưa được chuyên gia rà.',
     TRUE, FALSE),
    ('7e000000-0000-4000-8000-000000000002', NULL, 'Thân trên / Thân dưới — 4 buổi',
     'Bốn buổi chia thân trên và thân dưới, cần phòng tập có tạ đòn, cáp và máy. Dữ liệu minh họa đồ án, chưa được chuyên gia rà.',
     TRUE, FALSE);

INSERT INTO workout_days (id, program_id, day_order, name)
VALUES
    ('7e000000-0000-4000-8000-000000000101', '7e000000-0000-4000-8000-000000000001', 1, 'Buổi A'),
    ('7e000000-0000-4000-8000-000000000102', '7e000000-0000-4000-8000-000000000001', 2, 'Buổi B'),
    ('7e000000-0000-4000-8000-000000000103', '7e000000-0000-4000-8000-000000000001', 3, 'Buổi C'),
    ('7e000000-0000-4000-8000-000000000201', '7e000000-0000-4000-8000-000000000002', 1, 'Thân trên A'),
    ('7e000000-0000-4000-8000-000000000202', '7e000000-0000-4000-8000-000000000002', 2, 'Thân dưới A'),
    ('7e000000-0000-4000-8000-000000000203', '7e000000-0000-4000-8000-000000000002', 3, 'Thân trên B'),
    ('7e000000-0000-4000-8000-000000000204', '7e000000-0000-4000-8000-000000000002', 4, 'Thân dưới B');

INSERT INTO workout_exercises (workout_day_id, exercise_id, order_no, target_sets, target_reps, rest_seconds)
SELECT v.day_id::uuid, (SELECT e.id FROM exercises e WHERE e.code = v.code), v.order_no, v.sets, v.reps, v.rest
FROM (VALUES
    ('7e000000-0000-4000-8000-000000000101', 'goblet-squat', 1, 3, 10, 90),
    ('7e000000-0000-4000-8000-000000000101', 'push-up', 2, 3, 10, 60),
    ('7e000000-0000-4000-8000-000000000101', 'one-arm-dumbbell-row', 3, 3, 10, 60),
    ('7e000000-0000-4000-8000-000000000101', 'glute-bridge', 4, 3, 12, 60),
    ('7e000000-0000-4000-8000-000000000101', 'dead-bug', 5, 3, 10, 45),

    ('7e000000-0000-4000-8000-000000000102', 'dumbbell-lunge', 1, 3, 10, 90),
    ('7e000000-0000-4000-8000-000000000102', 'dumbbell-bench-press', 2, 3, 10, 90),
    ('7e000000-0000-4000-8000-000000000102', 'lat-pulldown', 3, 3, 10, 90),
    ('7e000000-0000-4000-8000-000000000102', 'dumbbell-shoulder-press', 4, 3, 10, 60),
    ('7e000000-0000-4000-8000-000000000102', 'bird-dog', 5, 3, 10, 45),

    ('7e000000-0000-4000-8000-000000000103', 'bodyweight-squat', 1, 3, 15, 60),
    ('7e000000-0000-4000-8000-000000000103', 'incline-dumbbell-press', 2, 3, 10, 90),
    ('7e000000-0000-4000-8000-000000000103', 'seated-cable-row', 3, 3, 10, 90),
    ('7e000000-0000-4000-8000-000000000103', 'lateral-raise', 4, 3, 12, 60),
    ('7e000000-0000-4000-8000-000000000103', 'mountain-climber', 5, 3, 20, 45),

    ('7e000000-0000-4000-8000-000000000201', 'dumbbell-bench-press', 1, 3, 8, 120),
    ('7e000000-0000-4000-8000-000000000201', 'one-arm-dumbbell-row', 2, 3, 10, 90),
    ('7e000000-0000-4000-8000-000000000201', 'dumbbell-shoulder-press', 3, 3, 10, 90),
    ('7e000000-0000-4000-8000-000000000201', 'dumbbell-curl', 4, 3, 12, 60),
    ('7e000000-0000-4000-8000-000000000201', 'cable-pushdown', 5, 3, 12, 60),

    ('7e000000-0000-4000-8000-000000000202', 'barbell-back-squat', 1, 3, 8, 120),
    ('7e000000-0000-4000-8000-000000000202', 'romanian-deadlift', 2, 3, 10, 120),
    ('7e000000-0000-4000-8000-000000000202', 'leg-press', 3, 3, 12, 90),
    ('7e000000-0000-4000-8000-000000000202', 'calf-raise', 4, 3, 15, 60),

    ('7e000000-0000-4000-8000-000000000203', 'incline-dumbbell-press', 1, 3, 10, 90),
    ('7e000000-0000-4000-8000-000000000203', 'lat-pulldown', 2, 3, 10, 90),
    ('7e000000-0000-4000-8000-000000000203', 'lateral-raise', 3, 3, 12, 60),
    ('7e000000-0000-4000-8000-000000000203', 'hammer-curl', 4, 3, 12, 60),
    ('7e000000-0000-4000-8000-000000000203', 'overhead-dumbbell-extension', 5, 3, 12, 60),

    ('7e000000-0000-4000-8000-000000000204', 'goblet-squat', 1, 3, 10, 90),
    ('7e000000-0000-4000-8000-000000000204', 'dumbbell-lunge', 2, 3, 10, 90),
    ('7e000000-0000-4000-8000-000000000204', 'lying-leg-curl', 3, 3, 12, 60),
    ('7e000000-0000-4000-8000-000000000204', 'glute-bridge', 4, 3, 12, 60),
    ('7e000000-0000-4000-8000-000000000204', 'dead-bug', 5, 3, 10, 45)
) AS v(day_id, code, order_no, sets, reps, rest);
