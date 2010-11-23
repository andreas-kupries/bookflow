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

#debug off    bookflow/scan
debug on     bookflow/scan

# ### ### ### ######### ######### #########
## API & Implementation

proc ::bookflow::scan {projectdir} {
    Debug.bookflow/scan {Bookflow::Scan <$projectdir>}

    task launch [list ::apply {{projectdir} {

	package require debug
	debug on     bookflow/scan
	# TODO :: Have debug work like log and reconfigure itself within a task.

	package require blog
	package require jpeg
	package require fileutil
	# package require scoreboard
	# scoreboard put [list PROJECT $projectdir]

	set dir [file normalize $projectdir]

	set hasimages  0
	set hasproject 0

	foreach f [glob -nocomplain -directory $dir *] {

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
		# scoreboard put [list IMAGE $fx]
	    } elseif {$fx eq "BOOKFLOW"} {
		Debug.bookflow/scan {  Project database found}
		set hasproject 1
		Log.bookflow {% Project database $fx}
		# scoreboard put [list DATABASE $fx]
	    } else {
		Debug.bookflow/scan {  Ignored}
	    }
	}

	if {$hasproject} {
	    # Verify project against found images, then continue
	    # as normal.

	    Debug.bookflow/scan {Bookflow::Scan .Verify project}
	    # scoreboard put {SCAN VERIFY}
	} elseif {$hasimages} {
	    # Create project, then continue as normal.
	    Debug.bookflow/scan {Bookflow::Scan .Create project}
	    # scoreboard put {SCAN CREATE}
	} else {
	    # Neither project, nor images found. This is
	    # an abnormal situation. Report.

	    Debug.bookflow/scan {Bookflow::Scan !Nothing found}
	    # scoreboard put {SCAN EMPTY}
	}

	task::exit
    }} $projectdir]

    Debug.bookflow/scan {/}
    return
}

# ### ### ### ######### ######### #########
## Internals

proc ::bookflow::scan::TASK {projectdir} {
    Debug.bookflow/scan {Bookflow::Scan <$projectdir>}

    task launch ::bookflow::scan::TASK

    Debug.bookflow/scan {/}
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
