-- Create book_tags join table (many-to-many between books and tags)
CREATE TABLE IF NOT EXISTS book_tags (
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (book_id, tag_id)
);

-- Index for reverse lookup: find all books for a given tag
CREATE INDEX idx_book_tags_tag_id ON book_tags (tag_id);
