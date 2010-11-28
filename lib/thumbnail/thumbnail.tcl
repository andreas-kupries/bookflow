## -*- tcl -*-
# ### ### ### ######### ######### #########

# Background task. Continuous.
# Creating and invalidating thumbnails.
# A producer in terms of "doc/interaction_pci.txt"
#
# Generated thumbnails are cached in the directory ".bookflow/thumb"
# of the project directory.

# Limits itself to no more than four actual threads in flight,
# i.e. performing image scaling. The scaling tasks do not exit on
# completion, but wait for more operations to perform. Communication
# and coordination is done through the scoreboard. As usual.

# ### ### ### ######### ######### #########
## Requisites

package require debug
package require blog
package require task
package require scoreboard

namespace eval ::bookflow::thumbnail {}

# ### ### ### ######### ######### #########
## Tracing

#debug off    bookflow/thumbnail
debug on     bookflow/thumbnail

# ### ### ### ######### ######### #########
## API & Implementation

proc ::bookflow::thumbnail {} {
    Debug.bookflow/thumbnail {Bookflow::Thumbnail Watch}

    scoreboard take {AT *} [namespace code thumbnail::BEGIN]

    Debug.bookflow/thumbnail {/}
}

proc ::bookflow::thumbnail::BEGIN {tuple} {
    # tuple = (AT project)
    # Put it back for the use of others.
    scoreboard put $tuple

    Debug.bookflow/thumbnail {Bookflow::Thumbnail BEGIN <$tuple>}

    lassign $tuple _ project

    # Monitor for thumbnail invalidation
    # doc/interaction_pci.txt (1)
    scoreboard take {!THUMBNAIL *} [namespace code [list INVALIDATE $project]]

    # Launch the tasks doing the actual resizing.
    variable max
    for {set i 0} {$i < $max} {incr i} {
	task launch [list ::apply {{} {
	    package require bookflow::thumbnail
	    bookflow::thumbnail::SCALER
	}}]
    }

    # Monitor for thumbnail creation requests.
    # doc/interaction_pci.txt (2)
    scoreboard bind missing {THUMBNAIL *} [namespace code [list MAKE $project]]

    Debug.bookflow/thumbnail {Bookflow::Thumbnail BEGIN/}
    return
}

# ### ### ### ######### ######### #########
## Internals. Helper encapsulation directory structure.

proc ::bookflow::thumbnail::ThumbFullPath {project path} {
    return $project/[ThumbPath $path]
}

proc ::bookflow::thumbnail::ThumbPath {path} {
    return .bookflow/thumb/[file rootname $path].png
}

# ### ### ### ######### ######### #########
## Internals. Thumbnail invalidation. See doc/interaction_pci.txt (1).

proc ::bookflow::thumbnail::INVALIDATE {project tuple} {
    # tuple = (!THUMBNAIL path)
    Debug.bookflow/thumbnail {Bookflow::Thumbnail INVALIDATE}

    lassign $tuple _ path
    scoreboard takeall [list THUMBNAIL $path *] [namespace code [list RETRACT $project $path]]

    Debug.bookflow/thumbnail {Bookflow::Thumbnail INVALIDATE/}
    return
}

proc ::bookflow::thumbnail::RETRACT {project path tuples} {
    Debug.bookflow/thumbnail {Bookflow::Thumbnail RETRACT}

    file delete [ThumbFullPath $project $path]

    # Look for more invalidation requests
    scoreboard take {!THUMBNAIL *} [namespace code [list INVALIDATE $project]]

    Debug.bookflow/thumbnail {Bookflow::Thumbnail RETRACT/}
    return
}

# ### ### ### ######### ######### #########
## Internals. Thumbnail creation. See doc/interaction_pci.txt (2).

proc ::bookflow::thumbnail::MAKE {project pattern} {
    # pattern = (THUMBNAIL path *)
    Debug.bookflow/thumbnail {Bookflow::Thumbnail MAKE}

    lassign $pattern _ path

    set thumbfull [ThumbFullPath $project $path]
    set thumb     [ThumbPath $path]

    if {[file exists $thumbfull]} {
	# Thumbnail already exists in the filesystem cache, simply
	# make it available.

	scoreboard put [list THUMBNAIL $path $thumb]
    } else {
	# Thumbnail not known. Put in a request for the scaling tasks
	# to generate it. This will also put the proper result into
	# the scoreboard on completion.

	scoreboard put [list SCALE $project/$path 160 $thumbfull \
			    [list THUMBNAIL $path $thumb]]
    }

    Debug.bookflow/thumbnail {Bookflow::Thumbnail MAKE/}
    return
}

# ### ### ### ######### ######### #########
## Internals. Implementation of the resizing tasks.

proc ::bookflow::thumbnail::SCALER {} {
    Debug.bookflow/thumbnail {Bookflow::Thumbnail SCALER}

    # TODO :: Have debug work like log and reconfigure itself within a task.
    package require debug
    debug on     bookflow/thumbnail

    # Requisites for the task
    package require bookflow::thumbnail
    package require scoreboard
    package require crimp ; wm withdraw .
    package require img::png
    package require img::jpeg

    # Start waiting for requests.
    scoreboard take {SCALE *} [namespace code SCALE]

    Debug.bookflow/thumbnail {Bookflow::Thumbnail SCALER/}
    return
}

proc ::bookflow::thumbnail::SCALE {tuple} {
    # tuple = (SCALE path size dstpath result)
    # result = (THUMBNAIL path dstpath)
    Debug.bookflow/thumbnail {Bookflow::Thumbnail SCALE}

    # Decode request
    lassign $tuple _ path size dst result

    # Perform the scaling to requested size, reading jpeg, writing
    # png, using crimp internally.
    set photo [image create photo -file $path]

    set h [image height $photo]
    set w [image width  $photo]
    if {$w > $h} {
	# Landscape.
	set h [expr {int($h*$size/$w)}]
	set w $size
    } else {
	# Portrait.
	set w [expr {int($w*$size/$h)}]
	set h $size
    }

    crimp write 2tk $photo [crimp resize [crimp read tk $photo] $w $h]
    file mkdir [file dirname $dst]
    $photo write $dst -format png

    # Push result
    scoreboard put $result

    # Wait for more requests.
    scoreboard take {SCALE *} [namespace code SCALE]

    Debug.bookflow/thumbnail {Bookflow::Thumbnail SCALE/}
    return
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::bookflow::thumbnail {
    # Number of parallel scaling tasks.
    variable max 4
}

# ### ### ### ######### ######### #########
## Ready

package provide bookflow::thumbnail 0.1
return
