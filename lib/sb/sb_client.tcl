## -*- tcl -*-
# ### ### ### ######### ######### #########

# Scoreboard Client. Used by tasks (in threads) to talk to the actual
# scoreboard in the main thread. The commands are shims which redirect
# to the equivalent command in the main thread, possibly rewriting
# arguments to handle the proper back and forth for callbacks.

# ### ### ### ######### ######### #########
## API & Implementation

proc ::scoreboard::put {args} {
    thread::send -async $::task::main [info level 0]
    return
}

proc ::scoreboard::take {pattern cmd} {
    set me [info level 0]
    set me [lreplace $me end end [list ::scoreboard::Return [thread::id] [lindex $me end]]]
    thread::send -async $::task::main $me
    return
}

proc ::scoreboard::takeall {pattern cmd} {
    set me [info level 0]
    set me [lreplace $me end end [list ::scoreboard::Return [thread::id] [lindex $me end]]]
    thread::send -async $::task::main $me
    return
}

proc ::scoreboard::peek {pattern cmd} {
    set me [info level 0]
    set me [lreplace $me end end [list ::scoreboard::Return [thread::id] [lindex $me end]]]
    thread::send -async $::task::main $me
    return
}

proc ::scoreboard::wpeek {pattern cmd} {
    set me [info level 0]
    set me [lreplace $me end end [list ::scoreboard::Return [thread::id] [lindex $me end]]]
    thread::send -async $::task::main $me
    return
}

proc ::scoreboard::bind {event pattern cmd} {
    set me [info level 0]
    set me [lreplace $me end end [list ::scoreboard::Return [thread::id] [lindex $me end]]]
    thread::send -async $::task::main $me
    return
}

proc ::scoreboard::unbind {event pattern cmd} {
    set me [info level 0]
    set me [lreplace $me end end [list ::scoreboard::Return [thread::id] [lindex $me end]]]
    thread::send -async $::task::main $me
    return
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::scoreboard {
    namespace export {[a-z]*}
    namespace ensemble create
}
