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
    --          Note: even/left  cover = back cover
    --                odd /right cover = front cover

    -- orientation: which side of the image is the upper edge of the page.
    --              See table 'orientation' for the encoding
    --
    --		In my setup orientation can normally be derived from even,
    --		i.e. left/right:
    --
    --		even == left  => east
    --		odd  == right => west

    used        INTEGER NOT NULL DEFAULT 0,
    content     INTEGER NOT NULL,
    even        INTEGER NOT NULL,
    attention   INTEGER NOT NULL,
    orientation INTEGER NOT NULL REFERENCES orientation
);

-- Information about all double-pages, i.e. spreads in the
-- project. I.e which left and right images belong together, how they
-- are ordered, where pieces are missing or blank.

CREATE TABLE spread (

    -- Basics: Id of the double page aka page spread, and the ordinal
    -- specifying the ordering of spreads. Separating these two allows
    -- changes to the ordering without regard to future references to
    -- the table.

    pid   INTEGER  NOT NULL  PRIMARY KEY  AUTOINCREMENT,
    ord   INTEGER  NOT NULL  UNIQUE

    -- The information about the spread, i.e. the left and right
    -- images, and the page number of the spread (which is always
    -- even, and thus is also always the page number of the left
    -- image). Both image references can be NULL, indicating a missing
    -- or blank page. The flags are used to distinguish the two cases.

    left  INTEGER  REFERENCES image,
    right INTEGER  REFERENCES image,
    page  TEXT     UNIQUE,

    lstatus INTEGER NOT NULL REFERENCES pagestatus,
    rstatus INTEGER NOT NULL REFERENCES pagestatus
);

-- Helper table for self-description. Names/labels for the image
-- orientations. Fixed content. Note: The order of orientation is
-- following the path of the sun in a day.

CREATE TABLE orientation (
    id   INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT    NOT NULL UNIQUE
);

INSERT INTO orientation VALUES (0,'east');
INSERT INTO orientation VALUES (1,'south');
INSERT INTO orientation VALUES (2,'west');
INSERT INTO orientation VALUES (3,'north');

-- Helper table for self-description. Names/labels for the page stati in a spread.
-- Fixed content.

CREATE TABLE pagestatus (
    id   INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT    NOT NULL UNIQUE
);

INSERT INTO pagestatus VALUES (0,'ok');
INSERT INTO pagestatus VALUES (1,'blank');
INSERT INTO pagestatus VALUES (2,'missing');
