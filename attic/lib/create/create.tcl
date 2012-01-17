## -*- tcl -*-
# ### ### ### ######### ######### #########

# Background task.
# Waiting for requests to create an initial project database.
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
    package require debug
    Debug.bookflow/create {Bookflow::Create TASK}

    # Requisites for the task
    package require scoreboard
    package require bookflow::create
    package require bookflow::project ; # client

    scoreboard wpeek {AT *} [namespace code BEGIN]

    Debug.bookflow/create {Bookflow::Create TASK/}
    return
}

proc ::bookflow::create::BEGIN {tuple} {
    # tuple = (AT project)
    variable defaultfile

    Debug.bookflow/create {Bookflow::Create BEGIN <$tuple>}

    # Get the payload
    lassign $tuple _ projectdir

    # Declare database presence, triggers creation.
    Log.bookflow {% Project database $defaultfile}
    scoreboard put    [list DATABASE $defaultfile]

    # At this point the server thread will complete initialization and
    # provide access to the database. We wait until it has done so:

    ::bookflow::project::ok [namespace code [list WaitForServerStart $projectdir]]

    Debug.bookflow/create {Bookflow::Create BEGIN/}
    return
}

proc ::bookflow::create::WaitForServerStart {project} {
    Debug.bookflow/create {Bookflow::Create WaitForServerStart}

    # Fill the database using the image files found by the scanner.
    scoreboard takeall {FILE*} [namespace code [list FILES $project]]

    Debug.bookflow/create {Bookflow::Create WaitForServerStart/}
    return
}

proc ::bookflow::create::FILES {project tuples} {
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
	set serial [::bookflow::project book extend @SCRATCH $jpeg \
			[file mtime $project/$jpeg]]

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
