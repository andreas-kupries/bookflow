## -*- tcl -*-
# ### ### ### ######### ######### #########

# Access to a bookflow database, file identification, creation, etc.

# ### ### ### ######### ######### #########
## Requisites

package require debug
package require snit
package require sqlite3

namespace eval ::bookflow::db {}

# ### ### ### ######### ######### #########
## Tracing

#debug off    bookflow/db
debug prefix bookflow/db {[debug::snit::call]}
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
	    );

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

    ### Accessors and manipulators

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide bookflow::db 0.1
