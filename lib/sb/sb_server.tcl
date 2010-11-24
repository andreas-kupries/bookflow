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

proc ::scoreboard::put {tuple} {
    variable db

    Debug.scoreboard {put <$tuple>}

    incr db($tuple)
    Broadcast $tuple

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

# ### ### ### ######### ######### #########
## Internals

proc ::scoreboard::Return {thread cmd tuple} {
    thread::send -async $thread [list {*}$cmd $tuple]
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

proc ::scoreboard::Call {cmd tuple} {
    Debug.scoreboard {    Call $cmd}
    after idle [list after 1 [list {*}$cmd $tuple]]
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
