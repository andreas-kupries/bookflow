## -*- tcl -*-
# ### ### ### ######### ######### #########

# Scoreboard Client. Used by tasks (in threads) to talk to the actual
# scoreboard in the main thread. The commands are shims which redirect
# to the equivalent command in the main thread, possibly rewriting
# arguments to handle the proper back and forth for callbacks.

# ### ### ### ######### ######### #########
## Requisites

namespace eval ::scoreboard {}

# ### ### ### ######### ######### #########
## Tracing

# ### ### ### ######### ######### #########
## API & Implementation

proc ::scoreboard::put {tuple} {
    thread::send -async $::task::main [info level 0]
    return
}

proc ::scoreboard::take {pattern cmd} {
    set me [info level 0]
    set me [lreplace $me end end [list ::scoreboard::Return [thread::id] [lindex $me end]]]
    return [thread::send $::task::main $me]
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::scoreboard {
    namespace export {[a-z]*}
    namespace ensemble create
}