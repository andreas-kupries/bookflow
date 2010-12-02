## -*- tcl -*-
# ### ### ### ######### ######### #########

# Issue Queue. Use it to limit the rate of issuing requests for data
# like thumbnails etc. Instead of directly issuing the query patterns
# to the scoreboard issue them to an instance of iq and the queue will
# issue them so that only a fixed (but configurable) number of queries
# have outstanding results.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require snit
package require scoreboard
package require debug
package require debug::snit
package require struct::queue

# ### ### ### ######### ######### #########
## Tracing

debug prefix iq {[::debug::snit::call] }
debug off    iq
#debug on     iq

# ### ### ### ######### ######### #########
## Implementation

snit::type ::iq {
    # ### ### ### ######### ######### #########
    ##

    option -emptycmd \
	-default {}

    # ### ### ### ######### ######### #########
    ##

    constructor {limit args} {
	Debug.iq {}

	set mylimit $limit
	set myqueue [struct::queue ${selfns}::Q]

	$self configurelist $args
	Debug.iq {/}
	return
    }

    method put {pattern cmd} {
	Debug.iq {}

	if {$myflight >= $mylimit} {
	    $myqueue put [list $pattern $cmd]
	    Debug.iq {/}
	    return
	}

	$self Dispatch $pattern $cmd

	Debug.iq {/}
	return
    }

    # ### ### ### ######### ######### #########
    ##

    method Dispatch {pattern cmd} {
	Debug.iq {}

	scoreboard wpeek $pattern [mymethod Have $cmd]
	incr myflight

	Debug.iq {/}
	return
    }

    method Have {cmd tuple} {
	Debug.iq {}

	incr myflight -1
	if {($myflight < $mylimit) && [$myqueue size]} {
	    lassign [$myqueue get] pattern cmd
	    $self Dispatch $pattern $cmd
	    $self NotifyEmpty
	}

	uplevel #0 [list {*}$cmd $tuple]

	Debug.iq {/}
	return
    }

    # ### ### ### ######### ######### #########

    method NotifyEmpty {args} {
	if {![$myqueue size]} return
	if {![llength $options(-emptycmd)]} return
	after idle [list after 0 [list {*}$options(-emptycmd) $self]]
	return
    }

    # ### ### ### ######### ######### #########
    ##

    variable myflight 0  ; # Number of requests waiting for results
    variable mylimit  0  ; # Maximum number of requests we are allowed
			   # to keep in flight.
    variable myqueue {}  ; # Queue of requests waiting to be issued.

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide iq 0.1
return
