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

debug off    bookflow/thumbnail
#debug on     bookflow/thumbnail

# ### ### ### ######### ######### #########
## API & Implementation

proc ::bookflow::thumbnail {} {
    Debug.bookflow/thumbnail {Bookflow::Thumbnail}

    scoreboard take {AT *} [namespace code thumbnail::Initialize]

    Debug.bookflow/thumbnail {/}
    return
}

proc ::bookflow::thumbnail::request {path size} {
    return [list THUMBNAIL $path $size *]
}

# ### ### ### ######### ######### #########
## Internals. Process initialization

proc ::bookflow::thumbnail::Initialize {tuple} {
    # tuple = (AT project)
    # Put it back for the use of others.
    scoreboard put $tuple
    lassign $tuple _ project

    Debug.bookflow/thumbnail {Bookflow::Thumbnail Initialize <$project>}

    # Monitor for thumbnail invalidation
    WatchForInvalidation $project

    # Launch the tasks doing the actual resizing.
    variable max
    for {set i 0} {$i < $max} {incr i} {
	task launch [list ::apply {{project} {
	    package require bookflow::thumbnail
	    bookflow::thumbnail::ScalingTask $project
	}} $project]
    }

    # Monitor for thumbnail creation requests.
    WatchForMisses $project

    Debug.bookflow/thumbnail {Bookflow::Thumbnail Initialize/}
    return
}

# ### ### ### ######### ######### #########
## Internals. Invalidation processing. See doc/interaction_pci.txt (1).

proc ::bookflow::thumbnail::WatchForInvalidation {project} {
    # doc/interaction_pci.txt (1)
    Debug.bookflow/thumbnail {Bookflow::Thumbnail WatchForInvalidation}

    scoreboard take {!THUMBNAIL *} [namespace code [list Invalidate $project]]

    Debug.bookflow/thumbnail {Bookflow::Thumbnail WatchForInvalidation}
    return
}

proc ::bookflow::thumbnail::Invalidate {project tuple} {
    # tuple = (!THUMBNAIL path)
    Debug.bookflow/thumbnail {Bookflow::Thumbnail Invalidate}

    lassign $tuple _ path
    scoreboard takeall [list THUMBNAIL $path *] [namespace code [list Cleanup $project $path]]

    Debug.bookflow/thumbnail {Bookflow::Thumbnail Invalidate/}
    return
}

proc ::bookflow::thumbnail::Cleanup {project path tuples} {
    Debug.bookflow/thumbnail {Bookflow::Thumbnail Cleanup}

    file delete [ThumbFullPath $project $path]

    WatchForInvalidation $project

    Debug.bookflow/thumbnail {Bookflow::Thumbnail Cleanup/}
    return
}

# ### ### ### ######### ######### #########
## Internals. Creation request handling. See doc/interaction_pci.txt (2).

proc ::bookflow::thumbnail::WatchForMisses {project} {
    Debug.bookflow/thumbnail {Bookflow::Thumbnail WatchForMisses}

    # doc/interaction_pci.txt (2)
    scoreboard bind missing {THUMBNAIL *} [namespace code [list MakeImage $project]]

    Debug.bookflow/thumbnail {Bookflow::Thumbnail WatchForMisses}
    return
}

proc ::bookflow::thumbnail::MakeImage {project pattern} {
    # pattern = (THUMBNAIL path size *)
    Debug.bookflow/thumbnail {Bookflow::Thumbnail MakeImage}

    lassign $pattern _ path size

    set dst [Path $path $size]

    if {[file exists $project/$dst]} {
	# The requested image already exists in the filesystem cache,
	# simply make it available.

	Return $path $size $dst

	Debug.bookflow/thumbnail {Bookflow::Thumbnail MakeImage/}
	return
    }

    # The image is not known yet. Forward the request to the scaling
    # tasks to create the desired image.

    RequestCreation $path $size $dst

    Debug.bookflow/thumbnail {Bookflow::Thumbnail MakeImage/}
    return
}

proc ::bookflow::thumbnail::Return {path size dst} {
    scoreboard put [list THUMBNAIL $path $size $dst]
    return
}

# ### ### ### ######### ######### #########
## Internals. Background tasks handling the actual scaling.

proc ::bookflow::thumbnail::RequestCreation {path size dst} {
    scoreboard put [list SCALE $path $size $dst]
    return
}

proc ::bookflow::thumbnail::ScalingTask {project} {
    package require debug
    Debug.bookflow/thumbnail {Bookflow::Thumbnail ScalingTask}

    # Requisites for the task
    package require bookflow::thumbnail
    package require scoreboard
    package require crimp ; wm withdraw .
    package require img::png
    package require img::jpeg

    # Start waiting for requests.
    ReadyForRequests $project

    Debug.bookflow/thumbnail {Bookflow::Thumbnail ScalingTask/}
    return
}

proc ::bookflow::thumbnail::ReadyForRequests {project} {
    # Wait for more requests.
    scoreboard take {SCALE *} [namespace code [list ScaleImage $project]]
    return
}

proc ::bookflow::thumbnail::ScaleImage {project tuple} {
    # tuple = (SCALE path size dstpath)
    # result = (THUMBNAIL path dstpath)
    Debug.bookflow/thumbnail {Bookflow::Thumbnail ScaleImage}

    # Decode request
    lassign $tuple _ path size dst

    # Perform the scaling to requested size, reading jpeg, writing
    # png, using crimp internally.
    set photo [image create photo -file $project/$path]

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
    file mkdir [file dirname $project/$dst]
    $photo write $project/$dst -format png
    image delete $photo

    Return $path $size $dst

    ReadyForRequests $project

    Debug.bookflow/thumbnail {Bookflow::Thumbnail ScaleImage/}
    return
}

# ### ### ### ######### ######### #########
## Internals. Path handling.

proc ::bookflow::thumbnail::Path {path size} {
    return .bookflow/thumb$size/[file rootname $path].png
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
