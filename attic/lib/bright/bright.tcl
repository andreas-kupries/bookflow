## -*- tcl -*-
# ### ### ### ######### ######### #########

# Background task. Continuous.
# Calculating the basic statistica values for page images.

# Called 'brightness' for historical reasons. That was the only value
# computed here at first (mean).

# A producer in terms of "doc/interaction_pci.txt"
# A consumer as well, of page greyscale images.
#
# Calculated statistical values are cached in the project database.

# Limits itself to no more than four actual threads in flight,
# i.e. computing image statistics. The computing tasks do not exit on
# completion, but wait for more operations to perform. Communication
# and coordination is done through the scoreboard. As usual.

# ### ### ### ######### ######### #########
## Requisites

package require debug
package require blog
package require task
package require scoreboard
package require bookflow::project

namespace eval ::bookflow::bright {}

# ### ### ### ######### ######### #########
## Tracing

debug off    bookflow/bright
#debug on     bookflow/bright

# ### ### ### ######### ######### #########
## API & Implementation

proc ::bookflow::bright {} {
    Debug.bookflow/bright {Bookflow::Bright Watch}

    scoreboard wpeek {AT *} [namespace code bright::BEGIN]

    Debug.bookflow/bright {/}
    return
}

proc ::bookflow::bright::BEGIN {tuple} {
    # tuple = (AT project)

    Debug.bookflow/bright {Bookflow::Bright BEGIN <$tuple>}

    lassign $tuple _ project

    ::bookflow::project::ok [namespace code [list INIT $project]]

    Debug.bookflow/bright {Bookflow::Bright BEGIN/}
    return
}

proc ::bookflow::bright::INIT {project} {
    Debug.bookflow/bright {Bookflow::Bright INIT}

    # Monitor for invalidation of statistics
    # doc/interaction_pci.txt (1)
    scoreboard take {!STATISTICS *} [namespace code INVALIDATE]

    # Launch the tasks doing the actual resizing.
    variable max
    for {set i 0} {$i < $max} {incr i} {
	task launch [list ::apply {{project} {
	    package require bookflow::bright
	    bookflow::bright::STATISTICS $project
	}} $project]
    }

    # Monitor for bright creation requests.
    # doc/interaction_pci.txt (2)
    scoreboard bind missing {STATISTICS *} [namespace code MAKE]

    Debug.bookflow/bright {Bookflow::Bright INIT/}
    return
}

# ### ### ### ######### ######### #########
## Internals. Bright invalidation. See doc/interaction_pci.txt (1).

proc ::bookflow::bright::INVALIDATE {tuple} {
    # tuple = (!STATISTICS path)
    lassign $tuple _ path

    Debug.bookflow/bright {Bookflow::Bright INVALIDATE $path}

    scoreboard takeall [list STATISTICS $path *] [namespace code [list RETRACT $path]]

    Debug.bookflow/bright {Bookflow::Bright INVALIDATE/}
    return
}

proc ::bookflow::bright::RETRACT {path tuples} {
    Debug.bookflow/bright {Bookflow::Bright RETRACT $path}

    ::bookflow::project statistics unset $path

    # Look for more invalidation requests
    scoreboard take {!STATISTICS *} [namespace code INVALIDATE]

    Debug.bookflow/bright {Bookflow::Bright RETRACT/}
    return
}

# ### ### ### ######### ######### #########
## Internals. Bright creation. See doc/interaction_pci.txt (2).

proc ::bookflow::bright::MAKE {pattern} {
    # pattern = (STATISTICS path *)
    Debug.bookflow/bright {Bookflow::Bright MAKE <$pattern>}

    lassign $pattern _ path

    set statistics [::bookflow::project statistics get $path]

    if {$statistics ne {}} {
	# The requested values already existed in the project database,
	# simply make them available.

	# TODO :: Have the verify task-to-be load existing brightness
	# TODO :: information to shortcircuit even this fast bailout.
	# TODO :: Note however that we will then need some way to
	# TODO :: prevent the insertion of duplicate or similar tuples.

	RESULT $path $statistics
    } else {
	# Statistics are not known. Put in a request for the computing
	# tasks to generate them. This will also put the proper result
	# into the scoreboard on completion.

	scoreboard put [list STATSQ $path]
    }

    Debug.bookflow/bright {Bookflow::Bright MAKE/}
    return
}

proc ::bookflow::bright::RESULT {path statistics} {
    scoreboard put [list STATISTICS $path $statistics]
    return
}

# ### ### ### ######### ######### #########
## Internals. Implementation of the calculation tasks.

proc ::bookflow::bright::STATISTICS {project} {
    package require debug
    Debug.bookflow/bright {Bookflow::Bright STATISTICS}

    # Requisites for the task
    package require bookflow::bright
    package require bookflow::project
    package require scoreboard
    package require crimp ; wm withdraw .
    package require fileutil

    # Start waiting for requests.
    ::bookflow::project::ok [namespace code [list READY $project]]

    Debug.bookflow/bright {Bookflow::Bright STATISTICS/}
    return
}

proc ::bookflow::bright::READY {project} {
    # Wait for more requests.
    scoreboard take {STATSQ *} [namespace code [list STAT $project]]
    return
}

proc ::bookflow::bright::STAT {project tuple} {
    # tuple = (STATSQ path)

    # Decode request
    lassign $tuple _ path
    Debug.bookflow/bright {Bookflow::Bright STAT $path}

    # Get the greyscale form of the image
    scoreboard take [list GREYSCALE $path *] [namespace code [list MEAN $project]]

    Debug.bookflow/bright {Bookflow::Bright STAT/}
    return
}

proc ::bookflow::bright::MEAN {project tuple} {
    # tuple = (GREYSCALE path grey-path)

    lassign $tuple _ path grey
    Debug.bookflow/bright {Bookflow::Bright MEAN $path |$grey}

    set data  [fileutil::cat -translation binary $project/$grey]
    Debug.bookflow/bright {  read ok       $path}

    set image [crimp read pgm $data]
    Debug.bookflow/bright {  pgm read ok   $path}

    set stats [crimp statistics basic $image]
    Debug.bookflow/bright {  statistics ok $path}

    array set s [dict get $stats channel luma]
    Debug.bookflow/bright {  statistics ok $path}

    set statistics [list $s(min) $s(max) $s(mean) $s(middle) $s(median) $s(stddev) $s(variance) $s(hf)]

    # Save/Cache result in the project.
    ::bookflow::project statistics set $path {*}$statistics
    Debug.bookflow/bright {  db ok         $path}

    # Push result
    RESULT $path $statistics

    # Wait for more requests.
    READY $project

    Debug.bookflow/bright {Bookflow::Bright MEAN $path = $statistics/}
    return
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::bookflow::bright {
    # Number of parallel calculation tasks.
    variable max 4
}

# ### ### ### ######### ######### #########
## Ready

package provide bookflow::bright 0.1
return
