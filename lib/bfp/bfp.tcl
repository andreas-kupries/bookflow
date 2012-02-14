## -*- tcl -*-
# # ## ### ##### ######## ############# #####################

# Access to Bookflow Project Files
# Internally: sqlite3 database.

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
#package require debug
#package require debug::snit
package require fileutil
package require snit
package require sqlite3

namespace eval ::bookflow::project {
    variable selfdir [file dirname [file normalize [info script]]]
}

# # ## ### ##### ######## ############# #####################
## Tracing

#debug prefix bookflow/project {[::debug::snit::call] }
#debug off    bookflow/project
#debug on     bookflow/project

# # ## ### ##### ######## ############# #####################
## API & Implementation

snit::type ::bookflow::project {
    # # ## ### ##### ######## ############# #####################

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

	set ok true
	foreach table $ourtables {
	    if {![Has $db $table]} {
		set ok false
		break
	    }
	}
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

    # # ## ### ##### ######## ############# #####################

    # List of expected database tables. Must match the schema.
    typevariable ourtables {
	global image spread orientation pagestatus
    }

    # Loaded from companion file.
    typevariable ourschema {}

    typemethod new {database project} {
	#Debug.bookflow/project { @ $database $project}

	# Create the database file at the specified location, and fill
	# it with the necessary tables.

	if {[$type isBookflow $database]} {
	    return -code error "Unable to overwrite existing bookflow project $database"
	}

	set db ${type}::DB
	sqlite3 $db $database

	$db transaction {
	    $db eval $ourschema
	    $db eval {
		INSERT INTO global VALUES ('path',:project)
	    }
	}
	$db close

	#Debug.bookflow/project {}
	#return [$type create %AUTO% $database]
	return
    }

    typeconstructor {
	::variable selfdir
	set ourschema [fileutil::cat $selfdir/bfp-schema.sql]
	return
    }

    # # ## ### ##### ######## ############# #####################

    method db {} { return $mydb }

    constructor {database} {
	#Debug.bookflow/project { @ $database $project}

	if {![$type isBookflow $database]} {
	    return -code error "Not a bookflow project: $database"
	}

	set mydb ${selfns}::DB
	sqlite3 $mydb $database

	set mydir [$mydb eval {
	    SELECT value FROM global WHERE key = 'path'
	}]

	#Debug.bookflow/project {}
	return
    }

    destructor {
	if {$mydb eq {}} return
        $mydb close 
	return
    }

    # # ## ### ##### ######## ############# #####################
    ## Public project methods

    method where {} {
	return $mydir
    }

    method add {images} {
	#Debug.bookflow/project {}

	$mydb transaction {
	    foreach image $images {
		$mydb eval {
		    INSERT INTO image VALUES (NULL,:image,1,1,1,0,0)
		    -- flags => used, page, even, !attention, east
		}
	    }
	}

	#Debug.bookflow/project {/}
	return
    }

    method indicator {image flags} {
	#Debug.bookflow/project {}
	dict with flags {}
	$mydb transaction {
	    $mydb eval {
		UPDATE image
		SET  used        = :used,
		     content     = :content,
		     even        = :even,
		     attention   = :attention,
		     orientation = :orientation
		WHERE  path = :image
	    }
	}
	#Debug.bookflow/project {/}
	return
    }

    method images-used {} {
	$mydb transaction {
	    set images [$mydb eval {
		SELECT path FROM image WHERE used = 1;
	    }]
	}
	return [lsort -dict $images]
    }

    method images-left {} {
	$mydb transaction {
	    set images [$mydb eval {
		SELECT path FROM image WHERE even = 1;
	    }]
	}
	return [lsort -dict $images]
    }

    method images-right {} {
	$mydb transaction {
	    set images [$mydb eval {
		SELECT path FROM image WHERE even = 0;
	    }]
	}
	return [lsort -dict $images]
    }

    method images-all {} {
	$mydb transaction {
	    set images [$mydb eval {
		SELECT path FROM image;
	    }]
	}
	return [lsort -dict $images]
    }

    method thumbnail? {image} {
	#Debug.bookflow/project {}
	return thumbnail/[file root $image]
    }

    method medium? {image} {
	#Debug.bookflow/project {}
	# XXX: Check that it is an image in the project?!
	return [image create photo -file [$self medium-path $image]]
    }

    method medium-path {image} {
	#Debug.bookflow/project {}
	file mkdir medium
	return medium/[file root [file tail $image]].ppm
    }

    method upright? {image} {
	#Debug.bookflow/project {}
	# XXX: Check that it is an image in the project?!
	return [image create photo -file [$self upright-path $image]]
    }

    method upright-path {image} {
	#Debug.bookflow/project {}
	file mkdir upright
	return upright/[file root [file tail $image]].ppm
    }

    method indicator? {image} {
	#Debug.bookflow/project {}

	$mydb transaction {
	    set data [$mydb eval {
		SELECT used, content, even, attention, orientation
		FROM image
		WHERE  path = :image
	    }]
	}

	lassign $data used content even attention orientation

	#Debug.bookflow/project {/}
	return [dict create \
		    used        $used \
		    content     $content \
		    even        $even \
		    attention   $attention \
		    orientation $orientation]
    }

    if 0 {method thumbnail {image thumbdata} {
	#Debug.bookflow/project {}

	$mydb transaction {
	    $mydb eval {
		INSERT INTO thumb
		VALUES ((SELECT iid FROM image
			 WHERE path = :image),:thumbdata)
	    }
	}

	#Debug.bookflow/project {/}
	return
    }

    method thumbnail? {image} {
	#Debug.bookflow/project {}

	$mydb transaction {
	    set data [$mydb eval {
		SELECT thumb FROM thumb
		WHERE iid IN (SELECT iid FROM image
			      WHERE path = :image)
	    }]
	}

	#Debug.bookflow/project {/}
	return $data
    }}

    ### Accessors and manipulators

    # # ## ### ##### ######## ############# #####################
    ##

    variable mydb  ; # Handle of the sqlite database. Object command.
    variable mydir ; # Absolute path to the project directory (holding the images).

    ##
    # # ## ### ##### ######## ############# #####################
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide bookflow::project 0.1
return
