# Debug - a debug narrative logger -- Colin McCormack / Wub server utilities
#
# Debugging areas of interest are represented by 'tokens' which have 
# independantly settable levels of interest (an integer, higher is more detailed)
#
# Debug narrative is provided as a tcl script whose value is [subst]ed in the 
# caller's scope if and only if the current level of interest matches or exceeds
# the Debug call's level of detail.  This is useful, as one can place arbitrarily
# complex narrative in code without unnecessarily evaluating it.
#
# TODO: potentially different streams for different areas of interest.
# (currently only stderr is used.  there is some complexity in efficient
# cross-threaded streams.)

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5

namespace eval ::debug {}

# ### ### ### ######### ######### #########
## API & Implementation

proc ::debug::noop {args} {}

proc ::debug::debug {tag message {level 1}} {
    variable detail
    if {$detail($tag) < $level} {
	#puts stderr "$tag @@@ $detail($tag) >= $level"
	return
    }

    variable prefix
    variable fds
    set fd $fds($tag)

    # Integrate global and tag prefixes with the user message.
    set themessage ""
    if {[info exists prefix(::)]}   { append themessage $prefix(::)   }
    if {[info exists prefix($tag)]} { append themessage $prefix($tag) }
    append themessage $message

    # Resolve variables references and command invokations embedded
    # into the message with plain text.
    set code [catch {
	uplevel 1 [list ::subst -nobackslashes [list $themessage]]
    } result eo]

    if {$code} {
	set x [info level -1]
	puts -nonewline $fd @@[string map {\n \\n \r \\r} "(DebugError from $tag [if {[string length $x] < 1000} {set x} else {set x "[string range $x 0 200]...[string range $x end-200 end]"}] ($eo)):"]
    } else {
	if {[string length $result] > 4096} {
	    set result "[string range $result 0 2048]...(truncated) ... [string range $result end-2048 end]"
	}
	puts $fd "$tag @@ [join [split $result \n] "\n$tag @+  "]"
    }
    return
}

# names - return names of debug tags
proc ::debug::names {} {
    variable detail
    return [lsort [array names detail]]
}

proc ::debug::2array {} {
    variable detail
    set result {}
    foreach n [lsort [array names detail]] {
	if {[interp alias {} Debug.$n] ne "::Debug::noop"} {
	    lappend result $n $detail($n)
	} else {
	    lappend result $n -$detail($n)
	}
    }
    return $result
}

# level - set level and fd for tag
proc ::debug::level {tag {level ""} {fd stderr}} {
    variable detail
    if {$level ne ""} {
	set detail($tag) $level
    }

    if {![info exists detail($tag)]} {
	set detail($tag) 1
    }

    variable fds
    set fds($tag) $fd

    return $detail($tag)
}

# set prefix to use for tag.
# The global (tag-independent) prefix is adressed through tag == '::'`.
# This works because colon (:) is an illegal character for regular tags.
proc ::debug::prefix {tag {theprefix {}}} {
    variable prefix
    set prefix($tag) $theprefix
    return
}

# turn on debugging for tag
proc ::debug::on {tag {level ""} {fd stderr}} {
    level $tag $level $fd
    interp alias {} Debug.$tag {} ::debug::debug $tag
    return
}

# turn off debugging for tag
proc ::debug::off {tag {level ""} {fd stderr}} {
    level $tag $level $fd
    interp alias {} Debug.$tag {} ::debug::noop
    return
}

proc ::debug::setting {args} {
    if {[llength $args] == 1} {
	set args [lindex $args 0]
    }
    set fd stderr
    if {[llength $args]%2} {
	set fd [lindex $args end]
	set args [lrange $args 0 end-1]
    }
    foreach {tag level} $args {
	if {$level > 0} {
	    level $tag $level $fd
	    interp alias {} Debug.$tag {} ::Debug::debug $tag
	} else {
	    level $tag [expr {-$level}] $fd
	    interp alias {} Debug.$tag {} ::Debug::noop
	}
    }
    return
}

namespace eval debug {
    variable detail  ; # map: TAG -> level of interest
    variable prefix  ; # map: TAG -> message prefix to use
    variable fds     ; # map: TAG -> handle of open channel to log to.

    # Notes:
    # The tag '::' is reserved, prefix() uses it to store the global message prefix.

    namespace export -clear *
    namespace ensemble create -subcommands {}
}

# ### ### ### ######### ######### #########
## Ready

package provide debug 1.0
return
