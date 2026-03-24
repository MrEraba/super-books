-- Create user_preferences join table (many-to-many between users and preferred tags)
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, tag_id)
);

-- Index for reverse lookup
CREATE INDEX idx_user_preferences_tag_id ON user_preferences (tag_id);
