-- Create books table
CREATE TABLE IF NOT EXISTS books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Index for lookup books by owner
CREATE INDEX idx_books_owner_id ON books (owner_id);

-- Index for paginated listing sorted by newest first
CREATE INDEX idx_books_created_at ON books (created_at DESC) WHERE deleted_at IS NULL;

-- GIN index for full-text search
CREATE INDEX idx_books_full_text ON books USING GIN (to_tsvector('english', title || ' ' || content));

-- Apply trigger to books table
CREATE TRIGGER update_books_updated_at
    BEFORE UPDATE ON books
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
