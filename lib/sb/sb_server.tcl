## -*- tcl -*-
# ### ### ### ######### ######### #########

# Scoreboard, a singleton in-memory database used by the concurrent
# tasks and the main control to coordinate and communicate with each
# other. Actually a tuple-space with a bit of dressing disguising it.

# ### ### ### ######### ######### #########
## Requisites

namespace eval ::scoreboard {}

# ### ### ### ######### ######### #########
## Tracing

#debug off    scoreboard
debug on     scoreboard

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
	NotifyPut $tuple
    }

    Broadcast $args
    Debug.scoreboard {put/}
    return
}

proc ::scoreboard::take {pattern cmd} {
    variable db

    Debug.scoreboard {take <$pattern>}

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
    NotifyTake $tuple
    Call $cmd $tuple

    Debug.scoreboard {take/}
    return
}

proc ::scoreboard::takeall {pattern cmd} {
    variable db

    Debug.scoreboard {takeall <$pattern>}

    set matches [array names db $pattern]

    Debug.scoreboard {  matches = [llength $matches]}

    foreach tuple $matches {
	Debug.scoreboard {  taken <$tuple>}
	Remove $tuple
	NotifyTake $tuple
    }

    Call $cmd $matches

    Debug.scoreboard {takeall/}
    return
}

namespace eval ::scoreboard::bind {
    namespace export put take
    namespace ensemble create
}

proc ::scoreboard::bind::put {pattern cmd} {
    variable ::scoreboard::eput
    lappend  eput [list $pattern $cmd]
    return
}

proc ::scoreboard::bind::take {pattern cmd} {
    variable ::scoreboard::etake
    lappend  etake [list $pattern $cmd]
    return
}

namespace eval ::scoreboard::unbind {
    namespace export put take
    namespace ensemble create
}

proc ::scoreboard::unbind::put {pattern cmd} {
    variable ::scoreboard::eput
    set k [list $pattern $cmd]
    set pos [lsearch -exact $eput $k]
    if {$pos < 0} return
    set eput [lreplace $eput $pos $pos]
    return
}

proc ::scoreboard::unbind::take {pattern cmd} {
    variable ::scoreboard::etake
    set k [list $pattern $cmd]
    set pos [lsearch -exact $etake $k]
    if {$pos < 0} return
    set etake [lreplace $etake $pos $pos]
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

	# This request matches and is now served.
	# It doesn't go on the still-pending list.
	# The tuple in question is removed.

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

proc ::scoreboard::NotifyPut {tuple} {
    Debug.scoreboard {  Notify Put}

    variable eput
    foreach item $eput {
	lassign $item p c
	if {![string match $p $tuple]} continue
	Call $c $tuple
    }

    Debug.scoreboard {  Notify Put/}
    return
}

proc ::scoreboard::NotifyTake {tuple} {
    Debug.scoreboard {  Notify Take}

    variable etake
    foreach item $etake {
	lassign $item p c
	if {![string match $p $tuple]} continue
	Call $c $tuple
    }

    Debug.scoreboard {  Notify Take/}
    return
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::scoreboard {
    variable db       ; # tuple array: tuple -> count of instances
    variable wait  {} ; # list of pending 'take's.
    variable eput  {} ; # list of bindings on put
    variable etake {} ; # list of bindings on take

    namespace export {[a-z]*}
    namespace ensemble create
}
