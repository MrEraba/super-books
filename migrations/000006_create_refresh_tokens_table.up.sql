-- Create refresh_tokens table
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for finding all sessions for a user (enables logout all)
CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens (user_id);

-- Index for periodic cleanup of expired tokens
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens (expires_at);
