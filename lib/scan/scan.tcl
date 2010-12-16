## -*- tcl -*-
# ### ### ### ######### ######### #########

# Background task.
# Initial task.

# Scans the specified directory, looking for the BOOKFLOW database and
# JPEG images.

# ### ### ### ######### ######### #########
## Requisites

package require debug
package require task

namespace eval ::bookflow::scan {}

# ### ### ### ######### ######### #########
## Tracing

debug off    bookflow/scan
#debug on     bookflow/scan

# ### ### ### ######### ######### #########
## API & Implementation

proc ::bookflow::scan {projectdir} {
    Debug.bookflow/scan {Bookflow::Scan <$projectdir>}

    task launch [list ::apply {{projectdir} {
	package require bookflow::scan
	bookflow::scan::TASK $projectdir
	task::exit
    }} $projectdir]

    Debug.bookflow/scan {/}
    return
}

# ### ### ### ######### ######### #########
## Internals

proc ::bookflow::scan::TASK {projectdir} {
    package require debug

    # Requisites for the task
    package require blog
    package require jpeg
    package require fileutil
    package require scoreboard
    package require bookflow::db

    scoreboard put [list AT $projectdir]
    set dir [file normalize $projectdir]

    set hasimages  0
    set hasproject 0

    # Iteratation over the files in the project directory.
    # No traversal into subdirectories!
    # Uses 'file'-like commands to determine the type of
    # files (jpeg, bookflow database, other) for classification.

    foreach f [lsort -dict [glob -nocomplain -directory $dir *]] {
	Debug.bookflow/scan {  Processing $f}

	if {![file isfile $f]} {
	    Debug.bookflow/scan {  Directory, ignored}
	    continue
	}

	set fx [fileutil::stripPath $dir $f]

	if {[jpeg::isJPEG $f]} {
	    Debug.bookflow/scan {  Image}
	    set hasimages 1
	    Log.bookflow {* Image            $fx}
	    scoreboard put [list FILE $fx]

	} elseif {[bookflow::db isBookflow $f]} {
	    Debug.bookflow/scan {  Project database found}
	    set hasproject 1
	    Log.bookflow {% Project database $fx}
	    scoreboard put [list DATABASE $fx]

	} else {
	    Debug.bookflow/scan {  Ignored}
	}
    }

    # Scan is complete, summarize the result. This triggers other
    # tasks.

    if {$hasproject} {
	# We have a project. Might have images or not.  Signal that
	# this project needs verification, i.e. internal consistency
	# check, and checking against the set of external images
	# found.

	Debug.bookflow/scan {Bookflow::Scan -> Verify project}
	scoreboard put {PROJECT VERIFY}

    } elseif {$hasimages} {
	# While no project database is available, we have
	# images. Signal that we should create a fresh project
	# database from the images.

	Debug.bookflow/scan {Bookflow::Scan -> Create project}
	scoreboard put {PROJECT CREATE}
    } else {
	# Neither project, nor images were found. This is an abnormal
	# situation. Signal the main controller to report on this.

	Debug.bookflow/scan {Bookflow::Scan -> Nothing found}
	set msg "The chosen project directory $projectdir contains neither images to process, nor a bookflow database.\n\nNothing will be done."
	scoreboard put [list PROJECT ERROR $msg]
    }

    return
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::bookflow {
    namespace export scan
    namespace ensemble create
}

# ### ### ### ######### ######### #########
## Ready

package provide bookflow::scan 0.1
return
