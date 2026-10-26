CREATE TABLE system_probe (
    id INTEGER PRIMARY KEY,
    message VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO system_probe (id, message)
VALUES (1, 'VieGym database connected');
