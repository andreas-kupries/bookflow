## -*- tcl -*-
# ### ### ### ######### ######### #########

# Background task. Continuous.
# Calculating brightness of page images.
# A producer in terms of "doc/interaction_pci.txt"
# A consumer as well, of page greyscale images.
#
# Calculated brightness values are cached in the project database.

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

    scoreboard take {AT *} [namespace code bright::BEGIN]

    Debug.bookflow/bright {/}
    return
}

proc ::bookflow::bright::BEGIN {tuple} {
    # tuple = (AT project)
    # Put it back for the use of others.
    scoreboard put $tuple

    Debug.bookflow/bright {Bookflow::Bright BEGIN <$tuple>}

    lassign $tuple _ project

    ::bookflow::project::ok [namespace code [list INIT $project]]

    Debug.bookflow/bright {Bookflow::Bright BEGIN/}
    return
}

proc ::bookflow::bright::INIT {project} {
    Debug.bookflow/bright {Bookflow::Bright INIT}

    # Monitor for brightness value invalidation
    # doc/interaction_pci.txt (1)
    scoreboard take {!BRIGHTNESS *} [namespace code INVALIDATE]

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
    scoreboard bind missing {BRIGHTNESS *} [namespace code MAKE]

    Debug.bookflow/bright {Bookflow::Bright INIT/}
    return
}

# ### ### ### ######### ######### #########
## Internals. Bright invalidation. See doc/interaction_pci.txt (1).

proc ::bookflow::bright::INVALIDATE {tuple} {
    # tuple = (!BRIGHTNESS path)
    lassign $tuple _ path

    Debug.bookflow/bright {Bookflow::Bright INVALIDATE $path}

    scoreboard takeall [list BRIGHTNESS $path *] [namespace code [list RETRACT $path]]

    Debug.bookflow/bright {Bookflow::Bright INVALIDATE/}
    return
}

proc ::bookflow::bright::RETRACT {path tuples} {
    Debug.bookflow/bright {Bookflow::Bright RETRACT $path}

    ::bookflow::project brightness unset $path

    # Look for more invalidation requests
    scoreboard take {!BRIGHTNESS *} [namespace code INVALIDATE]

    Debug.bookflow/bright {Bookflow::Bright RETRACT/}
    return
}

# ### ### ### ######### ######### #########
## Internals. Bright creation. See doc/interaction_pci.txt (2).

proc ::bookflow::bright::MAKE {pattern} {
    # pattern = (BRIGHTNESS path *)
    Debug.bookflow/bright {Bookflow::Bright MAKE <$pattern>}

    lassign $pattern _ path

    set brightness [::bookflow::project brightness get $path]

    if {$brightness ne {}} {
	# The requested value already existed in the project database,
	# simply make it available.

	# TODO :: Have the verify task-to-be load existing brightness
	# TODO :: information to shortcircuit even this fast bailout.
	# TODO :: Note however that we will then need some way to
	# TODO :: prevent the insertion of duplicate or similar tuples.

	RESULT $path $brightness
    } else {
	# Brightness is not known. Put in a request for the computing
	# tasks to generate it. This will also put the proper result
	# into the scoreboard on completion.

	scoreboard put [list BRIGHT? $path]
    }

    Debug.bookflow/bright {Bookflow::Bright MAKE/}
    return
}

proc ::bookflow::bright::RESULT {path brightness} {
    scoreboard put [list BRIGHTNESS $path $brightness]
    return
}

# ### ### ### ######### ######### #########
## Internals. Implementation of the calculation tasks.

proc ::bookflow::bright::STATISTICS {project} {
    Debug.bookflow/bright {Bookflow::Bright STATISTICS}

    # TODO :: Have debug work like log and reconfigure itself within a task.
    package require debug
    #debug on     bookflow/bright

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
    scoreboard take {BRIGHT? *} [namespace code [list STAT $project]]
    return
}

proc ::bookflow::bright::STAT {project tuple} {
    # tuple = (BRIGHT? path)

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
    set brightness [dict get $stats channel luma mean]
    Debug.bookflow/bright {  brightness ok $path}

    # Save/Cache result in the project.
    ::bookflow::project brightness set $path $brightness
    Debug.bookflow/bright {  db ok         $path}

    # Push result
    RESULT $path $brightness

    # Wait for more requests.
    READY $project

    Debug.bookflow/bright {Bookflow::Bright MEAN $path = $brightness/}
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
