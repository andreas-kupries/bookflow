## -*- tcl -*-
# ### ### ### ######### ######### #########

# Scoreboard, a singleton in-memory database used by the concurrent
# tasks and the main control to coordinate and communicate with each
# other. Actually a tuple-space with a bit of dressing disguising it.

# ### ### ### ######### ######### #########
## API & Implementation

proc ::scoreboard::put {args} {
    variable db

    if {![llength $args]} {
	return -code error "wrong\#args: expected tuple..."
    }

    Debug.scoreboard {put <[join $args ">\nput <"]>}

    foreach tuple $args {
	incr db($tuple)
	Notify put $tuple
    }

    Broadcast $args
    Debug.scoreboard {put/}
    return
}

proc ::scoreboard::take {pattern cmd} {
    variable db

    Debug.scoreboard {take <$pattern> (($cmd))}

    set matches [array names db $pattern]

    if {![llength $matches]} {
	Debug.scoreboard {  no matches, defer response}

	Wait $pattern $cmd
	Debug.scoreboard {take/}
	return
    }

    set tuple [lindex $matches 0]

    Debug.scoreboard {  matches = [llength $matches]}
    Debug.scoreboard {  taken <$tuple>}

    Remove $tuple
    Notify take $tuple
    Call $cmd $tuple

    Debug.scoreboard {take/}
    return
}

proc ::scoreboard::takeall {pattern cmd} {
    variable db

    Debug.scoreboard {takeall <$pattern> (($cmd))}

    set matches [array names db $pattern]

    Debug.scoreboard {  matches = [llength $matches]}

    foreach tuple $matches {
	Debug.scoreboard {  taken <$tuple>}
	Remove $tuple
	Notify take $tuple
    }

    Call $cmd $matches

    Debug.scoreboard {takeall/}
    return
}

proc ::scoreboard::peek {pattern cmd} {
    variable db

    Debug.scoreboard {peek <$pattern> (($cmd))}

    set matches [array names db $pattern]

    Debug.scoreboard {  matches = [llength $matches]}

    Call $cmd $matches

    Debug.scoreboard {peek/}
    return
}

proc ::scoreboard::bind {event pattern cmd} {
    Debug.scoreboard {bind::$event <$pattern> (($cmd))}

    if {$event ni {put take}} {
	return -code error "Bad event \"$event\", expected one of put, or take"
    }

    variable bind
    lappend  bind($event) [list $pattern $cmd]

    Debug.scoreboard {bind::$event/}
    return
}

proc ::scoreboard::unbind {event pattern cmd} {
    Debug.scoreboard {unbind::$event <$pattern> (($cmd))}

    if {$event ni {put take}} {
	return -code error "Bad event \"$event\", expected one of put, or take"
    }

    variable bind
    set k [list $pattern $cmd]
    set pos [lsearch -exact $bind($event) $k]
    if {$pos < 0} return
    set bind($event) [lreplace $bind($event) $pos $pos]

    Debug.scoreboard {unbind::$event/}
    return
}

# ### ### ### ######### ######### #########
## Internals

proc ::scoreboard::Return {thread cmd args} {
    thread::send -async $thread [list {*}$cmd {*}$args]
    return
}

proc ::scoreboard::Remove {tuple} {
    variable db
    incr db($tuple) -1
    if {!$db($tuple)} { unset db($tuple) }
    return
}

proc ::scoreboard::Wait {pattern cmd} {
    variable wait
    lappend  wait [list $pattern $cmd]
    return
}

proc ::scoreboard::Broadcast {tuples} {
    variable wait

    Debug.scoreboard {  Broadcast}

    set stillwaiting {}
    foreach item $wait {
	# Quick bail out if all tuples have been broadcast.

	if {![llength $tuples]} {
	    lappend stillwaiting $item
	    continue
	}

	# Bail if the pattern of the waiting request doesn't match any
	# tuple.

	lassign $item pattern cmd
	set pos [lsearch -glob $tuples $pattern]
	if {$pos < 0} {
	    lappend stillwaiting $item
	    continue
	}

	# This request matches and is now served. It doesn't go on the
	# still-pending list. The tuple in question is removed

	Debug.scoreboard {  Broadcast : Match <$pattern>}

	set tuple  [lindex $tuples $pos]
	set tuples [lreplace $tuples $pos $pos]

	Debug.scoreboard {    taken <$tuple>}

	Remove $tuple
	Call $cmd $tuple
    }

    set wait $stillwaiting

    Debug.scoreboard {  Broadcast/}
    return
}

proc ::scoreboard::Call {cmd args} {
    Debug.scoreboard {    Call $cmd ($args)}
    after idle [list after 1 [list {*}$cmd {*}$args]]
    return
}

proc ::scoreboard::Notify {event tuple} {
    Debug.scoreboard {  Notify $event}

    variable bind
    foreach item $bind($event) {
	lassign $item p c
	if {![string match $p $tuple]} continue
	Call $c $tuple
    }

    Debug.scoreboard {  Notify $event/}
    return
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::scoreboard {
    variable db       ; # tuple array: tuple -> count of instances
    variable wait  {} ; # list of pending 'take's.

    variable  bind    ; # List of bindings per event-type. Initially empty.
    array set bind {
	put     {}
	take    {}
    }

    namespace export {[a-z]*}
    namespace ensemble create
}
