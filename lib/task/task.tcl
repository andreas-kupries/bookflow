## -*- tcl -*-
# ### ### ### ######### ######### #########

# Handling of (background) tasks running concurrently to the main
# system.  This implementation uses thread, via package Thread.
# Alternate implementations could use sub-processses, or coroutines
# (green threads).  The main difference between them all will be in
# the communication between main system and tasks, and between tasks,
# and setting up the per-task environment for this communication.

# ### ### ### ######### ######### #########
## Requisites

package require debug
package require Thread

namespace eval ::task {}

# ### ### ### ######### ######### #########
## Tracing

debug off    task
#debug on     task

# ### ### ### ######### ######### #########
## API & Implementation

proc ::task::launch {cmdprefix} {
    # cmdprefix = The task to run concurrently.

    Debug.task {Task <$cmdprefix>}

    # Create thread for task

    set id [thread::create]
    Debug.task {  Running in thread $id}

    # Set magic information for communication with the main
    # thread. The packages requiring special setup for proper
    # communication will look for and recognize the magic and
    # configure themselves accordingly.

    Debug.task {  Configure communication magic}

    thread::send $id [list ::apply {{main ap} {
	set ::auto_path $ap
	namespace eval ::task {}
	set ::task::type thread
	set ::task::main $main
	proc ::task::exit {} {
	    thread::exit
	}
    }} [thread::id] $::auto_path]

    # And at last, launch the task

    Debug.task {  Launch...}
    thread::send -async $id $cmdprefix

    Debug.task {/}
    return
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::task {
    namespace export -clear *
    namespace ensemble create -subcommands {}
}

# ### ### ### ######### ######### #########
## Ready

package provide task::thread 0.1
return
