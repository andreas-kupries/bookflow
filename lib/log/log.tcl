
# Log - A narrative logger, not for debugging by the developer, but
#       end-user reporting of system activity.
# Derived from the debug logger.
#
# Logging areas of interest are represented by 'tokens' which have 
# independantly settable levels of interest (an integer, higher is more detailed)
#
# Log narrative is provided as a tcl script whose value is [subst]ed in the 
# caller's scope if and only if the current level of interest matches or exceeds
# the Log call's level of detail.  This is useful, as one can place arbitrarily
# complex narrative in code without unnecessarily evaluating it.
#
# TODO: potentially different streams for different areas of interest.
# (currently only stderr is used.  there is some complexity in efficient
# cross-threaded streams.)

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require debug

namespace eval ::log {}

debug off log

# ### ### ### ######### ######### #########
## API & Implementation

proc ::log::noop {args} {}

proc ::log::log {tag message {level 1}} {
    variable detail

    if {$detail($tag) < $level} {
	#puts stderr "$tag @@@ $detail($tag) >= $level"
	return
    }

    variable prefix
    variable fds

    # Determine the log command, based on tag, with fallback to a
    # global setting.`
    if {[catch {
	set fd $fds($tag)
    }]} {
	set fd $fds(::)
    }

    # Integrate global and tag prefixes with the user message.
    set themessage ""
    if {[info exists prefix(::)]}   { append themessage $prefix(::)   }
    if {[info exists prefix($tag)]} { append themessage $prefix($tag) }
    append themessage $message

    # Resolve variables references and command invokations embedded
    # into the message with plain text.
    set code [catch {
	uplevel 1 [list ::subst -nobackslashes $themessage]
    } result eo]

    if {$code} {
	return -code error $result
	#set x [info level -1]
	#set x [expr {[string length $x] < 1000 ? $x : "[string range $x 0 200]...[string range $x end-200 end]"}]
	#{*}$fd puts* @@[string map {\n \\n \r \\r} "(LogError from $tag $x ($eo)):"]
    } {
	if {[string length $result] > 4096} {
	    set result "[string range $result 0 2048]...(truncated) ... [string range $result end-2048 end]"
	}
	set head $tag
	set blank [regsub -all . $tag { }]
	foreach line [split $result \n] {
	    #{*}$fd puts* $head
	    #{*}$fd puts* { | }
	    {*}$fd puts  $line
	    set head $blank
	}
    }
    return
}

# names - return names of log tags
proc ::log::names {} {
    variable detail
    return [lsort [array names detail]]
}

proc ::log::2array {} {
    variable detail
    set result {}
    foreach n [lsort [array names detail]] {
	if {[interp alias {} Log.$n] ne "::Log::noop"} {
	    lappend result $n $detail($n)
	} else {
	    lappend result $n -$detail($n)
	}
    }
    return $result
}

# level - set level and log command for tag
proc ::log::level {tag {level ""} {fd {}}} {
    variable detail
    if {$level ne ""} {
	set detail($tag) $level
    }

    if {![info exists detail($tag)]} {
	set detail($tag) 1
    }

    variable fds
    if {$fd ne {}} {
	set fds($tag) $fd
    }

    return $detail($tag)
}

# set prefix to use for tag.
# The global (tag-independent) prefix is adressed through tag == '::'`.
# This works because colon (:) is an illegal character for regular tags.
proc ::log::prefix {tag {theprefix {}}} {
    variable prefix
    set prefix($tag) $theprefix
    return
}

# turn on logging for tag
proc ::log::on {tag {level ""} {fd {}}} {
    variable active
    set active($tag) 1
    level $tag $level $fd
    interp alias {} Log.$tag {} ::log::log $tag
    return
}

# turn off logging for tag
proc ::log::off {tag {level ""} {fd {}}} {
    variable active
    set active($tag) 0
    level $tag $level $fd
    interp alias {} Log.$tag {} ::log::noop
    return
}

proc ::log::setting {args} {
    if {[llength $args] == 1} {
	set args [lindex $args 0]
    }
    set fd {}
    if {[llength $args]%2} {
	set fd [lindex $args end]
	set args [lrange $args 0 end-1]
    }
    foreach {tag level} $args {
	if {$level > 0} {
	    level $tag $level $fd
	    interp alias {} Log.$tag {} ::Log::log $tag
	} else {
	    level $tag [expr {-$level}] $fd
	    interp alias {} Log.$tag {} ::Log::noop
	}
    }
    return
}

# ### ### ### ######### ######### #########
## Communication setup for concurrent tasks.
## Thread based.

namespace eval ::log::thread {}

proc ::log::thread::link {main} {
    variable ::log::detail
    variable ::log::prefix
    variable ::log::fds

    Debug.log {  Setting up log for $main}

    # Import main's status.
    array set detail [thread::send $main {array get ::log::detail}]
    array set prefix [thread::send $main {array get ::log::prefix}]
    array set active [thread::send $main {array get ::log::active}]
    # We do not import any custom write commands.
    # Any writing goes through the global setting, which is
    # reconfigured to perform the necessary inter-thread
    # communication.

    # Replicate (in)active status of the tags.
    foreach {t a} [array get active] {
	if {$a} {
	    interp alias {} Log.$t {} ::log::log $t
	} else {
	    interp alias {} Log.$t {} ::log::noop
	}
    }

    set fds(::) [list ::log::thread::ToMain $main]

    return
}

proc ::log::thread::ToMain {main cmd text} {
    upvar 1 tag tag
    thread::send -async $main \
	[list ::log::thread::FromTask $tag $cmd $text]
    return
}

proc ::log::thread::FromTask {tag cmd text} {
    # This is a variant of log::log without all the substitutions. It
    # determines the actual write command per the tag and invokes it
    # with the specifiec method and text.

    # It is the receiver of messages coming from concurrently running
    # tasks.

    variable ::log::fds

    if {[catch {
	set fd $fds($tag)
    }]} {
	set fd $fds(::)
    }

    {*}$fd $cmd $text
    return
}

# ### ### ### ######### ######### #########
## Standard log writer command

namespace eval ::log::Write {
    namespace export puts puts*
    namespace ensemble create
}

proc ::log::Write::puts {text} {
    puts stderr $text
    return
}

proc ::log::Write::puts* {text} {
    puts stderr -nonewline $text
    flush stderr
    return
}

# ### ### ### ######### ######### #########
## State

namespace eval ::log {
    variable detail  ; # map: TAG -> level of interest
    variable prefix  ; # map: TAG -> message prefix to use
    variable fds     ; # map: TAG -> command prefix to use for writing the message.
    variable active  ; # map: TAG -> boolean flag, true if tag is active.

    # Notes:
    # The tag '::' is reserved.
    # prefix() uses it to store the global message prefix.
    # fds() uses it to store a global command prefix for writing messages.

    set fds(::) ::log::Write

    namespace export -clear *
    namespace ensemble create -subcommands {}
}

# ### ### ### ######### ######### #########
## Look for the magic of package task, and if found, reconfigure
## ourselves to write to the main system. Do not forget to import the
## main's status as well.

::apply {{} {
    if {![info exists ::task::type]} return
    ::log::${::task::type}::link $::task::main
    return
}}

# ### ### ### ######### ######### #########
## Ready

package provide blog 1.0
return
