## -*- tcl -*-
# ### ### ### ######### ######### #########

# Error display. Watches the scoreboard for error messages and posts
# them as tk_message. Pseudo-task using events, i.e. CPS.

# ### ### ### ######### ######### #########
## Requisites

package require debug
package require scoreboard

namespace eval ::bookflow::error {}

# ### ### ### ######### ######### #########
## Tracing

#debug off    bookflow/error
debug on     bookflow/error

# ### ### ### ######### ######### #########
## API & Implementation

proc ::bookflow::error {} {
    Debug.bookflow/error {Bookflow::Error Watch}
    scoreboard take {PROJECT ERROR *} [namespace code error::Post]
    Debug.bookflow/error {/}
    return
}

# ### ### ### ######### ######### #########
## Internals

proc ::bookflow::error::Post {tuple} {
    tk_messageBox -type ok -icon error -parent . -title Error \
	-message [lindex $tuple 2]

    # Return to watching the scoreboard, there may be more messages.
    after idle ::bookflow::error
    return
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::bookflow {
    namespace export error
    namespace ensemble create
}

# ### ### ### ######### ######### #########
## Ready

package provide bookflow::error 0.1
