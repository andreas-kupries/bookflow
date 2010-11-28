## -*- tcl -*-
# ### ### ### ######### ######### #########

# Background task.
# Waiting for requests to create an initial database.
# Launches the task when the request is found.

# Creates the specified directory, looking for the BOOKFLOW database and
# JPEG images.

# ### ### ### ######### ######### #########
## Requisites

package require debug
package require blog
package require task

namespace eval ::bookflow::create {}

# ### ### ### ######### ######### #########
## Tracing

debug off    bookflow/create
#debug on     bookflow/create

# ### ### ### ######### ######### #########
## API & Implementation

proc ::bookflow::create {} {
    Debug.bookflow/create {Bookflow::Create Watch}

    scoreboard take {PROJECT CREATE} [namespace code create::RUN]

    Debug.bookflow/create {/}
}

# ### ### ### ######### ######### #########
## Internals

proc ::bookflow::create::RUN {tuple} {
    Debug.bookflow/create {Bookflow::Create RUN}

    Log.bookflow {Creating project database...}

    task launch [list ::apply {{} {
	package require bookflow::create
	bookflow::create::TASK
    }}]

    Debug.bookflow/create {Bookflow::Create RUN/}
    return
}

proc ::bookflow::create::TASK {} {
    Debug.bookflow/create {Bookflow::Create TASK}

    # TODO :: Have debug work like log and reconfigure itself within a task.
    package require debug
    #debug on     bookflow/create

    # Requisites for the task
    package require scoreboard
    package require bookflow::create
    package require bookflow::project ; # client

    scoreboard take {AT *} [namespace code BEGIN]

    Debug.bookflow/create {Bookflow::Create TASK/}
    return
}

proc ::bookflow::create::BEGIN {tuple} {
    variable defaultfile

    Debug.bookflow/create {Bookflow::Create BEGIN <$tuple>}

    # tuple = (AT project)
    # Put it back for the use of others.
    scoreboard put $tuple

    # Get the payload
    lassign $tuple _ projectdir

    # Create the empty database, and declare its presence
    set dbfile [file join [file normalize $projectdir] $defaultfile]

    Log.bookflow {% Project database $defaultfile}
    scoreboard put    [list DATABASE $defaultfile]

    # At this point the server thread will complete initialization and
    # provide access to the database. We wait until it has done so:

    ::bookflow::project::ok [namespace code WaitForServerStart]

    Debug.bookflow/create {Bookflow::Create BEGIN/}
    return
}

proc ::bookflow::create::WaitForServerStart {} {
    Debug.bookflow/create {Bookflow::Create WaitForServerStart}

    # Fill the database using the image files found by the scanner.
    scoreboard takeall {FILE*} [namespace code FILES]

    Debug.bookflow/create {Bookflow::Create WaitForServerStart/}
    return
}

proc ::bookflow::create::FILES {tuples} {
    Debug.bookflow/create {Bookflow::Create FILES}
    # tuples = list ((FILE *)...)

    # ... pull books out of the database and declare them ...
    # ... push files into the @scratch book, and declare
    # them as images, with book link ...

    foreach b [::bookflow::project books] {
	Debug.bookflow/create {                   BOOK $b}
	scoreboard put [list BOOK $b]
    }

    # Sorted by file name (like IMG_nnnn), this is the initial order.
    foreach def [lsort -dict -index 1 $tuples] {
	lassign $def _ jpeg
	set serial [::bookflow::project book extend @SCRATCH $jpeg]

	Debug.bookflow/create {                   IMAGE $jpeg $serial @SCRATCH}
	scoreboard put [list IMAGE $jpeg $serial @SCRATCH]
    }

    Debug.bookflow/create {Bookflow::Create FILES/}

    task::exit
    return
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::bookflow {
    namespace export create
    namespace ensemble create

    namespace eval create {
	variable defaultfile BOOKFLOW
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide bookflow::create 0.1
return
