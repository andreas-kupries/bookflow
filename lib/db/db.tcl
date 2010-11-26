## -*- tcl -*-
# ### ### ### ######### ######### #########

# Access to a bookflow database, file identification, creation, etc.

# ### ### ### ######### ######### #########
## Requisites

package require debug
package require debug::snit
package require snit
package require sqlite3

namespace eval ::bookflow::db {}

# ### ### ### ######### ######### #########
## Tracing

#debug off    bookflow/db
debug prefix bookflow/db {[::debug::snit::call]}
debug on     bookflow/db

# ### ### ### ######### ######### #########
## API & Implementation

snit::type ::bookflow::db {
    # ### ### ### ######### ######### #########

    typemethod isBookflow {path} {
	if {![file exists $path]} { return 0 }
	if {![file isfile $path]} { return 0 }

	# FUTURE :: Extend fileutil::fileType
	# readable, sqlite database ?
	if {[catch {
	    set c [open $path r]
	    fconfigure $c -translation binary
	}]} { return 0 }
	set head [read $c 15]
	close $c
	if {$head ne {SQLite format 3}} { return 0 }

	# check for the bookflow tables
	set db ${type}::DB
	sqlite3 $db $path
	set ok [expr {[Has $db bookflow] &&
		      [Has $db book] &&
		      [Has $db image]}]
	$db close
	return $ok
    }

    proc Has {db table} {
	return [llength [$db eval {
	    SELECT name
	    FROM sqlite_master
	    WHERE type = 'table'
	    AND   name = $table
	    ;
	}]]
    }

    # ### ### ### ######### ######### #########

    typemethod new {path} {
	Debug.bookflow/db { @ $path}

	# Create the database file at the specified location, and fill
	# it with the necessary tables.

	set db ${type}::DB
	sqlite3 $db $path
	$db eval {
	    -- Global, per project information
	    CREATE TABLE bookflow (
	       dpi INTEGER NOT NULL -- dots per inch for the whole project.
	    );

	    -- A project is subdivided into one or more books.
	    -- Note that each project internally uses two standard
	    -- 'books'. These are the 'scratchpad' holding all
	    -- images not assigned to a user-created book, and the
	    -- 'trash' holding the data about images which are gone,
	    -- for their eventual resurrection.

	    CREATE TABLE book (
	       bid  INTEGER  NOT NULL  PRIMARY KEY  AUTOINCREMENT,
	       name TEXT     NOT NULL  UNIQUE

	       -- FUTURE : More book information, like author, isbn,
	       -- FUTURE : printing datum, etc. Possibly in a separate
	       -- FUTURE : table for meta data.
	    );

	    -- The @ character is illegal in user-specified book names,
	    -- ensuring that the standard books can never be in conflict
	    -- with the user's names.

	    INSERT INTO book VALUES (0,'@SCRATCH');
	    INSERT INTO book VALUES (1,'@TRASH');

	    -- All images, which always belong to a single book.
	    -- Images have an order imposed on them (see field 'ord'),
	    -- which is unique within a book.

	    CREATE TABLE image (
	       iid  INTEGER  NOT NULL  PRIMARY KEY  AUTOINCREMENT,
	       path TEXT     NOT NULL  UNIQUE,
	       bid  INTEGER  NOT NULL  REFERENCES book,
	       ord  INTEGER  NOT NULL,
	       UNIQUE (bid, ord)
	    );
	}
	$db close

	Debug.bookflow/db {}
	return [$type create %AUTO% $path]
    }

    # ### ### ### ######### ######### #########

    constructor {path} {
	Debug.bookflow/db { @ $path}

	set mydb ${selfns}::DB
	sqlite3 $mydb $path

	Debug.bookflow/db {}
	return
    }

    # ### ### ### ######### ######### #########

    method books {} {
	return [$mydb eval { SELECT name FROM book }]
    }

    method {book extend} {book file} {
	$mydb transaction {
	    # Locate the named book, and retrieve its id.
	    set bid [lindex [$mydb eval {
		SELECT bid FROM book WHERE name = $book
	    }] 0]

	    # Get the last (= highest) ordering number for images in this book.
	    set ord [lindex [$mydb eval {
		SELECT MAX (ord) FROM image WHERE bid = $bid
	    }] 0]

	    # The new images is added behind the last-highest images.
	    if {$ord eq {}} { set ord -1 }
	    incr ord

	    # And enter the image into the database.
	    $mydb eval {
		INSERT INTO image VALUES (NULL, $file, $bid, $ord)
	    }
	}

	return $ord
    }

    ### Accessors and manipulators

    # ### ### ### ######### ######### #########
    ##

    variable mydb ; # Handle of the sqlite database. Object command.

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide bookflow::db 0.1
