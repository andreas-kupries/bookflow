## -*- tcl -*-
# ### ### ### ######### ######### #########

# Scoreboard, a singleton in-memory database used by the concurrent
# tasks and the main control to coordinate and communicate with each
# other. Actually a tuple-space with a bit of dressing disguising it.

# ### ### ### ######### ######### #########
## Requisites

package uevent::onidle
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
    }

    # NOTE (optimization): Should tell Broadcast how many tuples were
    # added. That many waiting 'take's can be released, at most.
    Broadcast
    Debug.scoreboard {put/}
    return
}

proc ::scoreboard::take {pattern cmd} {
    variable db

    Debug.scoreboard {take <$pattern>}

    set matches [array names db $pattern]

    if {![llength $matches]} {
	Debug.scoreboard {  no matches, defer response}

	variable wait
	lappend wait($pattern) $cmd

	Debug.scoreboard {take/}
	return
    }

    set tuple [lindex $matches 0]

    Debug.scoreboard {  matches = [llength $matches]}
    Debug.scoreboard {  taken <$tuple>}

    Remove $tuple
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
    }

    Call $cmd $matches

    Debug.scoreboard {takeall/}
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

proc ::scoreboard::Broadcast {tuple} {
    variable wait

    foreach pattern [array names wait] {
	if {![string match $pattern $tuple]} continue

	Debug.scoreboard {  Broadcast : Match <$pattern>}

	set remainder [lassign $wait($pattern) cmd]
	if {![llength $remainder]} {
	    unset wait($pattern)
	} else {
	    set wait($pattern) $remainder
	}

	Debug.scoreboard {    taken <$tuple>}

	Remove $tuple
	Call $cmd $tuple
	return
    }

    Debug.scoreboard {  Broadcast : No matches}
    return
}

proc ::scoreboard::Call {cmd args} {
    Debug.scoreboard {    Call $cmd ($args)}
    after idle [list after 1 [list {*}$cmd {*}$args]]
    return
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::scoreboard {
    variable db
    variable wait

    namespace export {[a-z]*}
    namespace ensemble create
}
