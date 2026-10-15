CREATE TABLE IF NOT EXISTS notes (
    id         BIGSERIAL PRIMARY KEY,
    text       TEXT NOT NULL CHECK (char_length(text) BETWEEN 1 AND 500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
