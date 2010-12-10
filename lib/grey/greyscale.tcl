## -*- tcl -*-
# ### ### ### ######### ######### #########

# Background task. Continuous.
# Creating and invalidating greyscales of page images.
# A producer in terms of "doc/interaction_pci.txt"
#
# Generated greyscales are cached in the directory ".bookflow/grey" of
# the project directory.

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

namespace eval ::bookflow::greyscale {}

# ### ### ### ######### ######### #########
## Tracing

debug off    bookflow/greyscale
#debug on     bookflow/greyscale

# ### ### ### ######### ######### #########
## API & Implementation

proc ::bookflow::greyscale {} {
    Debug.bookflow/greyscale {Bookflow::Greyscale Watch}

    scoreboard wpeek {AT *} [namespace code greyscale::BEGIN]

    Debug.bookflow/greyscale {/}
    return
}

proc ::bookflow::greyscale::BEGIN {tuple} {
    # tuple = (AT project)

    Debug.bookflow/greyscale {Bookflow::Greyscale BEGIN <$tuple>}

    lassign $tuple _ project

    # Monitor for greyscale invalidation
    # doc/interaction_pci.txt (1)
    scoreboard take {!GREYSCALE *} [namespace code [list INVALIDATE $project]]

    # Launch the tasks doing the actual conversion.
    variable max
    for {set i 0} {$i < $max} {incr i} {
	task launch [list ::apply {{} {
	    package require bookflow::greyscale
	    bookflow::greyscale::CONVERT
	}}]
    }

    # Monitor for greyscale creation requests.
    # doc/interaction_pci.txt (2)
    scoreboard bind missing {GREYSCALE *} [namespace code [list MAKE $project]]

    Debug.bookflow/greyscale {Bookflow::Greyscale BEGIN/}
    return
}

# ### ### ### ######### ######### #########
## Internals. Helper encapsulation directory structure.

proc ::bookflow::greyscale::GreyFullPath {project path} {
    return $project/[GreyPath $path]
}

proc ::bookflow::greyscale::GreyPath {path} {
    return .bookflow/grey/[file rootname $path].pgm
}

# ### ### ### ######### ######### #########
## Internals. Greyscale invalidation. See doc/interaction_pci.txt (1).

proc ::bookflow::greyscale::INVALIDATE {project tuple} {
    # tuple = (!GREYSCALE path)
    lassign $tuple _ path

    Debug.bookflow/greyscale {Bookflow::Greyscale INVALIDATE $path}

    scoreboard takeall [list GREYSCALE $path *] [namespace code [list RETRACT $project $path]]

    Debug.bookflow/greyscale {Bookflow::Greyscale INVALIDATE/}
    return
}

proc ::bookflow::greyscale::RETRACT {project path tuples} {
    Debug.bookflow/greyscale {Bookflow::Greyscale RETRACT $path}

    file delete [GreyFullPath $project $path]

    # Look for more invalidation requests
    scoreboard take {!GREYSCALE *} [namespace code [list INVALIDATE $project]]

    Debug.bookflow/greyscale {Bookflow::Greyscale RETRACT/}
    return
}

# ### ### ### ######### ######### #########
## Internals. Greyscale creation. See doc/interaction_pci.txt (2).

proc ::bookflow::greyscale::MAKE {project pattern} {
    # pattern = (GREYSCALE path *)

    lassign $pattern _ path
    Debug.bookflow/greyscale {Bookflow::Greyscale MAKE $path}

    set greyfull [GreyFullPath $project $path]
    set grey     [GreyPath $path]

    if {[file exists $greyfull]} {
	# Greyscale already exists in the filesystem cache, simply
	# make it available.

	scoreboard put [list GREYSCALE $path $grey]
    } else {
	# Greyscale not known. Put in a request for the converter
	# tasks to generate it. This will also put the proper result
	# into the scoreboard on completion.

	scoreboard put [list GREYCONVERT $project/$path $greyfull \
			    [list GREYSCALE $path $grey]]
    }

    Debug.bookflow/greyscale {Bookflow::Greyscale MAKE/}
    return
}

# ### ### ### ######### ######### #########
## Internals. Implementation of the resizing tasks.

proc ::bookflow::greyscale::CONVERT {} {
    package require debug
    Debug.bookflow/greyscale {Bookflow::Greyscale CONVERT}

    # Requisites for the task
    package require bookflow::greyscale
    package require scoreboard
    package require crimp ; wm withdraw .
    package require img::jpeg

    # Start waiting for requests.
    READY

    Debug.bookflow/greyscale {Bookflow::Greyscale CONVERT/}
    return
}

proc ::bookflow::greyscale::READY {} {
    # Wait for more requests.
    scoreboard take {GREYCONVERT *} [namespace code GCONV]
    return
}

proc ::bookflow::greyscale::GCONV {tuple} {
    # tuple = (GREYCONVERT path dstpath result)
    # result = (GREYSCALE path dstpath)

    # Decode request
    lassign $tuple _ path dst result
    Debug.bookflow/greyscale {Bookflow::Greyscale GCONV $path $dst}

    # Perform the conversion, writing pgm, using crimp internally.
    file mkdir [file dirname $dst]

    set photo [image create photo -file $path]
    crimp write 2file pgm-raw $dst [crimp convert 2grey8 [crimp read tk $photo]]
    image delete $photo

    # Push result
    scoreboard put $result

    # Wait for more requests.
    READY

    Debug.bookflow/greyscale {Bookflow::Greyscale GCONV $path = $dst /}
    return
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::bookflow::greyscale {
    # Number of parallel conversion tasks.
    variable max 4
}

# ### ### ### ######### ######### #########
## Ready

package provide bookflow::greyscale 0.1
return
