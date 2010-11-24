## -*- tcl -*-
# ### ### ### ######### ######### #########

# Scoreboard, a singleton in-memory database used by the concurrent
# tasks and the main control to coordinate and communicate with each
# other. Actually a tuple-space with a bit of dressing disguising it.

# ### ### ### ######### ######### #########
##

# The code here checks wether the package is running in the main
# thread or a task thread, and loads the associated implementation.

namespace eval ::scoreboard {}

::apply {{here} {
    if {![info exists ::task::type]} {
	source [file join $here sb_server.tcl]
    } else {
	switch -exact -- $::task::type {
	    thread {
	source [file join $here sb_client.tcl]
	    }
	    default {
		return -code error "Unable to handle ${::task::type}-based tasks"
	    }
	}
    }
    return
}} [file dirname [file normalize [info script]]]

# ### ### ### ######### ######### #########
## Ready

package provide scoreboard 0.1
