## -*- tcl -*-
# ### ### ### ######### ######### #########

# Access to the bookflow project database from any part of the
# application.

# ### ### ### ######### ######### #########
## Requisites

package require debug
package require scoreboard

namespace eval ::bookflow::project {}

# ### ### ### ######### ######### #########
## Tracing

debug off    bookflow/project
#debug on     bookflow/project

# ### ### ### ######### ######### #########
## API & Implementation
## Wait for the server thread to complete initialization

proc ::bookflow::project::ok {cmd} {
    Debug.bookflow/project {OK <cmd>}

    # Wait for the appearance of (PROJECT SERVER *)
    scoreboard take {PROJECT SERVER *} [list ::apply {{cmd tuple} {
	# Put tuple back for others.
	scoreboard put $tuple

	# Make delegation command usable, i.e. tell it which thread to
	# send the commands to.
	lassign $tuple _ _ thread
	variable server $thread

	# Tell the caller that the database server thread is (now)
	# ready.
	uplevel #0 $cmd
    } ::bookflow::project} $cmd]

    Debug.bookflow/project {OK/}
    return
}

# ### ### ### ######### ######### #########
## API & Implementation
## Delegate all actions to the server thread.  This serializes
## concurrent access by different parts of the application.

proc ::bookflow::project {args} {
    variable project::server
    return [thread::send $server [info level 0]]
}

# ### ### ### ######### ######### #########

namespace eval ::bookflow::project {
    variable server
}

# ### ### ### ######### ######### #########
## Ready

package provide bookflow::project 0.1
return
