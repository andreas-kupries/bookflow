-- Global information about the project.
-- A simple key/value store.
--
-- Known keys and their meaning:
--   'path' : Absolute path to the project directory.

CREATE TABLE global (
    key   TEXT NOT NULL PRIMARY KEY,
    value TEXT NOT NULL
);

-- Information about all images in the directory hierarchy associated
-- with the project.

CREATE TABLE image (
    -- Basic information: Row id, and path to the image file, relative
    -- to the project directory.

    iid   INTEGER  NOT NULL  PRIMARY KEY  AUTOINCREMENT,
    path  TEXT     NOT NULL  UNIQUE,

    -- Various classifications, stored as booleans.
    --
    -- used:      true for images which do belong to the project.
    --            false for images whioch don't
    -- content:   true for images which contain book content pages
    --            false for images of the book covers
    -- even:      true for even-numbered (*) images (right of book spine)
    --            false for odd-numbered images (left of book spine)
    -- attention: true for images to look closely at. Mostly because
    --            nearby images where special, like !used. May indicate
    --            duplicated pages or similar.
    --
    --          Note: even cover = back cover
    --                odd cover  = front cover

    used      INTEGER NOT NULL DEFAULT 0,
    content   INTEGER NOT NULL,
    even      INTEGER NOT NULL,
    attention INTEGER NOT NULL
);

-- CREATE TABLE thumb (
--    iid   INTEGER NOT NULL PRIMARY KEY REFERENCES image,
--    thumb CBLOB
-- );
