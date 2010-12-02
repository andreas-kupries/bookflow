## -*- tcl -*-
# ### ### ### ######### ######### #########

# Background task.
# Waiting for requests to verify an exiting project database.
# Launches the task when the request is found.

# Compares found images with images in the database.

# ### ### ### ######### ######### #########
## Requisites

package require debug
package require blog
package require task

namespace eval ::bookflow::verify {}

# ### ### ### ######### ######### #########
## Tracing

debug off    bookflow/verify
#debug on     bookflow/verify

# ### ### ### ######### ######### #########
## API & Implementation

proc ::bookflow::verify {} {
    Debug.bookflow/verify {Bookflow::Verify Watch}

    scoreboard take {PROJECT VERIFY} [namespace code verify::RUN]

    Debug.bookflow/verify {/}
}

# ### ### ### ######### ######### #########
## Internals

proc ::bookflow::verify::RUN {tuple} {
    Debug.bookflow/verify {Bookflow::Verify RUN}

    Log.bookflow {Verifying project database...}

    task launch [list ::apply {{} {
	package require bookflow::verify
	bookflow::verify::TASK
    }}]

    Debug.bookflow/verify {Bookflow::Verify RUN/}
    return
}

proc ::bookflow::verify::TASK {} {
    package require debug
    Debug.bookflow/verify {Bookflow::Verify TASK}

    # Requisites for the task
    package require scoreboard
    package require struct::set
    package require bookflow::verify
    package require bookflow::project ; # client

    scoreboard take {AT *} [namespace code BEGIN]

    Debug.bookflow/verify {Bookflow::Verify TASK/}
    return
}

proc ::bookflow::verify::BEGIN {tuple} {
    variable defaultfile

    Debug.bookflow/verify {Bookflow::Verify BEGIN <$tuple>}

    # tuple = (AT project)
    # Put it back for the use of others.
    scoreboard put $tuple

    # Get the payload
    lassign $tuple _ projectdir

    # We wait until the server thread has completed initialization and
    # is providing access to the database.

    ::bookflow::project::ok [namespace code [list WaitForServerStart $projectdir]]

    Debug.bookflow/verify {Bookflow::Verify BEGIN/}
    return
}

proc ::bookflow::verify::WaitForServerStart {project} {
    Debug.bookflow/verify {Bookflow::Verify WaitForServerStart}

    # Fill the database using the image files found by the scanner.
    scoreboard takeall {FILE*} [namespace code [list FILES $project]]

    Debug.bookflow/verify {Bookflow::Verify WaitForServerStart/}
    return
}

proc ::bookflow::verify::FILES {project tuples} {
    Debug.bookflow/verify {Bookflow::Verify FILES}
    # tuples = list ((FILE *)...)

    # We now have the files found by the scanner...
    set scanned {}
    foreach def [lsort -dict -index 1 $tuples] {
	lassign $def _ jpeg
	lappend scanned $jpeg
    }

    # ... and the files known to the project.
    set known [::bookflow::project files]

    # Separate them into newly added, gone missing, and unchanged.
    lassign [struct::set intersect3 $scanned $known] \
	unchanged new del

    # New files are handled like the create task does, i.e. they are
    # added to the @SCRATCH book. NOTE that we are not adding them to
    # the scoreboard yet. This is done later, when all books have been
    # updated per the images.

    foreach jpeg $new {
	::bookflow::project book extend @SCRATCH $jpeg \
	    [file mtime $project/$jpeg]
    }

    # Removed files are moved from whereever they are into the @TRASH
    # book. Except those which are already there.

    foreach jpeg $new {
	set jbook [::bookflow::project book holding $jpeg]
	if {$jbook eq "@TRASH"} continue
	::bookflow::project book move @TRASH $jpeg
    }

    # Unchanged files ... Those in @TRASH have apparently been
    # restored as files, so these move to @SCRATCH. Even so, we cannot be sure that their derived data is ok,
    # forcing us to invalidate them.

    foreach jpeg $unchanged {
	set jbook [::bookflow::project book holding $jpeg]
	if {$jbook eq "@TRASH"} {
	    # FUTURE :: See if we can remember their old book
	    # FUTURE :: somewhere, and restore them to that.
	    ::bookflow::project book move @SCRATCH $jpeg
	    set modified 1
	} else {
	    # Ok, this file was present before, and is still present.
	    # Now let us check if it was modified since the project
	    # was used the last time. Because if so the derived data
	    # we have is useless and need to be regenerated.

	    set current  [file mtime $project/$jpeg]
	    set last     [::bookflow::project file mtime $jpeg]
	    set modified [expr {$current != $last}]
	}

	if {$modified} {
	    # Invalidation requests. We can do the statistics here
	    # because nobody is in a position to ask for it and we
	    # know how to do it. For the other things we rely on their
	    # producers for the invalidation.
	    ::bookflow::project statistics unset $jpeg
	    scoreboard put [list !THUMBNAIL  $jpeg]
	    scoreboard put [list !GREYSCALE  $jpeg]
	}
    }

    # Closing work ...

    # ... pull books out of the database and declare them ...

    foreach b [::bookflow::project books] {
	Debug.bookflow/verify {                   BOOK $b}
	scoreboard put [list BOOK $b]

	# ... pull files out and declare them ...
	foreach {jpeg serial} [::bookflow::project book files $b] {
	    Debug.bookflow/verify {                   IMAGE $jpeg $serial $b}
	    scoreboard put [list IMAGE $jpeg $serial $b]

	    # Pre-load any statistics information, shortcircuiting its
	    # producer.

	    set statistics [::bookflow::project statistics get $jpeg]
	    if {$statistics ne {}} {
		scoreboard put [list STATISTICS $jpeg $statistics]
	    }
	}
    }

    Debug.bookflow/verify {Bookflow::Verify FILES/}

    task::exit
    return
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::bookflow {
    namespace export verify
    namespace ensemble create

    namespace eval verify {
	variable defaultfile BOOKFLOW
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide bookflow::verify 0.1
return
